import { Server } from 'socket.io';
import { env } from '../config/env.js';
import { User } from '../models/User.js';
import { Message } from '../models/Message.js';
import { verifyToken } from '../utils/token.js';
import { createMessage } from '../services/message.service.js';
import { setIO, userRoom, emitToUsers } from './io.js';
import { Conversation } from '../models/Conversation.js';

export function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: env.corsOrigin,
      methods: ['GET', 'POST'],
    },
  });

  setIO(io);

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

    await User.update({ online: true, lastSeen: new Date() }, { where: { id: userId } });
    socket.broadcast.emit('presence:update', { userId, online: true });


    socket.on('message:send', async (payload = {}, ack) => {
      try {

        const message = await createMessage({
          conversationId: payload.conversationId,
          senderId: userId,
          text: payload.text,
          type: payload.type || 'text',
          callUrl: payload.callUrl || null,
        });

        const conversation = await Conversation.findByPk(
          payload.conversationId,
        );

        const sender = await User.findByPk(userId, {
          attributes: ['id', 'name', 'avatarUrl'],
        });

        const messageData = message.toJSON();

        messageData.sender = sender;

        if (conversation) {

            emitToUsers(
              conversation.userIds,
              'message:new',
              {
                conversationId: conversation.id,
                message: messageData,
              },
            );
        }

        if (typeof ack === 'function') {
          ack({
            ok: true,
            message: message.toJSON(),
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

    socket.on('typing', (payload = {}) => {
      if (!payload.peerId) return;
      emitToUsers([payload.peerId], 'typing', {
        conversationId: payload.conversationId,
        userId,
        typing: !!payload.typing,
      });
    });

    socket.on('message:read', async (payload = {}) => {
      if (!payload.conversationId) return;
      await Message.update(
        { readBy: null },
        { where: { conversationId: payload.conversationId } }
      );
      if (payload.peerId) {
        emitToUsers([payload.peerId], 'message:read', {
          conversationId: payload.conversationId,
          readerId: userId,
        });
      }
    });
    // ================= CALL START =================

    socket.on("call:start", async (payload = {}, ack) => {
      try {

        const conversation = await Conversation.findByPk(
          payload.conversationId,
        );

        if (!conversation) {
          return ack?.({
            ok: false,
            error: "Conversation not found",
          });
        }

        const sender = await User.findByPk(userId, {
          attributes: ["id", "name", "avatarUrl"],
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
            ack?.({
                ok: false,
                error: e?.message || "Call failed",
            });
        }
    });
    // ================= ACCEPT =================

    socket.on("call:accept", (payload = {}) => {
    console.log("CALL ACCEPT");
    console.log(payload);
console.log("sending accepted to", payload.callerId);
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

    socket.on("call:reject", (payload = {}) => {

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

      emitToUsers(
        conversation.userIds,
        "call:ended",
        {
          conversationId: payload.conversationId,
        },
      );

    });
    socket.on('disconnect', async () => {
      const room = io.sockets.adapter.rooms.get(userRoom(userId));
      const stillConnected = room && room.size > 0;
      if (!stillConnected) {
        const lastSeen = new Date();
        await User.update({ online: false, lastSeen }, { where: { id: userId } });
        socket.broadcast.emit('presence:update', { userId, online: false, lastSeen });
      }
    });
  });

  return io;
}
