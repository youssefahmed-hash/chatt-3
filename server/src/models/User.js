import { DataTypes } from 'sequelize';
import { db } from '../config/database.js';

export const User = db.define('User', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  email: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
  },
  passwordHash: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  avatarUrl: {
    type: DataTypes.STRING,
    defaultValue: '',
  },
  bio: {
    type: DataTypes.TEXT,
    defaultValue: '',
  },
  online: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  lastSeen: {
    type: DataTypes.DATE,
    defaultValue: null,
  },
}, {
  timestamps: true,
  underscored: true,
});

import bcrypt from 'bcryptjs';

User.prototype.comparePassword = async function(password) {
  return bcrypt.compare(password, this.passwordHash);
};

User.prototype.toJSON = function() {
  const values = Object.assign({}, this.get());
  delete values.passwordHash;
  return values;
};

User.addHook('beforeValidate', async (user) => {
  if (user.changed('passwordHash') && user.passwordHash && !user.passwordHash.startsWith('$2')) {
    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(user.passwordHash, salt);
  }
});
