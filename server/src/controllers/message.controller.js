import { z } from 'zod';
import { Op } from 'sequelize';
import { MESSAGE_TYPES } from '../models/Message.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createMessage, serializeMessage, messagePreviewText, assertParticipant } from '../services/message.service.js';
import { Message } from '../models/Message.js';
import { Conversation } from '../models/Conversation.js';
import { Reaction } from '../models/Reaction.js';
import { StarredMessage } from '../models/StarredMessage.js';
import { emitToUsers, emitToUsersPerViewer } from '../realtime/io.js';
import { sendPushToUsers } from '../services/push.service.js';
import { ApiError } from '../utils/ApiError.js';


export const sendMessageSchema = z.object({
  text: z.string().max(5000).optional(),
  type: z.enum(MESSAGE_TYPES).optional(),
  callUrl: z.string().url('callUrl must be a valid URL').nullable().optional(),
  replyToId: z.string().uuid().nullable().optional(),
  forwardedFrom: z.string().uuid().nullable().optional(),
  clientId: z.string().max(100).nullable().optional(),
});

export const sendImageMessage = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      message: 'No image uploaded',
    });
  }

  const imageUrl = `/uploads/messages/${req.file.filename}`;
  const message = await createMessage({
    conversationId: req.params.id,
    senderId: req.user.id,
    text: req.body.text || '',
    type: 'image',
    imageUrl,
    replyToId: req.body.replyToId || null,
  });

  res.status(201).json({ message });
});

// POST /api/conversations/:id/messages
// REST fallback for sending a message (the socket layer is the primary path).
export const sendMessage = asyncHandler(async (req, res) => {
  const message = await createMessage({
    conversationId: req.params.id,
    senderId: req.user.id,
    text: req.body.text,
    type: req.body.type || 'text',
    callUrl: req.body.callUrl || null,
    replyToId: req.body.replyToId || null,
    forwardedFrom: req.body.forwardedFrom || null,
    clientId: req.body.clientId || null,
  });

  res.status(201).json({ message });
});

export const deleteMessage = async (req, res) => {
  try {
    const { messageId } = req.params;

    const message = await Message.findByPk(messageId);

    if (!message) {
      return res.status(404).json({
        message: 'Message not found',
      });
    }

    if (message.senderId !== req.user.id) {
      return res.status(403).json({
        message: 'You can only delete your own messages',
      });
    }

    const conversationId = message.conversationId;

    // هات المحادثة قبل الحذف علشان نعرف نبعت Socket
    const conversation = await Conversation.findByPk(conversationId);

    // احذف الصورة من الداتا بيز
    await message.destroy();

    // هات آخر رسالة
    const lastMessage = await Message.findOne({
      where: {
        conversationId,
      },
      order: [['createdAt', 'DESC']],
    });

    if (conversation) {
      conversation.lastMessage = lastMessage
        ? {
            text: messagePreviewText(lastMessage),
            sender: lastMessage.senderId,
            at: lastMessage.createdAt,
          }
        : {
            text: '',
            sender: null,
            at: null,
          };

      conversation.pinnedMessageIds = (conversation.pinnedMessageIds || []).filter(
        (id) => String(id) !== String(messageId),
      );

      await conversation.save();

      // ابعت لكل المستخدمين إن الرسالة اتحذفت
      emitToUsers(conversation.userIds, 'message:deleted', {
        conversationId,
        messageId,
      });
    }

    return res.status(200).json({
      message: 'Message deleted successfully',
    });

  } catch (error) {
    console.error(error);

    return res.status(500).json({
      message: error.message,
    });
  }
};

export const sendVoiceMessage = asyncHandler(async (req, res) => {

  if (!req.file) {
    return res.status(400).json({
      message: 'No voice uploaded',
    });
  }

  const voiceUrl = `/uploads/voices/${req.file.filename}`;
  const duration = Number(req.body.duration || 0);

  const message = await createMessage({
    conversationId: req.params.id,
    senderId: req.user.id,
    text: '',
    type: 'voice',
    voiceUrl,
    voiceDuration: duration,
    replyToId: req.body.replyToId || null,
  });

  res.status(201).json({
    message,
  });

});

// ============================================================
// EDIT MESSAGE (text only, owner only)
// ============================================================
export const editMessageSchema = z.object({
  text: z.string().trim().min(1).max(5000),
});

export const editMessage = asyncHandler(async (req, res) => {
  const { id, messageId } = req.params;

  const message = await Message.findByPk(messageId);

  if (!message) throw new ApiError(404, 'Message not found');
  if (String(message.conversationId) !== String(id)) {
    throw new ApiError(400, 'Message does not belong to this conversation');
  }
  if (String(message.senderId) !== String(req.user.id)) {
    throw new ApiError(403, 'You can only edit your own messages');
  }
  if (message.type !== 'text') {
    throw new ApiError(400, 'Only text messages can be edited');
  }

  message.text = req.body.text;
  message.edited = true;
  await message.save();

  const conversation = await Conversation.findByPk(id);
  if (conversation && conversation.lastMessage &&
      String(conversation.lastMessage.sender) === String(req.user.id)) {
    conversation.lastMessage.text = req.body.text;
    await conversation.save();
  }

  const serialized = await serializeMessage(message, req.user.id);

  await emitToUsersPerViewer(conversation.userIds, 'message:edited', async (viewerId) => {
    const viewerMessage =
      String(viewerId) === String(req.user.id)
        ? serialized
        : await serializeMessage(message, viewerId);
    return {
      conversationId: String(id),
      message: viewerMessage,
    };
  });

  res.json({ message: serialized });
});

// ============================================================
// REACTIONS
// ============================================================
export const addReactionSchema = z.object({
  emoji: z.string().trim().min(1).max(32),
});

export const addReaction = asyncHandler(async (req, res) => {
  const { id, messageId } = req.params;
  const { emoji } = req.body;

  const message = await Message.findByPk(messageId);
  if (!message) throw new ApiError(404, 'Message not found');
  if (String(message.conversationId) !== String(id)) {
    throw new ApiError(400, 'Message does not belong to this conversation');
  }

  const conversation = await Conversation.findByPk(id);
  await assertParticipant(conversation, req.user.id);

  // WhatsApp semantics: ONE reaction per user per message. A different emoji
  // replaces the previous one; the same emoji tap is a no-op (the client
  // sends reaction:remove to take it back).
  const existing = await Reaction.findOne({
    where: {
      messageId,
      userId: req.user.id,
      emoji,
    },
  });

  let created = false;
  if (!existing) {
    await Reaction.destroy({ where: { messageId, userId: req.user.id } });
    await Reaction.create({ messageId, userId: req.user.id, emoji });
    created = true;
  }

  const serialized = await serializeMessage(message, req.user.id);

  if (created) {
    emitToUsers(conversation.userIds, 'reaction:added', {
      conversationId: String(id),
      messageId: String(messageId),
      emoji,
      userId: String(req.user.id),
      reactions: serialized.reactions,
    });

    // Reaction push notification for the message AUTHOR (web push reaches
    // closed tabs; foreground devices get the socket event instead).
    if (message.senderId && String(message.senderId) !== String(req.user.id)) {
      const authorName = serialized.sender ? serialized.sender.name : null;
      sendPushToUsers(
        [String(message.senderId)],
        {
          title: authorName || 'Chatt',
          body: `Reacted ${emoji}`,
          data: { conversationId: String(id) },
        },
      ).catch(() => {});
    }
  }

  res.json({ reactions: serialized.reactions });
});

export const removeReaction = asyncHandler(async (req, res) => {
  const { id, messageId, emoji } = req.params;

  const message = await Message.findByPk(messageId);
  if (!message) throw new ApiError(404, 'Message not found');
  if (String(message.conversationId) !== String(id)) {
    throw new ApiError(400, 'Message does not belong to this conversation');
  }

  const conversation = await Conversation.findByPk(id);
  await assertParticipant(conversation, req.user.id);

  await Reaction.destroy({
    where: {
      messageId,
      userId: req.user.id,
      emoji,
    },
  });

  const serialized = await serializeMessage(message, req.user.id);

  emitToUsers(conversation.userIds, 'reaction:removed', {
    conversationId: String(id),
    messageId: String(messageId),
    emoji,
    userId: String(req.user.id),
    reactions: serialized.reactions,
  });

  res.json({ reactions: serialized.reactions });
});

// ============================================================
// FORWARD
// ============================================================
export const forwardMessageSchema = z.object({
  messageId: z.string().uuid(),
});

export const forwardMessage = asyncHandler(async (req, res) => {
  const { id } = req.params; // target conversation
  const { messageId } = req.body;

  const target = await Conversation.findByPk(id);
  if (!target) throw new ApiError(404, 'Target conversation not found');
  await assertParticipant(target, req.user.id);

  const source = await Message.findByPk(messageId);
  if (!source) throw new ApiError(404, 'Message not found');

  const sourceConv = await Conversation.findByPk(source.conversationId);
  if (!sourceConv) throw new ApiError(404, 'Source conversation not found');
  await assertParticipant(sourceConv, req.user.id);

  // Copy content; physical media (URLs) are reused, not duplicated.
  const newMessage = await createMessage({
    conversationId: id,
    senderId: req.user.id,
    text: source.text || '',
    type: source.type,
    callUrl: source.callUrl,
    imageUrl: source.imageUrl,
    voiceUrl: source.voiceUrl,
    voiceDuration: source.voiceDuration,
    fileUrl: source.fileUrl,
    fileName: source.fileName,
    fileSize: source.fileSize,
    fileType: source.fileType,
    videoUrl: source.videoUrl,
    videoThumbUrl: source.videoThumbUrl,
    forwardedFrom: messageId,
  });

  res.status(201).json({ message: newMessage });
});

// ============================================================
// FILES
// ============================================================
export const sendFileMessage = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      message: 'No file uploaded',
    });
  }

  const originalName = Buffer.from(req.file.originalname, 'latin1').toString('utf8');

  const message = await createMessage({
    conversationId: req.params.id,
    senderId: req.user.id,
    text: '',
    type: 'file',
    fileUrl: `/uploads/files/${req.file.filename}`,
    fileName: originalName,
    fileSize: req.file.size,
    fileType: req.file.mimetype || '',
    replyToId: req.body.replyToId || null,
  });

  res.status(201).json({ message });
});

// ============================================================
// VIDEOS
// ============================================================
export const sendVideoMessage = asyncHandler(async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      message: 'No video uploaded',
    });
  }

  const message = await createMessage({
    conversationId: req.params.id,
    senderId: req.user.id,
    text: '',
    type: 'video',
    videoUrl: `/uploads/videos/${req.file.filename}`,
    replyToId: req.body.replyToId || null,
  });

  res.status(201).json({ message });
});

// ============================================================
// STARRED MESSAGES
// ============================================================
export const starMessage = asyncHandler(async (req, res) => {
  const { messageId } = req.params;

  const message = await Message.findByPk(messageId);
  if (!message) throw new ApiError(404, 'Message not found');

  const conversation = await Conversation.findByPk(message.conversationId);
  await assertParticipant(conversation, req.user.id);

  const existing = await StarredMessage.findOne({
    where: { userId: req.user.id, messageId },
  });

  if (!existing) {
    await StarredMessage.create({
      userId: req.user.id,
      messageId,
      conversationId: message.conversationId,
    });
  }

  res.json({ starred: true });
});

export const unstarMessage = asyncHandler(async (req, res) => {
  const { messageId } = req.params;

  const message = await Message.findByPk(messageId);
  if (!message) throw new ApiError(404, 'Message not found');

  const conversation = await Conversation.findByPk(message.conversationId);
  await assertParticipant(conversation, req.user.id);

  await StarredMessage.destroy({
    where: { userId: req.user.id, messageId },
  });

  res.json({ starred: false });
});

export const listStarredMessages = asyncHandler(async (req, res) => {
  const rows = await StarredMessage.findAll({
    where: { userId: req.user.id },
    order: [['createdAt', 'DESC']],
    include: [
      {
        model: Message,
        as: 'message',
        include: [
          {
            model: Conversation,
            attributes: ['id', 'isGroup', 'groupName', 'groupImage', 'userIds'],
          },
        ],
      },
    ],
  });

  const messages = [];
  for (const row of rows) {
    if (!row.message) continue;
    messages.push({
      starredAt: row.createdAt,
      ...(await serializeMessage(row.message, req.user.id)),
    });
  }

  res.json({ messages });
});
