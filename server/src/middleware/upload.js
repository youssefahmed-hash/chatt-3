import multer from 'multer';
import path from 'path';
import fs from 'fs';

function createStorage(folder) {
  const dir = `uploads/${folder}`;

  fs.mkdirSync(dir, {
    recursive: true,
  });

  return multer.diskStorage({
    destination(req, file, cb) {
      cb(null, dir);
    },

    filename(req, file, cb) {
      const ext = path.extname(file.originalname);

      cb(
        null,
        `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`,
      );
    },
  });
}

// 👇 القديم للرسائل (متسيبوش)
export const upload = multer({
  storage: createStorage('messages'),
});

// 👇 جديد للجروبات
export const groupUpload = multer({
  storage: createStorage('groups'),
});

// 👇 هنستخدمه بعدين
export const avatarUpload = multer({
  storage: createStorage('avatars'),
});

export const voiceUpload = multer({
  storage: createStorage('voices'),
});

// 👇 للملفات
export const fileUpload = multer({
  storage: createStorage('files'),
  limits: {
    fileSize: 100 * 1024 * 1024, // 100 MB
  },
});

// 👇 للفيديوهات
export const videoUpload = multer({
  storage: createStorage('videos'),
  limits: {
    fileSize: 250 * 1024 * 1024, // 250 MB
  },
});