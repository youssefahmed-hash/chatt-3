// Holds the Socket.IO server instance so non-socket code (REST controllers,
// services) can emit real-time events. Each user joins a personal room named
// after their userId, so we can push events to a specific user across all of
// their connected devices.

let ioRef = null;

export function setIO(io) {
  ioRef = io;
}

export function getIO() {
  return ioRef;
}

export function userRoom(userId) {
  return `user:${userId}`;
}

// Emit an event to every listed user (across all their sockets).
export function emitToUsers(userIds, event, payload) {
  if (!ioRef) return;
  for (const id of userIds) {
    ioRef.to(userRoom(id)).emit(event, payload);
  }
}

// Emit an event where each recipient receives a payload serialized from their
// own point of view (e.g. message:new) instead of one sender-view payload for
// everyone. This keeps the socket payload identical to what the same user's
// REST reload would return for the same message.
export async function emitToUsersPerViewer(userIds, event, payloadFor) {
  if (!ioRef) return;
  for (const id of userIds) {
    const payload = await payloadFor(id);
    ioRef.to(userRoom(id)).emit(event, payload);
  }
}
