import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

// An emoji reaction left on a message by a user.
// Unique constraint prevents duplicate same-user + same-emoji reactions.
export const Reaction = db.define('Reaction', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  messageId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'message_id',
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'user_id',
  },
  emoji: {
    type: DataTypes.STRING(32),
    allowNull: false,
  },
}, {
  timestamps: true,
  underscored: true,
  tableName: 'reactions',
  indexes: [
    {
      unique: true,
      fields: ['message_id', 'user_id', 'emoji'],
      name: 'reactions_message_user_emoji_unique',
    },
  ],
});
