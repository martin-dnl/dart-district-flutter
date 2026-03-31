# Dart District — Backend API Documentation

## Architecture

```
backend/
├── src/
│   ├── common/                    # Shared utilities
│   │   ├── dto/api-response.dto.ts
│   │   ├── filters/global-exception.filter.ts
│   │   └── interceptors/
│   │       ├── logging.interceptor.ts
│   │       └── transform.interceptor.ts
│   ├── modules/
│   │   ├── auth/                  # JWT + Google + Apple + Guest
│   │   ├── users/                 # User profiles & leaderboard
│   │   ├── clubs/                 # Club CRUD & membership
│   │   ├── territories/           # Territory map + duels
│   │   ├── matches/               # Match creation & scoring
│   │   ├── stats/                 # Player stats & ELO
│   │   ├── tournaments/           # Tournament management
│   │   ├── realtime/              # WebSocket gateways
│   │   ├── offline_sync/          # Offline queue & conflict resolution
│   │   ├── notifications/         # Push notifications
│   │   └── qr/                    # QR code generation & scanning
│   ├── app.module.ts
│   └── main.ts
├── sql/
│   ├── 001_schema.sql             # 21 tables, 9 ENUMs, triggers
│   └── 002_seed.sql               # Development seed data
├── .env / .env.example
├── package.json
└── tsconfig.json
```

---

## REST API Endpoints

All endpoints prefixed with `/api/v1/`. Authenticated endpoints require `Authorization: Bearer <token>`.

### Auth (`/api/v1/auth`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | ✗ | Register with email/password |
| POST | `/auth/login` | ✗ | Login with email/password |
| POST | `/auth/google` | ✗ | Login with Google id_token |
| POST | `/auth/apple` | ✗ | Login with Apple id_token |
| POST | `/auth/guest` | ✗ | Anonymous guest login |
| POST | `/auth/refresh` | ✗ | Refresh access token |
| POST | `/auth/logout` | ✓ | Revoke all refresh tokens |

**Response format:**
```json
{ "access_token": "...", "refresh_token": "...", "user_id": "uuid" }
```

### Users (`/api/v1/users`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/users/me` | ✓ | Get current user profile |
| PATCH | `/users/me` | ✓ | Update profile |
| DELETE | `/users/me` | ✓ | Soft-delete account |
| GET | `/users/leaderboard?limit=50` | ✓ | ELO leaderboard |
| GET | `/users/search?q=name` | ✓ | Search users by name |
| GET | `/users/:id` | ✓ | Get user by ID |

### Clubs (`/api/v1/clubs`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/clubs` | ✓ | Create club (becomes president) |
| GET | `/clubs` | ✓ | List all clubs |
| GET | `/clubs/ranking` | ✓ | Club conquest ranking |
| GET | `/clubs/:id` | ✓ | Club details + members |
| PATCH | `/clubs/:id` | ✓ | Update club (president only) |
| POST | `/clubs/:id/members` | ✓ | Add member |
| PATCH | `/clubs/:id/members/:userId/role` | ✓ | Update member role (president) |
| DELETE | `/clubs/:id/members/:userId` | ✓ | Remove member |

### Territories (`/api/v1/territories`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/territories/tileset` | ✓ | Active PMTiles metadata (url, zoom, bounds) |
| GET | `/territories/map/statuses` | ✓ | IRIS status feed (`code_iris` + status + owner) |
| GET | `/territories` | ✓ | List all IRIS territories + owners |
| GET | `/territories/:codeIris` | ✓ | Territory details by IRIS code |
| GET | `/territories/:codeIris/panel` | ✓ | Panel data for map tap (territory + duel + events) |
| GET | `/territories/:codeIris/history` | ✓ | Ownership/status history |
| PATCH | `/territories/:codeIris/status` | ✓ | Update business status (available/locked/alert/...) |
| PATCH | `/territories/:codeIris/owner` | ✓ | Manual owner transfer |
| POST | `/territories/duels` | ✓ | Create duel challenge |
| GET | `/territories/duels/pending` | ✓ | Pending duels for club |
| PATCH | `/territories/duels/:id/accept` | ✓ | Accept duel |
| PATCH | `/territories/duels/:id/complete` | ✓ | Complete duel + transfer |

### Matches (`/api/v1/matches`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/matches` | ✓ | Create match (501/301/cricket) |
| GET | `/matches/me` | ✓ | My match history |
| GET | `/matches/:id` | ✓ | Full match details |
| POST | `/matches/:id/legs/:legId/throws` | ✓ | Submit throw |
| PATCH | `/matches/:id/validate` | ✓ | Validate match result |

### Stats (`/api/v1/stats`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/stats/me` | ✓ | My stats (avg, checkout, 180s, precision) |
| GET | `/stats/me/elo-history` | ✓ | My ELO history |
| GET | `/stats/:userId` | ✓ | User stats |
| GET | `/stats/:userId/elo-history` | ✓ | User ELO history |

### Tournaments (`/api/v1/tournaments`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/tournaments` | ✓ | Create tournament |
| GET | `/tournaments` | ✓ | List upcoming tournaments |
| GET | `/tournaments/:id` | ✓ | Tournament details + registrations |
| POST | `/tournaments/:id/register` | ✓ | Register club |
| DELETE | `/tournaments/:id/register/:clubId` | ✓ | Unregister club |

### Notifications (`/api/v1/notifications`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/notifications?limit=50` | ✓ | List notifications |
| GET | `/notifications/unread-count` | ✓ | Unread count |
| PATCH | `/notifications/:id/read` | ✓ | Mark as read |
| PATCH | `/notifications/read-all` | ✓ | Mark all as read |

### QR Codes (`/api/v1/qr-codes`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/qr-codes` | ✓ | Generate QR for territory |
| GET | `/qr-codes/scan/:code` | ✓ | Scan QR → territory info |
| GET | `/qr-codes/territory/:id` | ✓ | QR codes for territory |
| PATCH | `/qr-codes/:id/deactivate` | ✓ | Deactivate QR |

### Offline Sync (`/api/v1/sync`)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/sync/push` | ✓ | Push offline changes |
| GET | `/sync/pull?since=ISO` | ✓ | Pull pending changes |
| PATCH | `/sync/:id/resolve` | ✓ | Resolve conflict |

---

## WebSocket Events

### `/ws/match` — Match real-time

| Event | Direction | Payload |
|-------|-----------|---------|
| `join_match` | Client → Server | `{ match_id }` |
| `leave_match` | Client → Server | `{ match_id }` |
| `throw_event` | Client → Server | `{ match_id, leg_id, player_id, segment, score, remaining }` |
| `score_sync` | Client → Server | `{ match_id, scores }` |
| `throw_update` | Server → Client | Throw data broadcast |
| `match_update` | Server → Client | Match state update |
| `leg_complete` | Server → Client | Leg completion |
| `match_complete` | Server → Client | Match result |

### `/ws/chat` — Match chat

| Event | Direction | Payload |
|-------|-----------|---------|
| `join_chat` | Client → Server | `{ match_id }` |
| `chat_message` | Bidirectional | `{ match_id, user_id, content }` |

### `/ws/territory` — Territory updates

| Event | Direction | Payload |
|-------|-----------|---------|
| `subscribe_territory` | Client → Server | `{ code_iris }` (compat: `{ territory_id }`) |
| `subscribe_map` | Client → Server | — |
| `territory_status_updated` | Server → Client | Territory status delta |
| `territory_owner_updated` | Server → Client | Territory owner delta |
| `territory_update` | Server → Client | Territory state (legacy compat) |
| `duel_request` | Server → Client | Duel challenge |
| `duel_accepted` | Server → Client | Duel accepted |
| `duel_completed` | Server → Client | Duel result + ownership change |
| `map_update` | Server → Client | Global map state |

### `/ws/system` — System notifications

| Event | Direction | Payload |
|-------|-----------|---------|
| `subscribe_user` | Client → Server | `{ user_id }` |
| `subscribe_club` | Client → Server | `{ club_id }` |
| `qr_scan` | Client → Server | `{ qr_code, user_id }` |
| `notification` | Server → Client | Notification payload |
| `sync_complete` | Server → Client | Sync confirmation |

---

## Database Schema (ER Diagram)

```
┌──────────┐     ┌──────────────┐     ┌─────────────┐
│  users   │────▶│ auth_providers│     │player_stats │
│          │────▶│              │     │ (1:1 user)  │
│          │────▶│              │     └─────────────┘
│          │     └──────────────┘
│          │────▶ refresh_tokens
│          │────▶ elo_history
│          │────▶ notifications
│          │────▶ offline_queue
│          │     ┌──────────────┐     ┌──────────┐
│          │────▶│ club_members │────▶│  clubs   │
└──────────┘     └──────────────┘     │          │
                                      │          │────▶ territories
                                      └──────────┘     │
                                                        ├──▶ territory_history
                                                        ├──▶ duels
                                                        ├──▶ qr_codes
                                                        └──▶ tournaments
                                                              └──▶ tournament_registrations

┌──────────┐     ┌──────────────┐     ┌──────┐     ┌──────┐     ┌────────┐
│ matches  │────▶│match_players │     │ sets │────▶│ legs │────▶│ throws │
│          │────▶│              │     │      │     │      │     │        │
│          │────▶│              │     └──────┘     └──────┘     └────────┘
│          │────▶ chat_messages
└──────────┘
```

---

## ELO Algorithm

Standard ELO with K-factor = 32:

$$E_A = \frac{1}{1 + 10^{(R_B - R_A) / 400}}$$
$$\Delta R = K \times (S - E_A)$$

Where S = 1 (win) or 0 (loss). Applied after each validated match.

---

## Getting Started

```bash
# 1. Install dependencies
cd backend && npm install

# 2. Configure environment
cp .env.example .env
# Edit .env with your PostgreSQL credentials & JWT secret

# 3. Create database & run schema
psql -U postgres -c "CREATE DATABASE dart_district"
psql -U postgres -d dart_district -f sql/001_schema.sql
psql -U postgres -d dart_district -f sql/002_seed.sql

# 4. Start development server
npm run start:dev

# 5. Access Swagger docs
open http://localhost:3000/api/docs
```

---

## Deployment Recommendations

1. **Environment**: Use `NODE_ENV=production` to disable TypeORM `synchronize` and SQL logging
2. **JWT Secret**: Generate a strong random secret (≥256-bit)
3. **Rate Limiting**: Adjust `THROTTLE_TTL` / `THROTTLE_LIMIT` per route sensitivity
4. **Database**: Use connection pooling (pgBouncer), enable SSL
5. **WebSocket**: Consider Redis adapter (`@socket.io/redis-adapter`) for horizontal scaling
6. **Monitoring**: Integrate Sentry or similar APM for error tracking
7. **CI/CD**: Run `npm run build` + `npm run start:prod` in production
8. **Backups**: Automated PostgreSQL `pg_dump` on schedule
