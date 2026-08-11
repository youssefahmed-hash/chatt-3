# chatt — Backend (Node.js + Express + MongoDB + Socket.IO)

Real-time chat backend for the `chatt` Flutter app. Provides authentication,
users, conversations, persisted messages, and live message delivery.

## Stack

- **Express** — REST API
- **MongoDB + Mongoose** — data persistence
- **Socket.IO** — real-time messaging, typing, presence
- **JWT (jsonwebtoken)** — stateless auth
- **bcryptjs** — password hashing
- **zod** — request validation

## Project structure

```
server/
├── src/
│   ├── config/        env loading + Mongo connection
│   ├── models/        User, Conversation, Message (Mongoose)
│   ├── middleware/     auth (JWT), validation, error handling
│   ├── controllers/    auth, users, conversations, messages
│   ├── routes/         REST route definitions
│   ├── services/       message.service (shared by REST + sockets)
│   ├── realtime/       Socket.IO server + io helper
│   ├── utils/          token, asyncHandler, ApiError, seed
│   ├── app.js          Express app wiring
│   └── server.js       entry point (http + socket.io)
├── .env.example
└── package.json
```

## Setup

1. **Install MongoDB** (one of):
   - Local: install MongoDB Community Server, it runs at `mongodb://127.0.0.1:27017`.
   - Cloud (recommended, free): create a free cluster on **MongoDB Atlas** and copy its connection string.

2. **Configure env:**
   ```bash
   cd server
   cp .env.example .env
   # then edit .env — set MONGO_URI and a strong JWT_SECRET
   ```
   Generate a secret:
   ```bash
   node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
   ```

3. **Install deps & run:**
   ```bash
   npm install
   npm run seed     # optional: creates demo users (ahmed@chatt.dev / 123456, etc.)
   npm run dev      # auto-restarts on change  (or: npm start)
   ```

   Server: `http://localhost:4000` — health check at `GET /health`.

## REST API

All protected routes require: `Authorization: Bearer <token>`.

| Method | Path                                | Auth | Body / Query                          | Description                          |
|--------|-------------------------------------|------|---------------------------------------|--------------------------------------|
| POST   | `/api/auth/register`                | —    | `{ name, email, password }`           | Create account → `{ token, user }`   |
| POST   | `/api/auth/login`                   | —    | `{ email, password }`                 | Log in → `{ token, user }`           |
| GET    | `/api/auth/me`                      | ✓    | —                                     | Current user                         |
| GET    | `/api/users?search=`                | ✓    | —                                     | List users to start chats with       |
| GET    | `/api/users/:id`                    | ✓    | —                                     | One user                             |
| GET    | `/api/conversations`                | ✓    | —                                     | My conversations (chat list)         |
| POST   | `/api/conversations`                | ✓    | `{ userId }`                          | Open/create a 1-on-1 conversation    |
| GET    | `/api/conversations/:id/messages`   | ✓    | `?before=<ISO>&limit=30`              | Message history (paginated)          |
| POST   | `/api/conversations/:id/messages`   | ✓    | `{ text, type?, callUrl? }`           | Send a message (REST fallback)       |

`type` is one of `text` | `videoCall` | `voiceCall` (matches the Flutter `MessageType` enum).

### Quick test (after `npm run seed`)

```bash
# login
curl -s -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"ahmed@chatt.dev","password":"123456"}'
```

## Real-time (Socket.IO)

Connect with the JWT from login:

```js
const socket = io("http://localhost:4000", { auth: { token } });
```

**Emit (client → server):**

| Event            | Payload                                          | Notes                                  |
|------------------|--------------------------------------------------|----------------------------------------|
| `message:send`   | `{ conversationId, text, type?, callUrl? }`      | 3rd arg is an ack callback `{ ok, message }` |
| `typing`         | `{ conversationId, peerId, typing: boolean }`    | forwarded to the peer                  |
| `message:read`   | `{ conversationId, peerId }`                      | marks peer's messages read             |

**Listen (server → client):**

| Event              | Payload                                  | Meaning                          |
|--------------------|------------------------------------------|----------------------------------|
| `message:new`      | `{ conversationId, message }`            | new message in one of your chats |
| `typing`           | `{ conversationId, userId, typing }`     | peer is typing                   |
| `message:read`     | `{ conversationId, readerId }`           | peer read your messages          |
| `presence:update`  | `{ userId, online, lastSeen? }`          | a user came online / went offline|

## Connecting the Flutter app

**The Flutter app is already wired to this backend.** The client layer lives in:

| File | Purpose |
|------|---------|
| `lib/config/api_config.dart`        | Backend base URL (auto-uses `10.0.2.2` on Android emulator) |
| `lib/services/session.dart`         | Persists JWT + current user via `shared_preferences` |
| `lib/services/api_service.dart`     | REST calls (auth, users, conversations, messages) |
| `lib/services/auth_service.dart`    | Register/login → saves session |
| `lib/services/socket_service.dart`  | Socket.IO connection + streams (`onNewMessage`, `onTyping`, `onPresence`) |
| `lib/screens/login_screen.dart`     | Login / register UI |

`main.dart` restores the session on launch and opens the login screen or the
chat list accordingly. `ChatListScreen` loads conversations from
`GET /api/conversations` and lets you start new chats; `ChatScreen` loads
history and sends messages over the socket (`message:send`), updating live from
the `message:new` stream.

### Run the app against the backend

```bash
# 1. start the backend (see Setup above)  →  http://localhost:4000
# 2. from the project root:
flutter pub get
flutter run
```

> **Where to point the app:** `lib/config/api_config.dart`
> - Android emulator → `10.0.2.2:4000` (handled automatically)
> - iOS simulator / desktop / web → `localhost:4000`
> - **Real phone** → set `overrideHost` to your PC's LAN IP (e.g. `192.168.1.5`)
>   and keep the phone on the same Wi-Fi.

To test two-way chat: register two accounts (or run `npm run seed` and log in as
`ahmed@chatt.dev` / `123456` on one device and `sara@chatt.dev` on another),
start a chat, and watch messages arrive in real time.

## Production notes

- Set `NODE_ENV=production` and a restrictive `CORS_ORIGIN` (not `*`).
- Use a managed MongoDB (Atlas) with a strong password and IP allowlist.
- Put the server behind HTTPS (reverse proxy) — JWTs travel in headers.
- Consider adding rate limiting (`express-rate-limit`) on `/api/auth/*`.
