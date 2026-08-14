import { Op } from 'sequelize';
import { Call } from '../models/Call.js';
import { Conversation } from '../models/Conversation.js';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';

// GET /api/calls — calls involving the current user (voice/video history).
export const listCalls = asyncHandler(async (req, res) => {
  const conversations = await Conversation.findAll({
    where: {
      userIds: { [Op.contains]: [req.user.id] },
    },
    attributes: ['id'],
  });

  const convIds = conversations.map((c) => c.id);

  const calls = await Call.findAll({
    where: {
      [Op.or]: [
        { conversationId: { [Op.in]: convIds } },
        { callerId: req.user.id },
      ],
    },
    order: [['createdAt', 'DESC']],
    limit: 200,
  });

  const shaped = await Promise.all(
    calls.map(async (call) => {
      const conversation = await Conversation.findByPk(call.conversationId);
      const caller = await User.findByPk(call.callerId, {
        attributes: ['id', 'name', 'avatarUrl'],
      });

      let name = '';
      let isGroup = false;
      let avatarUrl = null;

      if (conversation && conversation.isGroup) {
        name = conversation.groupName || 'Group call';
        isGroup = true;
        avatarUrl = conversation.groupImage;
      } else if (conversation) {
        const peerId = conversation.userIds.find((id) => String(id) !== String(req.user.id));
        const peer = peerId ? await User.findByPk(peerId) : null;
        name = peer ? peer.name : 'Unknown';
        isGroup = false;
        avatarUrl = peer ? peer.avatarUrl : null;
      }

      // Which "direction" does the current user see?
      let direction = 'outgoing';
      if (String(call.callerId) === String(req.user.id)) {
        direction = call.status === 'missed' ? 'missed' : 'outgoing';
      } else {
        if (call.status === 'rejected') direction = 'rejected';
        else if (call.status === 'incoming' || call.status === 'ended') direction = 'incoming';
        else direction = 'missed';
      }

      return {
        id: call.id,
        conversationId: call.conversationId,
        type: call.type,
        direction,
        status: call.status,
        name,
        isGroup,
        avatarUrl,
        callerName: caller ? caller.name : '',
        startedAt: call.startedAt || call.createdAt,
        endedAt: call.endedAt,
        duration: call.duration,
      };
    }),
  );

  res.json({ calls: shaped });
});

// POST /api/calls — explicit logging from the client (e.g. missed after ring).
export const logCallSchema = null;

export const logCall = asyncHandler(async (req, res) => {
  const { conversationId, type, status, startedAt, endedAt, duration } = req.body || {};

  const conversation = await Conversation.findByPk(conversationId);
  if (!conversation) throw new ApiError(404, 'Conversation not found');
  if (!conversation.userIds.includes(String(req.user.id))) {
    throw new ApiError(403, 'Not part of this conversation');
  }

  const call = await Call.create({
    conversationId,
    callerId: req.user.id,
    type: type === 'video' ? 'video' : 'voice',
    status: status || 'ended',
    startedAt: startedAt || new Date(),
    endedAt: endedAt || null,
    duration: Number(duration) || 0,
    participants: conversation.userIds,
  });

  res.status(201).json({ call });
});
