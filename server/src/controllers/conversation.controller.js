import { z } from 'zod';
import { Op } from 'sequelize';
import { Conversation } from '../models/Conversation.js';
import { Message } from '../models/Message.js';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';
import { getOrCreateConversation } from '../services/message.service.js';
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
  const conversations = await Conversation.findAll({
    where: {
      userIds: { [Op.contains]: [req.user.id] },
    },
    order: [['updatedAt', 'DESC']],
  });

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

  // Fetch sender details for each message
  const messagesWithSenders = await Promise.all(messages.map(async (msg) => {
    const sender = await User.findByPk(msg.senderId);
    const msgJson = msg.toJSON();
    msgJson.sender = sender ? sender.toJSON() : null;
    return msgJson;
  }));

  res.json({ messages: messagesWithSenders.reverse() });
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