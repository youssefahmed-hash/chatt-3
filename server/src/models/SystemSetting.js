import { DataTypes } from "sequelize";
import { db } from "../config/database.js";

export const SystemSetting = db.define(
  "SystemSetting",
  {
    key: {
      type: DataTypes.STRING,
      primaryKey: true,
      unique: true,
      allowNull: false,
    },
    value: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
  },
  {
    timestamps: true,
    tableName: 'system_settings',
    underscored: true,
  }
);
