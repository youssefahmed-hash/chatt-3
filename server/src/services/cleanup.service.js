import fs from 'fs';
import path from 'path';
import { Op } from 'sequelize';
import { Message } from '../models/Message.js';
import { StarredMessage } from '../models/StarredMessage.js';
import { Reaction } from '../models/Reaction.js';

export async function runContentCleanup() {
  console.log('🧹 Starting content cleanup job...');
  try {
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    // 1. Find starred message IDs to protect them (active content)
    const starredMessages = await StarredMessage.findAll({
      attributes: ['messageId'],
      raw: true
    });
    const protectedIds = starredMessages.map((sm) => sm.messageId).filter(Boolean);

    // 2. Find all messages older than 30 days that are not starred
    const oldMessages = await Message.findAll({
      where: {
        createdAt: {
          [Op.lt]: thirtyDaysAgo,
        },
        id: {
          [Op.notIn]: protectedIds.length > 0 ? protectedIds : ['00000000-0000-0000-0000-000000000000'],
        },
      },
    });

    console.log(`🧹 Found ${oldMessages.length} expired messages eligible for cleanup.`);

    let filesDeleted = 0;
    for (const msg of oldMessages) {
      // Collect all possible file URLs
      const filePathsToClean = [
        msg.imageUrl,
        msg.voiceUrl,
        msg.fileUrl,
        msg.videoUrl,
        msg.videoThumbUrl
      ].filter(Boolean);

      for (const fileUrl of filePathsToClean) {
        // fileUrl is e.g. "/uploads/abc.jpg" or "http://localhost:4000/uploads/abc.jpg"
        try {
          const parts = fileUrl.split('/uploads/');
          if (parts.length > 1) {
            const relativePath = parts[1];
            const fullPath = path.resolve('uploads', relativePath);
            if (fs.existsSync(fullPath)) {
              fs.unlinkSync(fullPath);
              filesDeleted++;
            }
          }
        } catch (fileErr) {
          console.error(`❌ Failed to delete file: ${fileUrl}`, fileErr.message);
        }
      }

      // Delete associated reactions manually to prevent foreign key constraint issues
      await Reaction.destroy({
        where: {
          messageId: msg.id
        }
      });

      // Delete the message from database
      await msg.destroy();
    }

    console.log(`✅ Cleanup completed. Deleted ${oldMessages.length} messages and ${filesDeleted} media files.`);
  } catch (error) {
    console.error('❌ Error during content cleanup:', error);
  }
}

// Start recurring job every 24 hours, and run once immediately on startup
export function startCleanupInterval() {
  // Run once immediately on boot (delayed slightly to allow DB sync to finish)
  setTimeout(() => {
    runContentCleanup();
  }, 10000);

  // Run every 24 hours
  setInterval(runContentCleanup, 24 * 60 * 60 * 1000);
}
