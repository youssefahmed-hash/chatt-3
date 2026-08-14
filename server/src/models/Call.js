import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

export const CALL_STATUSES = [
  'incoming',
  'outgoing',
  'missed',
  'rejected',
  'ended',
];

// Call history record (voice / video calls, 1-on-1 and group).
export const Call = db.define('Call', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  conversationId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'conversation_id',
  },
  callerId: {
    type: DataTypes.UUID,
    allowNull: false,
    field: 'caller_id',
  },
  type: {
    type: DataTypes.STRING(16),
    allowNull: false,
    defaultValue: 'voice',
  },
  status: {
    type: DataTypes.ENUM(...CALL_STATUSES),
    allowNull: false,
    defaultValue: 'outgoing',
  },
  roomName: {
    type: DataTypes.STRING,
    allowNull: true,
    defaultValue: null,
    field: 'room_name',
  },
  startedAt: {
    type: DataTypes.DATE,
    allowNull: true,
    defaultValue: null,
    field: 'started_at',
  },
  endedAt: {
    type: DataTypes.DATE,
    allowNull: true,
    defaultValue: null,
    field: 'ended_at',
  },
  duration: {
    type: DataTypes.INTEGER,
    allowNull: false,
    defaultValue: 0,
  },
  participants: {
    type: DataTypes.ARRAY(DataTypes.UUID),
    allowNull: false,
    defaultValue: [],
  },
}, {
  timestamps: true,
  underscored: true,
  tableName: 'calls',
  indexes: [
    { fields: ['conversation_id'] },
    { fields: ['caller_id'] },
  ],
});
