import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

// Push device registration (web push subscription JSON, or a native push
// token once FCM credentials are provided).
export const Device = db.define(
  'Device',
  {
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
    token: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    platform: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'web',
      field: 'platform',
    },
    updatedAt: {
      type: DataTypes.DATE,
      allowNull: false,
      defaultValue: DataTypes.NOW,
      field: 'updated_at',
    },
  },
  {
    tableName: 'devices',
    indexes: [
      {
        unique: true,
        fields: ['user_id', 'token'],
      },
    ],
  },
);