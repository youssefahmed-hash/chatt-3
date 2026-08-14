import { User } from '../models/User.js';
import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';
import { Reaction } from '../models/Reaction.js';
import { Call } from '../models/Call.js';
import { StarredMessage } from '../models/StarredMessage.js';

// Conversation ←→ User (many-to-many: participants)
Conversation.belongsToMany(User, {
  through: 'conversation_participants',
  as: 'participants',
  foreignKey: 'conversation_id',
  otherKey: 'user_id',
  timestamps: false,
});

User.belongsToMany(Conversation, {
  through: 'conversation_participants',
  as: 'conversations',
  foreignKey: 'user_id',
  otherKey: 'conversation_id',
  timestamps: false,
});

// Message ←→ User (sender)
Message.belongsTo(User, {
  as: 'sender',
  foreignKey: 'sender_id',
  targetKey: 'id',
});

// Message ←→ Conversation
Message.belongsTo(Conversation, {
  foreignKey: 'conversation_id',
  targetKey: 'id',
});

Conversation.hasMany(Message, {
  foreignKey: 'conversation_id',
  sourceKey: 'id',
  as: 'messages',
});

// Message ←→ Message (reply reference)
Message.belongsTo(Message, {
  as: 'replyTo',
  foreignKey: 'reply_to_id',
  targetKey: 'id',
});

// Reaction ←→ Message & User
Reaction.belongsTo(Message, {
  as: 'message',
  foreignKey: 'message_id',
  targetKey: 'id',
});
Message.hasMany(Reaction, {
  as: 'reactions',
  foreignKey: 'message_id',
  sourceKey: 'id',
});
Reaction.belongsTo(User, {
  as: 'user',
  foreignKey: 'user_id',
  targetKey: 'id',
});

// Call ←→ Conversation
Call.belongsTo(Conversation, {
  as: 'conversation',
  foreignKey: 'conversation_id',
  targetKey: 'id',
});
Conversation.hasMany(Call, {
  as: 'calls',
  foreignKey: 'conversation_id',
  sourceKey: 'id',
});

// StarredMessage ←→ User & Message
StarredMessage.belongsTo(User, {
  as: 'user',
  foreignKey: 'user_id',
  targetKey: 'id',
});
StarredMessage.belongsTo(Message, {
  as: 'message',
  foreignKey: 'message_id',
  targetKey: 'id',
});
