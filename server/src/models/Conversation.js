import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

export const Conversation = db.define(
  'Conversation',
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true,
    },

    // هل المحادثة جروب؟
    isGroup: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      field: 'is_group',
    },

    // اسم الجروب
    groupName: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null,
      field: 'group_name',
    },

    // صورة الجروب
    groupImage: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null,
      field: 'group_image',
    },

    // منشئ الجروب
    createdBy: {
      type: DataTypes.UUID,
      allowNull: true,
      defaultValue: null,
      field: 'created_by',
    },

    // الأدمنز
    admins: {
      type: DataTypes.ARRAY(DataTypes.UUID),
      allowNull: false,
      defaultValue: [],
      field: 'admins',
    },

    // أعضاء المحادثة
    userIds: {
      type: DataTypes.ARRAY(DataTypes.UUID),
      allowNull: false,
      defaultValue: [],
      field: 'user_ids',
    },

    // آخر رسالة
    lastMessage: {
      type: DataTypes.JSON,
      defaultValue: {
        text: '',
        sender: null,
        at: null,
      },
      field: 'last_message',
    },

    // الرسائل المثبتة (بالترتيب: أحدث أولاً)
    pinnedMessageIds: {
      type: DataTypes.ARRAY(DataTypes.UUID),
      allowNull: false,
      defaultValue: [],
      field: 'pinned_message_ids',
    },

    // مستخدمو المحادثة اللذين أرشيفوها
    archivedBy: {
      type: DataTypes.ARRAY(DataTypes.UUID),
      allowNull: false,
      defaultValue: [],
      field: 'archived_by',
    },
  },
  {
    timestamps: true,
    underscored: true,
    tableName: 'conversations',
  },
);