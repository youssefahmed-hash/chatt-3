import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';
import { User } from '../models/User.js';
import { Reaction } from '../models/Reaction.js';
import { ApiError } from '../utils/ApiError.js';
import { emitToUsersPerViewer } from '../realtime/io.js';
import { sendPushToUsers } from './push.service.js';

export async function getOrCreateConversation(userIdA, userIdB) {
  if (String(userIdA) === String(userIdB)) {
    throw new ApiError(400, 'Cannot start a conversation with yourself');
  }

  const allConvs = await Conversation.findAll();

  let conversation = allConvs.find(
    c =>
      c.userIds.includes(String(userIdA)) &&
      c.userIds.includes(String(userIdB))
  );

  if (!conversation) {
    conversation = await Conversation.create({
      userIds: [String(userIdA), String(userIdB)],
    });
  }

  return conversation;
}

// Last-message preview text for a message type.
export function messagePreviewText(message) {
  switch (message.type) {
    case 'text':
      return message.text;
    case 'image':
      return '📷 Photo';
    case 'voice':
      return '🎤 Voice message';
    case 'file':
      return '📎 File';
    case 'video':
      return '🎬 Video';
    case 'videoCall':
      return '📹 Video call';
    case 'voiceCall':
      return '📞 Voice call';
    default:
      return message.text || '';
  }
}

// Serialize a message with its sender, reply reference and reactions.
export async function serializeMessage(msg, viewerId) {
  const json = msg.toJSON ? msg.toJSON() : msg;

  if (msg.sender === undefined) {
    const sender = msg.senderId
      ? await User.findByPk(msg.senderId, {
          attributes: ['id', 'name', 'avatarUrl'],
        })
      : null;
    json.sender = sender ? sender.toJSON() : null;
  }

  if (json.replyToId) {
    const reply = await Message.findByPk(json.replyToId, {
      include: [
        {
          model: User,
          as: 'sender',
          attributes: ['id', 'name', 'avatarUrl'],
        },
      ],
    });
    if (reply) {
      const r = reply.toJSON();
      delete r.readBy;
      json.replyTo = r;
    }
  }

  const reactions = await Reaction.findAll({
    where: { messageId: json.id },
    attributes: ['emoji', 'userId'],
  });

  // Resolve one user record per distinct reactor so the client can label
  // WHO reacted with WHAT (WhatsApp-style reaction details).
  const reactorIds = [
    ...new Set(reactions.map(r => String(r.userId))),
  ];
  const usersById = {};
  if (reactorIds.length) {
    const reactorUsers = await User.findAll({
      where: { id: reactorIds },
      attributes: ['id', 'name', 'avatarUrl'],
    });
    reactorUsers.forEach(u => {
      usersById[String(u.id)] = u.toJSON();
    });
  }

  const reactionMap = {};
  for (const r of reactions) {
    const emoji = r.emoji;
    if (!reactionMap[emoji]) {
      reactionMap[emoji] = { count: 0, userIds: [], users: [] };
    }
    reactionMap[emoji].count += 1;
    reactionMap[emoji].userIds.push(String(r.userId));
    reactionMap[emoji].users.push(
      usersById[String(r.userId)] || {
        id: String(r.userId),
        name: null,
        avatarUrl: null,
      },
    );
  }
  json.reactions = reactionMap;
  json.myReactions = reactions
    .filter(r => String(r.userId) === String(viewerId))
    .map(r => r.emoji);

  return json;
}

export async function createMessage({
  conversationId,
  senderId,
  text,
  type = 'text',
  callUrl = null,
  imageUrl = null,
  voiceUrl = null,
  voiceDuration = 0,
  replyToId = null,
  forwardedFrom = null,
  fileUrl = null,
  fileName = null,
  fileSize = null,
  fileType = null,
  videoUrl = null,
  videoThumbUrl = null,
  clientId = null,
}) {
  const conversation = await Conversation.findByPk(conversationId);
  if (!conversation) {
    throw new ApiError(404, 'Conversation not found');
  }

  const isParticipant = conversation.userIds.includes(String(senderId));
  if (!isParticipant) {
    throw new ApiError(403, 'You are not part of this conversation');
  }

  if (type === 'text' && (!text || !text.trim())) {
    throw new ApiError(400, 'Message text is required');
  }

  if (replyToId) {
    const replyTarget = await Message.findByPk(replyToId);
    if (!replyTarget) {
      throw new ApiError(404, 'Replied message not found');
    }
  }

  // Idempotency: a retry (socket ack lost, REST fallback, offline flush)
  // carrying the same client id of the same sender must never create a
  // duplicate row. Return the already-persisted message instead.
  if (clientId) {
    const existing = await Message.findOne({
      where: { senderId, clientId },
    });
    if (existing) {
      return await serializeMessage(existing, senderId);
    }
  }

  let message = await Message.create({
    conversationId,
    senderId,
    text: text || '',
    type,
    callUrl,
    imageUrl,
    voiceUrl,
    voiceDuration,
    readBy: [senderId],
    clientId: clientId || null,
    replyToId: replyToId || null,
    forwardedFrom: forwardedFrom || null,
    fileUrl,
    fileName,
    fileSize,
    fileType,
    videoUrl,
    videoThumbUrl,
  });

  conversation.lastMessage = {
    text: messagePreviewText(message),
    sender: senderId,
    at: message.createdAt,
  };
  await conversation.save();

  // Fetch sender details and full serialization (reply preview, reactions)
  // so every path (socket ack, message:new broadcast, REST responses) carries
  // consistent data.
  const serialized = await serializeMessage(message, senderId);

  // Echo to both participants, each with their own viewer so the payload a
  // device parses (sender, myReactions, readBy) matches exactly what its own
  // REST reload would return for this message.
  await emitToUsersPerViewer(
    conversation.userIds,
    'message:new',
    async (userId) => {
      const viewerMessage =
        String(userId) === String(senderId)
          ? serialized
          : await serializeMessage(message, userId);
      return {
        conversationId: String(conversation.id),
        message: viewerMessage,
      };
    },
  );

  // Push to every other participant. Closed tabs receive the Web Push;
  // open/foreground devices get the socket event above (and suppress the
  // duplicate via the worker visibility flag).
  const senderName = serialized.sender ? serialized.sender.name : null;
  sendPushToUsers(
    conversation.userIds.filter((u) => String(u) !== String(senderId)),
    {
      title: senderName || 'Chatt',
      body: messagePreviewText(message),
      data: { conversationId: String(conversation.id) },
    },
  ).catch(() => {});

  return serialized;
}

// Ensure a user is a participant of a conversation, else throw 403.
export async function assertParticipant(conversation, userId) {
  if (!conversation.userIds.includes(String(userId))) {
    throw new ApiError(403, 'You are not part of this conversation');
  }
}
