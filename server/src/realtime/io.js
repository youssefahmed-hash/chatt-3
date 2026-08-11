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
