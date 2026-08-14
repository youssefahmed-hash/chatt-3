import { z } from 'zod';
import { Op } from 'sequelize';
import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { getOrCreateConversation, serializeMessage, assertParticipant, messagePreviewText } from '../services/message.service.js';
import { emitToUsers } from '../realtime/io.js';

export const addMembersSchema = z.object({
  members: z.array(z.string()).min(1),
});

export const startConversationSchema = z.object({
  userId: z.string().min(1, 'userId is required'),
});

export const createGroupSchema = z.object({
  name: z.string().min(1),
  members: z.array(z.string()).min(1),
});

// GET /api/conversations
export const listConversations = asyncHandler(async (req, res) => {
  const { archived } = req.query;

  const all = await Conversation.findAll({
    where: {
      userIds: { [Op.contains]: [req.user.id] },
    },
    order: [['updatedAt', 'DESC']],
  });

  // archive=1 returns only archived; otherwise archived are excluded.
  const includeArchived = archived === '1';
  const conversations = all.filter((c) => {
    const isArchived = (c.archivedBy || []).includes(String(req.user.id));
    return includeArchived ? isArchived : !isArchived;
  });

// Count messages the current user has not read yet, per conversation.
  const unreadCounts = {};
  if (conversations.length) {
    const unread = await Message.findAll({
      attributes: ['conversationId', 'readBy'],
      where: {
        conversationId: { [Op.in]: conversations.map((c) => c.id) },
        senderId: { [Op.ne]: req.user.id },
      },
    });
    for (const m of unread) {
      const readBy = (m.readBy || []).map(String);
      if (!readBy.includes(String(req.user.id))) {
        const key = String(m.conversationId);
        unreadCounts[key] = (unreadCounts[key] || 0) + 1;
      }
    }
  }

const shaped = await Promise.all(
  conversations.map(async (c) => {

    if (c.isGroup) {

      const members = await User.findAll({
        where: {
          id: {
            [Op.in]: c.userIds,
          },
        },
        attributes: ['id', 'name', 'avatarUrl'],
      });

      return {
        id: c.id,
        isGroup: true,
        groupName: c.groupName,
        groupImage: c.groupImage,
        members,
        admins: c.admins,
        createdBy: c.createdBy,
        lastMessage: c.lastMessage,
        updatedAt: c.updatedAt,
        archived: (c.archivedBy || []).includes(String(req.user.id)),
        pinnedMessageIds: c.pinnedMessageIds || [],
        unreadCount: unreadCounts[String(c.id)] || 0,
      };
    }

    const peerId = c.userIds.find(
      id => id !== req.user.id,
    );

    const peer = peerId
      ? await User.findByPk(peerId)
      : null;

    return {
      id: c.id,
      isGroup: false,
      peer: peer ? peer.toJSON() : null,
      lastMessage: c.lastMessage,
      updatedAt: c.updatedAt,
      archived: (c.archivedBy || []).includes(String(req.user.id)),
      pinnedMessageIds: c.pinnedMessageIds || [],
      unreadCount: unreadCounts[String(c.id)] || 0,
    };
  }),
);

  res.json({ conversations: shaped });
});

// POST /api/conversations { userId }
export const startConversation = asyncHandler(async (req, res) => {
  const { userId } = req.body;

  const conversation = await getOrCreateConversation(req.user.id, userId);
  const peerId = conversation.userIds.find(id => id !== req.user.id);
  const peer = peerId ? await User.findByPk(peerId) : null;

  res.status(201).json({
    conversation: {
      id: conversation.id,
      peer: peer ? peer.toJSON() : null,
      lastMessage: conversation.lastMessage,
      updatedAt: conversation.updatedAt,
    },
  });
});

// POST /api/conversations/group
export const createGroup = asyncHandler(async (req, res) => {
    const name = req.body.name?.trim();

    const members = JSON.parse(req.body.members ?? "[]");
  // ضيف الأدمن تلقائياً
  const userIds = [...new Set([req.user.id, ...members])];

  let groupImage = null;

  if (req.file) {
    groupImage = `/uploads/groups/${req.file.filename}`;
  }

  const conversation = await Conversation.create({
    isGroup: true,
    groupName: name,
    groupImage,
    createdBy: req.user.id,
    admins: [req.user.id],
    userIds,
  });

    const membersData = await User.findAll({
      where: {
        id: {
          [Op.in]: userIds,
        },
      },
      attributes: ['id', 'name', 'avatarUrl'],
    });

    res.status(201).json({
      conversation: {
        ...conversation.toJSON(),
        members: membersData,
        groupImage: conversation.groupImage,
      },
    });
});


export const addMembers = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { members } = req.body;

  const conversation = await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(404, "Conversation not found");
  }

  if (!conversation.isGroup) {
    throw new ApiError(400, "Not a group");
  }

  if (!conversation.admins.includes(req.user.id)) {
    throw new ApiError(403, "Admins only");
  }

  const userIds = [
    ...new Set([
      ...conversation.userIds,
      ...members,
    ]),
  ];

  conversation.userIds = userIds;

  await conversation.save();

  const membersData = await User.findAll({
    where: {
      id: {
        [Op.in]: userIds,
      },
    },
    attributes: [
      'id',
      'name',
      'avatar_url',
    ],
  });

    emitToUsers(
      members,
      'group:added',
      {
        conversation: {
          ...conversation.toJSON(),
          members: membersData,
        },
      },
    );

  res.json({
    members: membersData,
  });
});

export const removeMember = asyncHandler(async (req, res) => {
  const { id, memberId } = req.params;

  const conversation = await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(404, "Conversation not found");
  }

  if (!conversation.isGroup) {
    throw new ApiError(400, "Not a group");
  }

  if (!conversation.admins.includes(req.user.id)) {
    throw new ApiError(403, "Admins only");
  }

  if (memberId === req.user.id) {
    throw new ApiError(
      400,
      "Use Leave Group instead",
    );
  }

  // احتفظ بقائمة الأعضاء قبل الحذف
  const oldUserIds = [...conversation.userIds];

  // إزالة العضو من الجروب
  conversation.userIds = conversation.userIds.filter(
    (u) => u !== memberId,
  );

  // إزالة صلاحية الأدمن لو كان أدمن
  conversation.admins = conversation.admins.filter(
    (u) => u !== memberId,
  );

  await conversation.save();

  const membersData = await User.findAll({
    where: {
      id: {
        [Op.in]: conversation.userIds,
      },
    },
    attributes: [
      "id",
      "name",
      "avatarUrl",
    ],
  });

  // إرسال التحديث لكل من كان في الجروب قبل الحذف
  emitToUsers(
    oldUserIds,
    "group:membersUpdated",
    {
      conversationId: conversation.id,
      members: membersData,
    },
  );

  res.json({
    members: membersData,
  });
});

export const makeAdmin = asyncHandler(async (req, res) => {

  const { id, memberId } = req.params;

  const conversation =
    await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(
      404,
      "Conversation not found",
    );
  }

  if (!conversation.isGroup) {
    throw new ApiError(
      400,
      "Not a group",
    );
  }

  if (!conversation.admins.includes(req.user.id)) {
    throw new ApiError(
      403,
      "Admins only",
    );
  }

  if (!conversation.userIds.includes(memberId)) {
    throw new ApiError(
      400,
      "User not in group",
    );
  }

if (!conversation.admins.includes(memberId)) {
  conversation.admins = [
    ...conversation.admins,
    memberId,
  ];
}

await conversation.save();

  emitToUsers(
    conversation.userIds,
    'group:adminsUpdated',
    {
      conversationId: conversation.id,
      admins: conversation.admins,
    },
  );

  res.json({
    admins: conversation.admins,
  });

});

export const updateGroupName = asyncHandler(async (req, res) => {

  const { id } = req.params;
  const { name } = req.body;

  const conversation = await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(
      404,
      "Conversation not found",
    );
  }

  if (!conversation.isGroup) {
    throw new ApiError(
      400,
      "Not a group",
    );
  }

  if (!conversation.admins.includes(req.user.id)) {
    throw new ApiError(
      403,
      "Admins only",
    );
  }

  conversation.groupName = name.trim();

  await conversation.save();

  emitToUsers(
    conversation.userIds,
    "group:updated",
    {
      conversationId: conversation.id,
      groupName: conversation.groupName,
    },
  );

  res.json({
    groupName: conversation.groupName,
  });

});

export const removeAdmin = asyncHandler(async (req, res) => {

  const { id, memberId } = req.params;

  const conversation =
    await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(
      404,
      "Conversation not found",
    );
  }

  if (!conversation.isGroup) {
    throw new ApiError(
      400,
      "Not a group",
    );
  }

  // فقط منشئ الجروب يقدر يشيل الأدمن
  if (conversation.createdBy !== req.user.id) {
    throw new ApiError(
      403,
      "Only group creator can remove admins",
    );
  }

  // ممنوع إزالة منشئ الجروب
  if (memberId === conversation.createdBy) {
    throw new ApiError(
      400,
      "Creator cannot be removed from admins",
    );
  }

  if (!conversation.admins.includes(memberId)) {
    throw new ApiError(
      400,
      "User is not an admin",
    );
  }

    conversation.admins =
      conversation.admins.filter(
        id => id !== memberId,
      );

  await conversation.save();

  emitToUsers(
    conversation.userIds,
    'group:adminsUpdated',
    {
      conversationId: conversation.id,
      admins: conversation.admins,
    },
  );

  res.json({
    admins: conversation.admins,
  });

});



export const leaveGroup = asyncHandler(async (req, res) => {

  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(404, "Conversation not found");
  }

  if (!conversation.isGroup) {
    throw new ApiError(400, "Not a group");
  }

  if (!conversation.userIds.includes(req.user.id)) {
    throw new ApiError(403, "You are not a member");
  }

  // Remove member from group
  conversation.userIds =
      conversation.userIds.filter(
        u => u !== req.user.id,
      );

  // Remove from admins if needed
  conversation.admins =
      conversation.admins.filter(
        u => u !== req.user.id,
      );

  // لو الجروب بقى فاضي
  if (conversation.userIds.length == 0) {

    await conversation.destroy();

    return res.json({
      deleted: true,
    });

  }

  // لو اللي خرج هو منشئ الجروب
if (conversation.createdBy === req.user.id) {

  let newCreator;

  if (conversation.admins.length > 0) {

    newCreator = conversation.admins[0];

  } else {

    newCreator = conversation.userIds[0];

    conversation.admins.push(newCreator);

  }

  conversation.createdBy = newCreator;

}
  await conversation.save();

  const members = await User.findAll({

    where: {
      id: {
        [Op.in]: conversation.userIds,
      },
    },

    attributes: [
      "id",
      "name",
      "avatarUrl",
    ],

  });

  emitToUsers(

    conversation.userIds,

    "group:membersUpdated",

    {

      conversationId: conversation.id,

      members,

    },

  );

  emitToUsers(

    conversation.userIds,

    "group:adminsUpdated",

    {

      conversationId: conversation.id,

      admins: conversation.admins,

    },

  );

  res.json({

    members,

    admins: conversation.admins,

    createdBy: conversation.createdBy,

  });

});

// GET /api/conversations/:id/messages?before=<ISO>&limit=30
export const listMessages = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');

  const isParticipant = conversation.userIds.includes(String(req.user.id));
  if (!isParticipant) throw new ApiError(403, 'Access denied');

  const limit = Math.min(Number(req.query.limit) || 30, 100);
  const where = { conversationId: id };

  if (req.query.before) {
    const before = new Date(req.query.before);
    if (!Number.isNaN(before.getTime())) {
      where.createdAt = { [Op.lt]: before };
    }
  }

  const messages = await Message.findAll({
    where,
    order: [['createdAt', 'DESC']],
    limit,
  });

  const serialized = [];
  for (const msg of messages) {
    serialized.push(await serializeMessage(msg, req.user.id));
  }

  res.json({ messages: serialized.reverse() });
});

// GET /api/conversations/:id/messages/search?q=<query>
export const searchMessages = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const q = String(req.query.q || '').trim();

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  if (!q) {
    return res.json({ messages: [] });
  }

  const messages = await Message.findAll({
    where: {
      conversationId: id,
      [Op.or]: [
        { text: { [Op.iLike]: `%${q}%` } },
        { fileName: { [Op.iLike]: `%${q}%` } },
      ],
    },
    order: [['createdAt', 'DESC']],
    limit: 100,
  });

  const serialized = [];
  for (const msg of messages) {
    serialized.push(await serializeMessage(msg, req.user.id));
  }

  res.json({ messages: serialized.reverse() });
});

// GET /api/conversations/:id/messages/context?around=<messageId>&limit=<n>
// Returns messages surrounding a specific message so the client can render
// and scroll to it without loading the entire conversation.
export const messageContext = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const around = String(req.query.around || '');
  const limit = Math.min(Number(req.query.limit) || 20, 50);

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  const target = around ? await Message.findByPk(around) : null;
  if (!target) {
    throw new ApiError(404, 'Message not found');
  }
  if (String(target.conversationId) !== String(id)) {
    throw new ApiError(400, 'Message does not belong to this conversation');
  }

  const before = await Message.findAll({
    where: { conversationId: id, createdAt: { [Op.lte]: target.createdAt } },
    order: [['createdAt', 'DESC']],
    limit,
  });

  const after = await Message.findAll({
    where: { conversationId: id, createdAt: { [Op.gt]: target.createdAt } },
    order: [['createdAt', 'ASC']],
    limit,
  });

  const all = [...after.reverse(), ...before.reverse()];

  const serialized = [];
  for (const msg of all) {
    serialized.push(await serializeMessage(msg, req.user.id));
  }

  res.json({ messages: serialized, aroundId: String(around) });
});

// ============================================================
// PIN MESSAGES
// ============================================================
export const pinMessage = asyncHandler(async (req, res) => {
  const { id, messageId } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  // Only admins may pin messages in groups.
  if (conversation.isGroup && !conversation.admins.includes(String(req.user.id))) {
    throw new ApiError(403, 'Only admins can pin messages');
  }

  const message = await Message.findByPk(messageId);
  if (!message) throw new ApiError(404, 'Message not found');
  if (String(message.conversationId) !== String(id)) {
    throw new ApiError(400, 'Message does not belong to this conversation');
  }

  const pins = conversation.pinnedMessageIds || [];
  if (!pins.includes(String(messageId))) {
    conversation.pinnedMessageIds = [String(messageId), ...pins].slice(0, 10);
    await conversation.save();
  }

  emitToUsers(conversation.userIds, 'message:pinned', {
    conversationId: String(id),
    messageId: String(messageId),
    pinnedMessageIds: conversation.pinnedMessageIds,
    pinnedBy: String(req.user.id),
  });

  res.json({ pinnedMessageIds: conversation.pinnedMessageIds });
});

export const unpinMessage = asyncHandler(async (req, res) => {
  const { id, messageId } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  if (conversation.isGroup && !conversation.admins.includes(String(req.user.id))) {
    throw new ApiError(403, 'Only admins can unpin messages');
  }

  conversation.pinnedMessageIds = (conversation.pinnedMessageIds || []).filter(
    (m) => String(m) !== String(messageId),
  );
  await conversation.save();

  emitToUsers(conversation.userIds, 'message:unpinned', {
    conversationId: String(id),
    messageId: String(messageId),
    pinnedMessageIds: conversation.pinnedMessageIds,
  });

  res.json({ pinnedMessageIds: conversation.pinnedMessageIds });
});

export const listPinnedMessages = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  const ids = conversation.pinnedMessageIds || [];
  const messages = await Message.findAll({
    where: { id: { [Op.in]: ids } },
  });

  const ordered = [];
  for (const mid of ids) {
    const m = messages.find((x) => String(x.id) === String(mid));
    if (m) ordered.push(await serializeMessage(m, req.user.id));
  }

  res.json({ messages: ordered });
});

// ============================================================
// ARCHIVE
// ============================================================
export const archiveConversation = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  const archivedBy = conversation.archivedBy || [];
  if (!archivedBy.includes(String(req.user.id))) {
    conversation.archivedBy = [...archivedBy, String(req.user.id)];
    await conversation.save();
  }

  emitToUsers([String(req.user.id)], 'conversation:archived', {
    conversationId: String(id),
    archived: true,
  });

  res.json({ archived: true });
});

export const unarchiveConversation = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  await assertParticipant(conversation, req.user.id);

  conversation.archivedBy = (conversation.archivedBy || []).filter(
    (u) => String(u) !== String(req.user.id),
  );
  await conversation.save();

  emitToUsers([String(req.user.id)], 'conversation:archived', {
    conversationId: String(id),
    archived: false,
  });

  res.json({ archived: false });
});

export const listArchivedConversations = asyncHandler(async (req, res) => {
  req.query.archived = '1';
  await listConversations(req, res);
});

export const updateGroupNameSchema = z.object({
  name: z.string().min(1).max(50),
});

export const updateGroupImage = asyncHandler(async (req, res) => {

  const { id } = req.params;

  const conversation = await Conversation.findByPk(id);

  if (!conversation) {
    throw new ApiError(
      404,
      "Conversation not found",
    );
  }

  if (!conversation.isGroup) {
    throw new ApiError(
      400,
      "Not a group",
    );
  }

  if (!conversation.admins.includes(req.user.id)) {
    throw new ApiError(
      403,
      "Admins only",
    );
  }

  if (!req.file) {
    throw new ApiError(
      400,
      "Image is required",
    );
  }

  conversation.groupImage =
      `/uploads/groups/${req.file.filename}`;

  await conversation.save();

  emitToUsers(
    conversation.userIds,
    "group:updated",
    {
      conversationId: conversation.id,
      groupName: conversation.groupName,
      groupImage: conversation.groupImage,
    },
  );

  res.json({
    groupImage: conversation.groupImage,
  });

});