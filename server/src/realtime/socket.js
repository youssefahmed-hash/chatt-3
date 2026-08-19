import { Server } from 'socket.io';
import { Op } from 'sequelize';
import { env } from '../config/env.js';
import { User } from '../models/User.js';
import { Message } from '../models/Message.js';
import { Conversation } from '../models/Conversation.js';
import { Reaction } from '../models/Reaction.js';
import { Call } from '../models/Call.js';
import { verifyToken } from '../utils/token.js';
import { createMessage, serializeMessage, assertParticipant } from '../services/message.service.js';
import { setIO, userRoom, emitToUsers, emitToUsersPerViewer } from './io.js';

// Group message-type -> call type mapping for call history.
function callTypeFor(type) {
  return type === 'videoCall' ? 'video' : 'voice';
}

export function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: env.corsOrigin,
      methods: ['GET', 'POST'],
    },
  });

  setIO(io);

  // userId -> Set of connected socket ids. The adapter-room check inside
  // 'disconnect' is unreliable (the socket may already have left its rooms),
  // so track connected sockets explicitly to avoid stale online status.
  const onlineUsers = new Map();

  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      if (!token) return next(new Error('Authentication required'));
      const userId = verifyToken(token);
      const user = await User.findByPk(userId);
      if (!user) return next(new Error('User not found'));
      socket.userId = String(user.id);
      next();
    } catch {
      next(new Error('Invalid or expired token'));
    }
  });

  io.on('connection', async (socket) => {
    const { userId } = socket;
    socket.join(userRoom(userId));

    // ================= MESSAGE SEND =================

    socket.on('message:send', async (payload = {}, ack) => {
      try {
        const message = await createMessage({
          conversationId: payload.conversationId,
          senderId: userId,
          text: payload.text,
          type: payload.type || 'text',
          callUrl: payload.callUrl || null,
          replyToId: payload.replyToId || null,
          forwardedFrom: payload.forwardedFrom || null,
          clientId: payload.clientId || null,
        });

        if (typeof ack === 'function') {
          ack({
            ok: true,
            message,
          });
        }
      } catch (err) {
        if (typeof ack === 'function') {
          ack({
            ok: false,
            error: err.message || 'Failed to send message',
          });
        }
      }
    });

    // ================= MESSAGE EDIT =================

    socket.on('message:edit', async (payload = {}, ack) => {
      try {
        const { conversationId, messageId, text } = payload;
        if (!conversationId || !messageId || !text || !text.trim()) {
          return ack?.({ ok: false, error: 'Invalid edit payload' });
        }

        const message = await Message.findByPk(messageId);
        if (!message) return ack?.({ ok: false, error: 'Message not found' });
        if (String(message.conversationId) !== String(conversationId)) {
          return ack?.({ ok: false, error: 'Message does not belong to this conversation' });
        }
        if (String(message.senderId) !== String(userId)) {
          return ack?.({ ok: false, error: 'You can only edit your own messages' });
        }
        if (message.type !== 'text') {
          return ack?.({ ok: false, error: 'Only text messages can be edited' });
        }

        message.text = text.trim();
        message.edited = true;
        await message.save();

        const conversation = await Conversation.findByPk(conversationId);
        if (conversation && conversation.lastMessage &&
            String(conversation.lastMessage.sender) === String(userId)) {
          conversation.lastMessage.text = message.text;
          await conversation.save();
        }

        const serialized = await serializeMessage(message, userId);
        // Serialize per viewer so reaction/read state matches each device's own
        // perspective; the sender's own view is reused for the ack below.
        await emitToUsersPerViewer(conversation.userIds, 'message:edited', async (viewerId) => {
          const viewerMessage =
            String(viewerId) === String(userId)
              ? serialized
              : await serializeMessage(message, viewerId);
          return {
            conversationId: String(conversationId),
            message: viewerMessage,
          };
        });

        ack?.({ ok: true, message: serialized });
      } catch (err) {
        ack?.({ ok: false, error: err.message || 'Failed to edit message' });
      }
    });

    // ================= REACTION ADD / REMOVE =================

    socket.on('reaction:add', async (payload = {}, ack) => {
      try {
        const { conversationId, messageId, emoji } = payload;
        if (!conversationId || !messageId || !emoji) {
          return ack?.({ ok: false, error: 'Invalid reaction payload' });
        }

        const conversation = await Conversation.findByPk(conversationId);
        if (!conversation) return ack?.({ ok: false, error: 'Conversation not found' });
        await assertParticipant(conversation, userId);

        const message = await Message.findByPk(messageId);
        if (!message || String(message.conversationId) !== String(conversationId)) {
          return ack?.({ ok: false, error: 'Message not found' });
        }

        // WhatsApp semantics: ONE reaction per user per message. Tapping a
        // different emoji replaces the previous one (the old emoji count
        // drops, the new one counts) — only the OTHER users' reactions keep
        // their own emoji counters.
        const existing = await Reaction.findOne({
          where: { messageId, userId, emoji },
        });

        let changed = false;
        if (!existing) {
          await Reaction.destroy({ where: { messageId, userId } });
          await Reaction.create({ messageId, userId, emoji });
          changed = true;
        }

        const serialized = await serializeMessage(message, userId);

        if (changed) {
          emitToUsers(conversation.userIds, 'reaction:added', {
            conversationId: String(conversationId),
            messageId: String(messageId),
            emoji,
            userId,
            reactions: serialized.reactions,
          });
        }

        ack?.({ ok: true, reactions: serialized.reactions });
      } catch (err) {
        ack?.({ ok: false, error: err.message || 'Failed to add reaction' });
      }
    });

    socket.on('reaction:remove', async (payload = {}, ack) => {
      try {
        const { conversationId, messageId, emoji } = payload;
        if (!conversationId || !messageId || !emoji) {
          return ack?.({ ok: false, error: 'Invalid reaction payload' });
        }

        const conversation = await Conversation.findByPk(conversationId);
        if (!conversation) return ack?.({ ok: false, error: 'Conversation not found' });
        await assertParticipant(conversation, userId);

        const message = await Message.findByPk(messageId);
        if (!message || String(message.conversationId) !== String(conversationId)) {
          return ack?.({ ok: false, error: 'Message not found' });
        }

        await Reaction.destroy({ where: { messageId, userId, emoji } });

        const serialized = await serializeMessage(message, userId);

        emitToUsers(conversation.userIds, 'reaction:removed', {
          conversationId: String(conversationId),
          messageId: String(messageId),
          emoji,
          userId,
          reactions: serialized.reactions,
        });

        ack?.({ ok: true, reactions: serialized.reactions });
      } catch (err) {
        ack?.({ ok: false, error: err.message || 'Failed to remove reaction' });
      }
    });

    // ================= TYPING =================

    socket.on('typing', async (payload = {}) => {
      if (!payload.conversationId) return;

      try {
        const conversation = await Conversation.findByPk(payload.conversationId);
        if (!conversation) return;
        if (!conversation.userIds.includes(String(userId))) return;

        const targets = conversation.userIds.filter(
          (id) => String(id) !== String(userId),
        );

        emitToUsers(targets, 'typing', {
          conversationId: payload.conversationId,
          userId,
          typing: !!payload.typing,
        });
      } catch {
        // ignore
      }
    });

    // ================= MESSAGE READ =================

    socket.on('message:read', async (payload = {}) => {
      if (!payload.conversationId) return;

      // Mark messages sent by others as read by this user (append to readBy),
      // without wiping read receipts that are already recorded.
      try {
        const unread = await Message.findAll({
          where: {
            conversationId: payload.conversationId,
            senderId: { [Op.ne]: userId },
          },
        });

        const changed = [];
        for (const msg of unread) {
          const readBy = msg.readBy || [];
          if (!readBy.map(String).includes(String(userId))) {
            msg.readBy = [...readBy, userId];
            await msg.save();
            changed.push(msg);
          }
        }

        if (changed.length) {
          const serialized = await Promise.all(
            changed.map((m) => serializeMessage(m, userId)),
          );

          // Direct chats target the single peer; groups target every other
          // participant so each member's sent messages update their ticks.
          const conversation = await Conversation.findByPk(payload.conversationId);
          const targets = payload.peerId
            ? [payload.peerId]
            : conversation && conversation.userIds
              ? conversation.userIds.filter((id) => String(id) !== String(userId))
              : [];

          emitToUsers(targets, 'message:read', {
            conversationId: payload.conversationId,
            readerId: userId,
            messages: serialized,
          });
        }
      } catch {
        // ignore
      }
    });

    // ================= RECORDING INDICATOR =================

    socket.on('recording:started', async (payload = {}) => {
      const { conversationId } = payload;
      if (!conversationId) return;
      try {
        const conversation = await Conversation.findByPk(conversationId);
        if (!conversation) return;
        if (!conversation.userIds.includes(String(userId))) return;

        const targets = conversation.userIds.filter(
          (id) => String(id) !== String(userId),
        );
        emitToUsers(targets, 'recording:started', {
          conversationId,
          userId,
        });
      } catch {
        // ignore
      }
    });

    socket.on('recording:stopped', async (payload = {}) => {
      const { conversationId } = payload;
      if (!conversationId) return;
      try {
        const conversation = await Conversation.findByPk(conversationId);
        if (!conversation) return;
        if (!conversation.userIds.includes(String(userId))) return;

        const targets = conversation.userIds.filter(
          (id) => String(id) !== String(userId),
        );
        emitToUsers(targets, 'recording:stopped', {
          conversationId,
          userId,
        });
      } catch {
        // ignore
      }
    });

    // ================= CALL START =================

    socket.on("call:start", async (payload = {}, ack) => {
      try {
        const conversation = await Conversation.findByPk(
          payload.conversationId,
        );

        if (!conversation) {
          return ack?.({ ok: false, error: "Conversation not found" });
        }

        if (!conversation.userIds.includes(String(userId))) {
          return ack?.({ ok: false, error: "You are not part of this conversation" });
        }

        const sender = await User.findByPk(userId, {
          attributes: ["id", "name", "avatarUrl"],
        });

        // Record outgoing call.
        await Call.create({
          conversationId: conversation.id,
          callerId: userId,
          type: callTypeFor(payload.type),
          status: 'outgoing',
          roomName: payload.roomName || null,
          startedAt: new Date(),
          participants: conversation.userIds,
        });

        emitToUsers(
          conversation.userIds.filter(id => String(id) !== String(userId)),
          "incoming:call",
          {
            conversationId: payload.conversationId,
            roomName: payload.roomName,
            type: payload.type,
            caller: sender,
          },
        );

        ack?.({ ok: true });
      } catch (e) {
        ack?.({ ok: false, error: e?.message || "Call failed" });
      }
    });

    // ================= ACCEPT =================

    socket.on("call:accept", async (payload = {}) => {
      // The acceptance itself does not create a new history row: call:start
      // already recorded the single outgoing row (callerId = the caller). The
      // controller derives per-user direction from that one row.
      //
      // Mark the open outgoing row as accepted so the receiver's history does
      // not fall through to "missed" when the call ends.
      try {
        if (payload.conversationId) {
          const call = await Call.findOne({
            where: {
              conversationId: payload.conversationId,
              status: 'outgoing',
              endedAt: null,
            },
            order: [['createdAt', 'DESC']],
          });
          if (call) {
            call.status = 'incoming';
            await call.save();
          }
        }
      } catch (e) {
        console.error("Failed to mark call as accepted:", e.message);
      }

      emitToUsers(
        [payload.callerId],
        "call:accepted",
        {
          roomName: payload.roomName,
          accepterId: userId,
        },
      );
    });

    // ================= REJECT =================

    socket.on("call:reject", async (payload = {}) => {
      // Mark the caller's open outgoing row as rejected (single-row model).
      try {
        if (payload.conversationId) {
          const call = await Call.findOne({
            where: {
              conversationId: payload.conversationId,
              endedAt: null,
            },
            order: [['createdAt', 'DESC']],
          });
          if (call) {
            call.status = 'rejected';
            call.endedAt = new Date();
            await call.save();
          }
        }
      } catch (e) {
        console.error("Failed to record rejected call:", e.message);
      }

      emitToUsers(
        [payload.callerId],
        "call:rejected",
        {
          rejecterId: userId,
        },
      );
    });

    // ================= END =================

    socket.on("call:end", async (payload = {}) => {
      const conversation = await Conversation.findByPk(
        payload.conversationId,
      );

      if (!conversation) return;

      // End the most recent open call for this conversation, regardless of
      // which participant initiates the hang-up.
      try {
        const call = await Call.findOne({
          where: {
            conversationId: payload.conversationId,
            endedAt: null,
          },
          order: [['createdAt', 'DESC']],
        });
        if (call) {
          call.endedAt = new Date();
          // If the receiver never accepted, the call was missed, not ended.
          call.status = call.status === 'incoming' ? 'ended' : 'missed';
          const started = call.startedAt ? new Date(call.startedAt) : call.createdAt;
          call.duration = Math.max(0, Math.round((Date.now() - started.getTime()) / 1000));
          await call.save();
        }
      } catch (e) {
        console.error("Failed to record call end:", e.message);
      }

      emitToUsers(
        conversation.userIds,
        "call:ended",
        {
          conversationId: payload.conversationId,
        },
      );
    });

    // ================= PRESENCE / DISCONNECT =================

    // Track the socket and register the disconnect handler before any await,
    // so a fast connect->disconnect cannot be missed while DB updates run.
    const userSockets = onlineUsers.get(userId) || new Set();
    userSockets.add(socket.id);
    onlineUsers.set(userId, userSockets);

    socket.on('disconnect', () => {
      const userSockets = onlineUsers.get(userId);
      if (userSockets) {
        userSockets.delete(socket.id);
        if (userSockets.size === 0) {
          onlineUsers.delete(userId);
        } else {
          onlineUsers.set(userId, userSockets);
          return;
        }
      }

      const lastSeen = new Date();
      User.update({ online: false, lastSeen }, { where: { id: userId } }).then(() => {
        socket.broadcast.emit('presence:update', { userId, online: false, lastSeen });
      }).catch(() => {
        // ignore
      });
    });

    // Mark the user online and broadcast presence only after every event
    // listener above is registered, so messages sent immediately after connect
    // are never dropped by the listener-registration race.
    await User.update({ online: true, lastSeen: new Date() }, { where: { id: userId } });
    socket.broadcast.emit('presence:update', { userId, online: true });
  });

  return io;
}
