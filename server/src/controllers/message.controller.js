import { z } from 'zod';
import { MESSAGE_TYPES } from '../models/Message.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { createMessage } from '../services/message.service.js';
import { Message } from '../models/Message.js';
import { Conversation } from '../models/Conversation.js';
import path from 'path';
import { emitToUsers } from '../realtime/io.js';


export const sendMessageSchema = z.object({
  text: z.string().max(5000).optional(),
  type: z.enum(MESSAGE_TYPES).optional(),
  callUrl: z.string().url('callUrl must be a valid URL').nullable().optional(),
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
    text: '',
    type: 'image',
    imageUrl,
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
  });

  res.status(201).json({ message: message.toJSON() });
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
            text: lastMessage.type === 'image'
                ? '📷 Photo'
                : lastMessage.text,
            sender: lastMessage.senderId,
            at: lastMessage.createdAt,
          }
        : {
            text: '',
            sender: null,
            at: null,
          };

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
  });

  res.status(201).json({
    message,
  });

});