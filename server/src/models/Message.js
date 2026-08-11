import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

export const MESSAGE_TYPES = [
  'text',
  'image',
  'voice',
  'videoCall',
  'voiceCall',
];
//,'image'
export const Message = db.define('Message', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  imageUrl: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'image_url',
  },
  voiceUrl: {
    type: DataTypes.STRING,
    allowNull: true,
    field: 'voice_url',
  },

  voiceDuration: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    field: 'voice_duration',
  },
  conversationId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'conversation_id', // Match the underscored naming
  },
  senderId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'sender_id',
  },
  text: {
    type: DataTypes.STRING(5000),
    defaultValue: '',
  },
  type: {
    type: DataTypes.ENUM(...MESSAGE_TYPES),
    defaultValue: 'text',
  },
  callUrl: {
    type: DataTypes.STRING,
    defaultValue: null,
    field: 'call_url',
  },
  readBy: {
    type: DataTypes.ARRAY(DataTypes.UUID),
    defaultValue: [],
    field: 'read_by',
  },
}, {
  timestamps: true,
  underscored: true,
  tableName: 'messages',
});
