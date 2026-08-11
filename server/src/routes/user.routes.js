import { Router } from 'express';
import {
  listUsers,
  getUser,
  updateProfile,
  getProfile,
  updateAvatar
} from '../controllers/user.controller.js';

import { protect } from '../middleware/auth.js';
import { avatarUpload } from '../middleware/upload.js';

const router = Router();

router.use(protect);

router.get('/', listUsers);

router.get('/profile', getProfile);

router.put('/profile', updateProfile);

router.put(
  '/avatar',
  avatarUpload.single('avatar'),
  updateAvatar
);

router.get('/:id', getUser);

export default router;