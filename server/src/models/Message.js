import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

export const MESSAGE_TYPES = [
  'text',
  'image',
  'voice',
  'videoCall',
  'voiceCall',
  'file',
  'video',
];

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
  // Client-generated id (e.g. a temp id from the offline queue) used to
  // correlate the sender's local placeholder with the persisted echo.
  clientId: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'client_id',
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
  // edited indicator
  edited: {
    type: DataTypes.BOOLEAN,
    allowNull: false,
    defaultValue: false,
  },
  // reply reference
  replyToId: {
    type: DataTypes.UUID,
    allowNull: true,
    defaultValue: null,
    field: 'reply_to_id',
  },
  // forward reference
  forwardedFrom: {
    type: DataTypes.UUID,
    allowNull: true,
    defaultValue: null,
    field: 'forwarded_from',
  },
  // file metadata
  fileUrl: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'file_url',
  },
  fileName: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'file_name',
  },
  fileSize: {
    type: DataTypes.BIGINT,
    allowNull: true,
    defaultValue: null,
    field: 'file_size',
  },
  fileType: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'file_type',
  },
  // video metadata
  videoUrl: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'video_url',
  },
  videoThumbUrl: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'video_thumb_url',
  },
}, {
  timestamps: true,
  underscored: true,
  tableName: 'messages',
});
