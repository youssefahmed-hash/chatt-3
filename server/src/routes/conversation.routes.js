import { Router } from 'express';
import {
  listConversations,
  startConversation,
  listMessages,
  startConversationSchema,
  createGroup,
  createGroupSchema,
  addMembers,
  addMembersSchema,
  removeMember,
  makeAdmin,
  removeAdmin,
  leaveGroup,
  updateGroupNameSchema,
  updateGroupName,
  updateGroupImage,
} from '../controllers/conversation.controller.js';

import {
  sendMessage,
  sendMessageSchema,
  sendImageMessage,
  sendVoiceMessage,
} from '../controllers/message.controller.js';

import { protect } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  upload,
  groupUpload,
  voiceUpload,
} from '../middleware/upload.js';
const router = Router();

router.use(protect);

router.get('/', listConversations);
router.post('/', validate(startConversationSchema), startConversation);
router.post(
  '/group',
  groupUpload.single('image'),
  createGroup,
);

router.post(
  '/:id/messages/voice',
  voiceUpload.single('voice'),
  sendVoiceMessage,
);

router.post(
  '/:id/members',
  validate(addMembersSchema),
  addMembers,
);

router.get('/:id/messages', listMessages);

router.post('/:id/messages', validate(sendMessageSchema), sendMessage);

router.post(
  '/:id/messages/image',
  upload.single('image'),
  sendImageMessage,
);

router.delete(
  '/:id/members/:memberId',
  removeMember,
);

router.patch(
  '/:id/admins/:memberId',
  makeAdmin,
);

router.delete(
  '/:id/admins/:memberId',
  removeAdmin,
);

router.post(
  '/:id/leave',
  leaveGroup,
);

router.patch(
  '/:id/name',
  validate(updateGroupNameSchema),
  updateGroupName,
);

router.patch(
  "/:id/image",
  protect,
  groupUpload.single("image"),
  updateGroupImage,
);

export default router;