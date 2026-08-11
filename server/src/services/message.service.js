import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';
import { User } from '../models/User.js';
import { ApiError } from '../utils/ApiError.js';
import { emitToUsers } from '../realtime/io.js';

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

//export async function getOrCreateConversation(userIdA, userIdB) {
//  if (String(userIdA) === String(userIdB)) {
//    throw new ApiError(400, 'Cannot start a conversation with yourself');
//  }
//
//  // Find existing 1-on-1 conversation
////  let conversation = await Conversation.findOne({
////    where: {
//      // Using raw query to check if both userIds exist in the array
////    },
////  });
//
//
//  // Manual check since we can't use array operators easily in Sequelize
//  if (!conversation) {
//    const allConvs = await Conversation.findAll();
//    conversation = allConvs.find(c =>
//      c.userIds.includes(String(userIdA)) && c.userIds.includes(String(userIdB))
//    );
//  }
//
//  if (!conversation) {
//    conversation = await Conversation.create({
//      userIds: [String(userIdA), String(userIdB)],
//    });
//  }
//
//  return conversation;
//}

export async function createMessage({
  conversationId,
  senderId,
  text,
  type = 'text',
  callUrl = null,
  imageUrl = null,
  voiceUrl = null,
  voiceDuration = 0,
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
});
   let lastText = '';

    switch (type) {
      case 'text':
        lastText = message.text;
        break;

      case 'image':
        lastText = '📷 Photo';
        break;

        case 'voice':
          lastText = '🎤 Voice message';
          break;

      case 'videoCall':
        lastText = '📹 Video call';
        break;

      case 'voiceCall':
        lastText = '📞 Voice call';
        break;
    }

    conversation.lastMessage = {
      text: lastText,
      sender: senderId,
      at: message.createdAt,
    };
  await conversation.save();

  // Fetch sender details for the response
  const sender = await User.findByPk(senderId);
  message = message.toJSON();
  message.sender = sender.toJSON();

  // Emit to both participants
  emitToUsers(conversation.userIds, 'message:new', {
    conversationId: String(conversation.id),
    message,
  });

  return message;
}
