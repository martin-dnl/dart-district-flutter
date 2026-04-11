-- ============================================================
-- Dart District – Full PostgreSQL Schema (consolidated init)
-- Replaces migrations 001–007; apply once on a fresh database.
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── ENUM types ──────────────────────────────────────────────
CREATE TYPE auth_provider_type      AS ENUM ('local', 'google', 'apple', 'guest');
CREATE TYPE club_member_role        AS ENUM ('president', 'captain', 'player');
CREATE TYPE territory_status        AS ENUM ('available', 'locked', 'alert', 'conquered', 'conflict');
CREATE TYPE match_status            AS ENUM ('pending', 'in_progress', 'paused', 'completed', 'cancelled', 'awaiting_validation');
CREATE TYPE match_mode              AS ENUM ('301', '501', '701', 'cricket', 'chasseur');
CREATE TYPE finish_type             AS ENUM ('double_out', 'single_out', 'master_out');
CREATE TYPE duel_status             AS ENUM ('pending', 'accepted', 'declined', 'expired', 'completed');
CREATE TYPE sync_action             AS ENUM ('create', 'update', 'delete');
CREATE TYPE notification_type       AS ENUM ('match_invite', 'duel_request', 'territory_update', 'club_invite', 'tournament', 'system');
CREATE TYPE friend_request_status   AS ENUM ('pending', 'accepted', 'rejected', 'canceled');
CREATE TYPE match_invitation_status AS ENUM ('pending', 'accepted', 'refused');

-- ── 1. USERS ────────────────────────────────────────────────
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(60) NOT NULL UNIQUE,
    email           VARCHAR(255) UNIQUE,
    password_hash   VARCHAR(255),
    avatar_url      TEXT,
    elo             INTEGER NOT NULL DEFAULT 1000,
    is_guest        BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    preferred_hand  VARCHAR(10) DEFAULT 'right',
    level           VARCHAR(20) DEFAULT 'intermediate',
    city            VARCHAR(100),
    region          VARCHAR(100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_users_email    ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_elo      ON users(elo DESC);

-- ── 2. AUTH PROVIDERS ───────────────────────────────────────
CREATE TABLE auth_providers (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider        auth_provider_type NOT NULL,
    provider_uid    VARCHAR(255) NOT NULL,
    access_token    TEXT,
    refresh_token   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(provider, provider_uid)
);
CREATE INDEX idx_auth_providers_user ON auth_providers(user_id);

-- ── 3. PLAYER STATS ─────────────────────────────────────────
CREATE TABLE player_stats (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    matches_played      INTEGER NOT NULL DEFAULT 0,
    matches_won         INTEGER NOT NULL DEFAULT 0,
    avg_score           NUMERIC(6,2) NOT NULL DEFAULT 0,
    best_avg            NUMERIC(6,2) NOT NULL DEFAULT 0,
    checkout_rate       NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_180s          INTEGER NOT NULL DEFAULT 0,
    high_finish         INTEGER NOT NULL DEFAULT 0,
    best_leg_darts      INTEGER NOT NULL DEFAULT 0,
    consecutive_days_played INTEGER NOT NULL DEFAULT 0,
    last_played_date    DATE,
    precision_t20       NUMERIC(5,2) NOT NULL DEFAULT 0,
    precision_t19       NUMERIC(5,2) NOT NULL DEFAULT 0,
    precision_double    NUMERIC(5,2) NOT NULL DEFAULT 0,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 4. ELO HISTORY ──────────────────────────────────────────
CREATE TABLE elo_history (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id    UUID,
    elo_before  INTEGER NOT NULL,
    elo_after   INTEGER NOT NULL,
    delta       INTEGER NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_elo_history_user ON elo_history(user_id, created_at DESC);

-- ── 5. CLUBS ────────────────────────────────────────────────
CREATE TABLE clubs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL UNIQUE,
    description     TEXT,
    avatar_url      TEXT,
    address         TEXT,
    city            VARCHAR(100),
    region          VARCHAR(100),
    latitude        NUMERIC(10,7),
    longitude       NUMERIC(10,7),
    conquest_points INTEGER NOT NULL DEFAULT 0,
    rank            INTEGER,
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_clubs_city   ON clubs(city);
CREATE INDEX idx_clubs_points ON clubs(conquest_points DESC);

-- ── 6. CLUB MEMBERS ─────────────────────────────────────────
CREATE TABLE club_members (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id     UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role        club_member_role NOT NULL DEFAULT 'player',
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(club_id, user_id)
);
CREATE INDEX idx_club_members_club ON club_members(club_id);
CREATE INDEX idx_club_members_user ON club_members(user_id);

-- ── 7. TERRITORIES ──────────────────────────────────────────
CREATE TABLE territories (
    code_iris       VARCHAR(9) PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    insee_com       VARCHAR(5),
    nom_com         VARCHAR(150),
    nom_iris        VARCHAR(100),
    iris_type       VARCHAR(30),
    dep_code        VARCHAR(3),
    dep_name        VARCHAR(2),
    region_code     VARCHAR(3),
    region_name     VARCHAR(120),
    population      INTEGER,
    centroid_lat    NUMERIC(10,7) NOT NULL,
    centroid_lng    NUMERIC(10,7) NOT NULL,
    area_m2         NUMERIC(12,2),
    status          territory_status NOT NULL DEFAULT 'available',
    owner_club_id   UUID REFERENCES clubs(id) ON DELETE SET NULL,
    conquered_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_territories_owner  ON territories(owner_club_id);
CREATE INDEX idx_territories_status ON territories(status);
CREATE INDEX idx_territories_dep    ON territories(dep_code);

-- ── 8. TERRITORY TILESETS (PMTiles metadata) ────────────────
CREATE TABLE territory_tilesets (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key             VARCHAR(100) NOT NULL UNIQUE,
    format          VARCHAR(50) NOT NULL,
    source_url      VARCHAR(255) NOT NULL,
    attribution     VARCHAR(120) NOT NULL,
    minzoom         INTEGER NOT NULL DEFAULT 0,
    maxzoom         INTEGER NOT NULL DEFAULT 14,
    bounds_west     NUMERIC(10,6),
    bounds_south    NUMERIC(10,6),
    bounds_east     NUMERIC(10,6),
    bounds_north    NUMERIC(10,6),
    center_lng      NUMERIC(10,6),
    center_lat      NUMERIC(10,6),
    center_zoom     INTEGER,
    layer_name      VARCHAR(100),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ── 9. TERRITORY HISTORY ────────────────────────────────────
CREATE TABLE territory_history (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    territory_id    VARCHAR(9) NOT NULL REFERENCES territories(code_iris) ON DELETE CASCADE,
    from_club_id    UUID REFERENCES clubs(id) ON DELETE SET NULL,
    to_club_id      UUID REFERENCES clubs(id) ON DELETE SET NULL,
    match_id        UUID,
    event           VARCHAR(50) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_territory_history_territory ON territory_history(territory_id, created_at DESC);

-- ── 10. MATCHES ─────────────────────────────────────────────
CREATE TABLE matches (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mode                    match_mode NOT NULL,
    finish                  finish_type NOT NULL DEFAULT 'double_out',
    status                  match_status NOT NULL DEFAULT 'pending',
    total_sets              INTEGER NOT NULL DEFAULT 1,
    legs_per_set            INTEGER NOT NULL DEFAULT 3,
    territory_id            VARCHAR(9) REFERENCES territories(code_iris) ON DELETE SET NULL,
    is_territorial          BOOLEAN NOT NULL DEFAULT FALSE,
    tournament_id           UUID,
    is_offline              BOOLEAN NOT NULL DEFAULT FALSE,
    validated_by_home       BOOLEAN NOT NULL DEFAULT FALSE,
    validated_by_away       BOOLEAN NOT NULL DEFAULT FALSE,
    inviter_id              UUID REFERENCES users(id) ON DELETE SET NULL,
    invitee_id              UUID REFERENCES users(id) ON DELETE SET NULL,
    invitation_status       match_invitation_status,
    invitation_created_at   TIMESTAMPTZ,
    started_at              TIMESTAMPTZ,
    ended_at                TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_matches_status              ON matches(status);
CREATE INDEX idx_matches_territory           ON matches(territory_id);
CREATE INDEX idx_matches_inviter_id          ON matches(inviter_id);
CREATE INDEX idx_matches_invitee_id          ON matches(invitee_id);
CREATE INDEX idx_matches_invitation_status   ON matches(invitation_status);
CREATE INDEX idx_matches_invitation_created  ON matches(invitation_created_at DESC);

-- ── 11. MATCH PLAYERS ───────────────────────────────────────
CREATE TABLE match_players (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id    UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    club_id     UUID REFERENCES clubs(id) ON DELETE SET NULL,
    side        VARCHAR(10) NOT NULL DEFAULT 'home',
    final_score INTEGER,
    avg_score   NUMERIC(6,2),
    is_winner   BOOLEAN,
    UNIQUE(match_id, user_id)
);
CREATE INDEX idx_match_players_match ON match_players(match_id);
CREATE INDEX idx_match_players_user  ON match_players(user_id);

-- ── 12. SETS ────────────────────────────────────────────────
CREATE TABLE sets (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id    UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    set_number  INTEGER NOT NULL,
    winner_id   UUID REFERENCES users(id),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(match_id, set_number)
);

-- ── 13. LEGS ────────────────────────────────────────────────
CREATE TABLE legs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    set_id          UUID NOT NULL REFERENCES sets(id) ON DELETE CASCADE,
    leg_number      INTEGER NOT NULL,
    winner_id       UUID REFERENCES users(id),
    starting_score  INTEGER NOT NULL DEFAULT 501,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(set_id, leg_number)
);

-- ── 14. THROWS ──────────────────────────────────────────────
CREATE TABLE throws (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    leg_id      UUID NOT NULL REFERENCES legs(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    round_num   INTEGER NOT NULL,
    dart_num    INTEGER NOT NULL,
    segment     VARCHAR(10) NOT NULL,
    score       INTEGER NOT NULL,
    remaining   INTEGER NOT NULL,
    is_checkout BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_throws_leg  ON throws(leg_id, round_num, dart_num);
CREATE INDEX idx_throws_user ON throws(user_id);

-- ── 15. TOURNAMENTS ─────────────────────────────────────────
CREATE TABLE tournaments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(150) NOT NULL,
    description     TEXT,
    territory_id    VARCHAR(9) REFERENCES territories(code_iris) ON DELETE SET NULL,
    is_territorial  BOOLEAN NOT NULL DEFAULT FALSE,
    mode            match_mode NOT NULL DEFAULT '501',
    finish          finish_type NOT NULL DEFAULT 'double_out',
    venue_name      VARCHAR(200),
    venue_address   TEXT,
    city            VARCHAR(100),
    entry_fee       NUMERIC(8,2) DEFAULT 0,
    max_clubs       INTEGER NOT NULL DEFAULT 16,
    enrolled_clubs  INTEGER NOT NULL DEFAULT 0,
    status          VARCHAR(30) NOT NULL DEFAULT 'open',
    scheduled_at    TIMESTAMPTZ NOT NULL,
    ended_at        TIMESTAMPTZ,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_tournaments_city   ON tournaments(city);
CREATE INDEX idx_tournaments_status ON tournaments(status);

-- Add FK from matches to tournaments
ALTER TABLE matches ADD CONSTRAINT fk_matches_tournament
    FOREIGN KEY (tournament_id) REFERENCES tournaments(id) ON DELETE SET NULL;

-- ── 16. TOURNAMENT REGISTRATIONS ────────────────────────────
CREATE TABLE tournament_registrations (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tournament_id   UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
    club_id         UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    registered_by   UUID NOT NULL REFERENCES users(id),
    registered_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tournament_id, club_id)
);

-- ── 17. DUELS ───────────────────────────────────────────────
CREATE TABLE duels (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    territory_id    VARCHAR(9) NOT NULL REFERENCES territories(code_iris) ON DELETE CASCADE,
    challenger_id   UUID NOT NULL REFERENCES users(id),
    defender_id     UUID REFERENCES users(id),
    challenger_club UUID NOT NULL REFERENCES clubs(id),
    defender_club   UUID REFERENCES clubs(id),
    match_id        UUID REFERENCES matches(id),
    qr_code_id      UUID,
    status          duel_status NOT NULL DEFAULT 'pending',
    expires_at      TIMESTAMPTZ NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_duels_territory ON duels(territory_id);
CREATE INDEX idx_duels_status    ON duels(status);

-- ── 18. QR CODES ────────────────────────────────────────────
CREATE TABLE qr_codes (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    territory_id    VARCHAR(9) NOT NULL REFERENCES territories(code_iris) ON DELETE CASCADE,
    venue_name      VARCHAR(200),
    code            VARCHAR(100) NOT NULL UNIQUE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
ALTER TABLE duels ADD CONSTRAINT fk_duels_qr
    FOREIGN KEY (qr_code_id) REFERENCES qr_codes(id) ON DELETE SET NULL;

-- ── 19. CHAT MESSAGES ───────────────────────────────────────
CREATE TABLE chat_messages (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id    UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_chat_match ON chat_messages(match_id, created_at);

-- ── 20. NOTIFICATIONS ───────────────────────────────────────
CREATE TABLE notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        notification_type NOT NULL,
    title       VARCHAR(200) NOT NULL,
    body        TEXT,
    data        JSONB,
    is_read     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);

-- ── 20b. SOCIAL POSTS ──────────────────────────────────────
CREATE TABLE social_posts (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id     UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    mode         VARCHAR(16) NOT NULL,
    sets_score   VARCHAR(32) NOT NULL,
    result_label VARCHAR(32) NOT NULL,
    description  TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_social_posts_author_created ON social_posts(author_id, created_at DESC);
CREATE INDEX idx_social_posts_created_at ON social_posts(created_at DESC);
CREATE INDEX idx_social_posts_match_id ON social_posts(match_id);

-- ── 21. OFFLINE SYNC QUEUE ──────────────────────────────────
CREATE TABLE offline_queue (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entity_type     VARCHAR(50) NOT NULL,
    entity_id       UUID,
    action          sync_action NOT NULL,
    payload         JSONB NOT NULL,
    client_ts       TIMESTAMPTZ NOT NULL,
    processed       BOOLEAN NOT NULL DEFAULT FALSE,
    processed_at    TIMESTAMPTZ,
    conflict        BOOLEAN NOT NULL DEFAULT FALSE,
    conflict_detail TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_offline_queue_user ON offline_queue(user_id, processed);

-- ── 22. REFRESH TOKENS ──────────────────────────────────────
CREATE TABLE refresh_tokens (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       VARCHAR(500) NOT NULL UNIQUE,
    expires_at  TIMESTAMPTZ NOT NULL,
    revoked     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);

-- ── 23. FRIENDSHIPS ─────────────────────────────────────────
CREATE TABLE friendships (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_friendships_user_friend UNIQUE (user_id, friend_id)
);
CREATE INDEX idx_friendships_user ON friendships(user_id);

-- ── 24. DIRECT MESSAGES ─────────────────────────────────────
CREATE TABLE direct_messages (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content       TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at       TIMESTAMPTZ
);
CREATE INDEX idx_direct_messages_to_read    ON direct_messages(to_user_id, read_at);
CREATE INDEX idx_direct_messages_pair_created ON direct_messages(from_user_id, to_user_id, created_at);

-- ── 25. FRIEND REQUESTS ─────────────────────────────────────
CREATE TABLE friend_requests (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    receiver_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status        friend_request_status NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at  TIMESTAMPTZ
);
CREATE INDEX idx_friend_requests_sender_receiver        ON friend_requests(sender_id, receiver_id);
CREATE INDEX idx_friend_requests_receiver_status_created ON friend_requests(receiver_id, status, created_at);

-- ── 26. IRIS IMPORT STAGING ─────────────────────────────────
-- Utility table used by the CSV bulk-import workflow.
CREATE TABLE IF NOT EXISTS staging_iris_import (
    code_iris     VARCHAR(9) NOT NULL,
    name          VARCHAR(255) NOT NULL,
    insee_com     VARCHAR(5),
    nom_com       VARCHAR(150),
    nom_iris      VARCHAR(100),
    iris_type     VARCHAR(30),
    dep_code      VARCHAR(3),
    dep_name      VARCHAR(2),
    region_code   VARCHAR(3),
    region_name   VARCHAR(120),
    population    INTEGER,
    centroid_lat  NUMERIC(10,7) NOT NULL,
    centroid_lng  NUMERIC(10,7) NOT NULL,
    area_m2       NUMERIC(12,2)
);
CREATE INDEX IF NOT EXISTS idx_staging_iris_import_code_iris ON staging_iris_import(code_iris);

-- ── 27. APP VERSION POLICIES ────────────────────────────────
CREATE TABLE app_version_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    platform VARCHAR(16) NOT NULL CHECK (platform IN ('android', 'ios')),
    min_version VARCHAR(32) NOT NULL,
    recommended_version VARCHAR(32) NOT NULL,
    store_url_android TEXT,
    store_url_ios TEXT,
    message_force_update TEXT NOT NULL,
    message_soft_update TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_app_version_policies_platform_active
    ON app_version_policies(platform, is_active);

-- ── TRIGGERS: auto-update updated_at ────────────────────────
CREATE OR REPLACE FUNCTION trigger_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER trg_clubs_updated_at
    BEFORE UPDATE ON clubs FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER trg_player_stats_updated_at
    BEFORE UPDATE ON player_stats FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER trg_territories_updated_at
    BEFORE UPDATE ON territories FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER trg_territory_tilesets_updated_at
    BEFORE UPDATE ON territory_tilesets FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

CREATE TRIGGER trg_app_version_policies_updated_at
    BEFORE UPDATE ON app_version_policies FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();

-- ── TRIGGER: auto-create player_stats row on user insert ────
CREATE OR REPLACE FUNCTION trigger_create_player_stats()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO player_stats (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_create_stats
    AFTER INSERT ON users FOR EACH ROW EXECUTE FUNCTION trigger_create_player_stats();
