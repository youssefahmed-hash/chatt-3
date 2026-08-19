import { Router } from 'express';
import {
  listConversations,
  startConversation,
  listMessages,
  searchMessages,
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
  pinMessage,
  unpinMessage,
  listPinnedMessages,
  pinConversation,
  unpinConversation,
  archiveConversation,
  unarchiveConversation,
  listArchivedConversations,
  messageContext,
} from '../controllers/conversation.controller.js';

import {
  sendMessage,
  sendMessageSchema,
  sendImageMessage,
  sendVoiceMessage,
  editMessage,
  editMessageSchema,
  addReaction,
  addReactionSchema,
  removeReaction,
  forwardMessage,
  forwardMessageSchema,
  sendFileMessage,
  sendVideoMessage,
  starMessage,
  unstarMessage,
  listStarredMessages,
} from '../controllers/message.controller.js';

import { protect } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import {
  upload,
  groupUpload,
  voiceUpload,
  fileUpload,
  videoUpload,
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
  '/:id/messages/file',
  fileUpload.single('file'),
  sendFileMessage,
);

router.post(
  '/:id/messages/video',
  videoUpload.single('video'),
  sendVideoMessage,
);

router.post(
  '/:id/members',
  validate(addMembersSchema),
  addMembers,
);

router.get('/:id/messages', listMessages);
router.get('/:id/messages/search', searchMessages);
router.get('/:id/messages/context', messageContext);

router.post('/:id/messages', validate(sendMessageSchema), sendMessage);

router.post(
  '/:id/messages/image',
  upload.single('image'),
  sendImageMessage,
);

// Forward a message into this conversation.
router.post(
  '/:id/messages/forward',
  validate(forwardMessageSchema),
  forwardMessage,
);

// Edit own text message.
router.patch(
  '/:id/messages/:messageId',
  validate(editMessageSchema),
  editMessage,
);

// Reactions.
router.post(
  '/:id/messages/:messageId/reactions',
  validate(addReactionSchema),
  addReaction,
);
router.delete(
  '/:id/messages/:messageId/reactions/:emoji',
  removeReaction,
);

// Star / unstar a message.
router.post(
  '/:id/messages/:messageId/star',
  starMessage,
);
router.delete(
  '/:id/messages/:messageId/star',
  unstarMessage,
);

// Starred messages (global, per-user).
router.get('/starred', listStarredMessages);

// Pin / unpin.
router.post('/:id/pins/:messageId', pinMessage);
router.delete('/:id/pins/:messageId', unpinMessage);
router.get('/:id/pins', listPinnedMessages);

// Pin / unpin CHATS (per-user).
router.post('/:id/pin', pinConversation);
router.delete('/:id/pin', unpinConversation);

// Archive / unarchive.
router.post('/:id/archive', archiveConversation);
router.delete('/:id/archive', unarchiveConversation);
router.get('/archived', listArchivedConversations);

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
