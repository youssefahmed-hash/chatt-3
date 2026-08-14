import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

// Per-user starred messages.
export const StarredMessage = db.define('StarredMessage', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'user_id',
  },
  messageId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'message_id',
  },
  conversationId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'conversation_id',
  },
}, {
  timestamps: true,
  underscored: true,
  tableName: 'starred_messages',
  indexes: [
    {
      unique: true,
      fields: ['user_id', 'message_id'],
      name: 'starred_user_message_unique',
    },
    { fields: ['user_id'] },
  ],
});
