import { User } from '../models/User.js';
import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';

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
