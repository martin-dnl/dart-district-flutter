# 🏗️ CODEX PROMPT 08 – Système de Tournois Complet (Backend + Flutter)

## Contexte
Tu travailles sur **Dart District** — Flutter frontend + NestJS backend.

### État actuel du système de tournois :
- **Backend** : `backend/src/modules/tournaments/` — orienté clubs (inscription = club_id), pas de pools, pas de bracket.
- **Entities** : `Tournament` (max_clubs, enrolled_clubs) + `TournamentRegistration` (club_id, registered_by).
- **Flutter** : Aucune page tournois dédiée. Juste une section dans `home_screen.dart` et `club_screen.dart`.

### Besoin :
Refondre complètement pour supporter des **tournois individuels** (inscription = joueur, pas club), avec **phases de poules** puis **élimination directe (bracket)**.

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## PARTIE A : Backend — Refonte DB + API

### Tâche A.1 : Migration SQL

Fichier : `backend/sql/012_tournaments_refactor.sql`

```sql
-- ====================================================================
-- Migration 012 : Refonte complète du système de tournois
-- ====================================================================

-- 1. Supprimer les anciennes tables (si aucune donnée de prod)
DROP TABLE IF EXISTS tournament_registrations CASCADE;

-- 2. Modifier la table tournaments
ALTER TABLE tournaments
  DROP COLUMN IF EXISTS max_clubs,
  DROP COLUMN IF EXISTS enrolled_clubs,
  ADD COLUMN IF NOT EXISTS max_players INT NOT NULL DEFAULT 16,
  ADD COLUMN IF NOT EXISTS enrolled_players INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS format VARCHAR(20) NOT NULL DEFAULT 'single_elimination',
  ADD COLUMN IF NOT EXISTS pool_count INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS players_per_pool INT DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS qualified_per_pool INT DEFAULT 2,
  ADD COLUMN IF NOT EXISTS legs_per_set_pool INT NOT NULL DEFAULT 3,
  ADD COLUMN IF NOT EXISTS sets_to_win_pool INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS legs_per_set_bracket INT NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS sets_to_win_bracket INT NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS current_phase VARCHAR(20) NOT NULL DEFAULT 'registration';
  -- current_phase: 'registration', 'pools', 'bracket', 'finished'

-- 3. Nouvelle table : inscriptions individuelles
CREATE TABLE IF NOT EXISTS tournament_players (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  seed INT,
  pool_id UUID,
  is_qualified BOOLEAN NOT NULL DEFAULT FALSE,
  is_disqualified BOOLEAN NOT NULL DEFAULT FALSE,
  disqualification_reason TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(tournament_id, user_id)
);

-- 4. Nouvelle table : poules
CREATE TABLE IF NOT EXISTS tournament_pools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  pool_name VARCHAR(10) NOT NULL, -- 'A', 'B', 'C', ...
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Lier les joueurs aux poules
ALTER TABLE tournament_players
  ADD CONSTRAINT fk_tp_pool FOREIGN KEY (pool_id) REFERENCES tournament_pools(id) ON DELETE SET NULL;

-- 5. Nouvelle table : matchs de poule (classement)
CREATE TABLE IF NOT EXISTS tournament_pool_standings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pool_id UUID NOT NULL REFERENCES tournament_pools(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  matches_played INT NOT NULL DEFAULT 0,
  matches_won INT NOT NULL DEFAULT 0,
  legs_won INT NOT NULL DEFAULT 0,
  legs_lost INT NOT NULL DEFAULT 0,
  leg_difference INT GENERATED ALWAYS AS (legs_won - legs_lost) STORED,
  points INT NOT NULL DEFAULT 0, -- 2 pts par victoire, 0 par défaite
  rank INT,
  UNIQUE(pool_id, user_id)
);

-- 6. Nouvelle table : bracket (élimination directe)
CREATE TABLE IF NOT EXISTS tournament_bracket_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tournament_id UUID NOT NULL REFERENCES tournaments(id) ON DELETE CASCADE,
  round_number INT NOT NULL, -- 1 = finale, 2 = demi, 4 = quart, etc.
  position INT NOT NULL, -- position dans le round (1, 2, 3, ...)
  player1_id UUID REFERENCES users(id),
  player2_id UUID REFERENCES users(id),
  winner_id UUID REFERENCES users(id),
  match_id UUID REFERENCES matches(id), -- lien vers le match joué
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, in_progress, completed
  scheduled_at TIMESTAMPTZ,
  UNIQUE(tournament_id, round_number, position)
);

-- 7. Index
CREATE INDEX IF NOT EXISTS idx_tp_tournament ON tournament_players(tournament_id);
CREATE INDEX IF NOT EXISTS idx_tp_pool ON tournament_players(pool_id);
CREATE INDEX IF NOT EXISTS idx_tps_pool ON tournament_pool_standings(pool_id);
CREATE INDEX IF NOT EXISTS idx_tbm_tournament ON tournament_bracket_matches(tournament_id);
```

### Tâche A.2 : Nouvelles Entities TypeORM

Créer/modifier dans `backend/src/modules/tournaments/entities/` :

**`tournament-player.entity.ts`** (remplace tournament-registration.entity.ts) :
```typescript
@Entity('tournament_players')
export class TournamentPlayer {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('uuid') tournament_id: string;
  @Column('uuid') user_id: string;
  @Column({ type: 'int', nullable: true }) seed: number | null;
  @Column({ type: 'uuid', nullable: true }) pool_id: string | null;
  @Column({ type: 'boolean', default: false }) is_qualified: boolean;
  @Column({ type: 'boolean', default: false }) is_disqualified: boolean;
  @Column({ type: 'text', nullable: true }) disqualification_reason: string | null;
  @CreateDateColumn({ type: 'timestamptz' }) registered_at: Date;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' }) tournament: Tournament;
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' }) user: User;
  @ManyToOne(() => TournamentPool, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'pool_id' }) pool: TournamentPool;
}
```

**`tournament-pool.entity.ts`** :
```typescript
@Entity('tournament_pools')
export class TournamentPool {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('uuid') tournament_id: string;
  @Column({ type: 'varchar', length: 10 }) pool_name: string;
  @CreateDateColumn({ type: 'timestamptz' }) created_at: Date;

  @ManyToOne(() => Tournament, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'tournament_id' }) tournament: Tournament;
  @OneToMany(() => TournamentPlayer, tp => tp.pool) players: TournamentPlayer[];
}
```

**`tournament-bracket-match.entity.ts`** :
```typescript
@Entity('tournament_bracket_matches')
export class TournamentBracketMatch {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('uuid') tournament_id: string;
  @Column('int') round_number: number;
  @Column('int') position: number;
  @Column({ type: 'uuid', nullable: true }) player1_id: string | null;
  @Column({ type: 'uuid', nullable: true }) player2_id: string | null;
  @Column({ type: 'uuid', nullable: true }) winner_id: string | null;
  @Column({ type: 'uuid', nullable: true }) match_id: string | null;
  @Column({ type: 'varchar', length: 20, default: 'pending' }) status: string;
  @Column({ type: 'timestamptz', nullable: true }) scheduled_at: Date | null;

  // Relations...
}
```

### Tâche A.3 : Mise à jour `tournament.entity.ts`

Modifier l'entity existante pour refléter les nouvelles colonnes :
- Remplacer `max_clubs`/`enrolled_clubs` par `max_players`/`enrolled_players`
- Ajouter `format`, `pool_count`, `players_per_pool`, `qualified_per_pool`
- Ajouter `legs_per_set_pool`, `sets_to_win_pool`, `legs_per_set_bracket`, `sets_to_win_bracket`
- Ajouter `current_phase`

### Tâche A.4 : Refonte `tournaments.service.ts`

Méthodes à implémenter :
```typescript
// Inscription
async registerPlayer(tournamentId: string, userId: string): Promise<TournamentPlayer>
async unregisterPlayer(tournamentId: string, userId: string): Promise<void>

// Gestion des poules (admin/créateur)
async generatePools(tournamentId: string, userId: string): Promise<TournamentPool[]>
async getPoolStandings(poolId: string): Promise<TournamentPoolStanding[]>
async updatePoolResult(poolId: string, matchId: string): Promise<void>

// Gestion du bracket
async generateBracket(tournamentId: string, userId: string): Promise<TournamentBracketMatch[]>
async getBracket(tournamentId: string): Promise<TournamentBracketMatch[]>
async advancePhase(tournamentId: string, userId: string): Promise<Tournament>

// Disqualification
async disqualifyPlayer(tournamentId: string, playerId: string, reason: string, requesterId: string): Promise<void>
```

**Algorithme de génération des poules** :
1. Prendre tous les `tournament_players` triés par `seed` (ou ELO si pas de seed).
2. Distribuer en serpentin : joueur 1 → poule A, joueur 2 → poule B, ..., joueur N → poule N, joueur N+1 → poule N, ...
3. Créer les `tournament_pool_standings` pour chaque joueur dans sa poule.

**Algorithme de génération du bracket** :
1. Prendre les qualifiés de chaque poule (`is_qualified = true`), triés par points + leg_difference.
2. Seed le bracket : top1 poule A vs bottom qualifié poule D, etc.
3. Créer les `tournament_bracket_matches` pour le premier round.
4. Les rounds suivants sont créés vides (player1/2 = null) et remplis quand les matchs précédents sont terminés.

### Tâche A.5 : Refonte `tournaments.controller.ts`

```typescript
@Post()           create(dto, req)
@Get()             findAll(@Query status, @Query upcoming)
@Get(':id')        findOne(id)
@Post(':id/register')    register(id, req)  // inscription joueur
@Delete(':id/register')  unregister(id, req) // désinscription
@Post(':id/pools')       generatePools(id, req) // admin only
@Get(':id/pools')        getPools(id)
@Get(':id/pools/:poolId/standings')  getPoolStandings(poolId)
@Post(':id/bracket')     generateBracket(id, req) // admin only
@Get(':id/bracket')      getBracket(id)
@Post(':id/advance')     advancePhase(id, req) // admin only
@Post(':id/disqualify/:playerId')  disqualify(id, playerId, body, req)
```

---

## PARTIE B : Flutter — Pages Tournois

### Tâche B.1 : Page Liste Tournois

Fichier : `lib/features/tournaments/presentation/tournaments_list_screen.dart`

```
📱 Tournaments List
├─ AppBar("Tournois")
├─ Tabs: ["À venir", "En cours", "Terminés"]
├─ Tab "À venir" :
│   └─ ListView de TournamentCard
│       ├─ Container(GlassCard)
│       │   ├─ Row: [Icon(trophy) + Column(name, mode+finish, venue)]
│       │   ├─ Row: [enrolled/max players, date, entry_fee]
│       │   └─ Chip(status: open/full)
│       └─ onTap → context.push('/tournaments/$id')
├─ FAB: "Créer un tournoi" → context.push(AppRoutes.tournamentCreate)
└─ Pull-to-refresh
```

### Tâche B.2 : Page Détail Tournoi

Fichier : `lib/features/tournaments/presentation/tournament_detail_screen.dart`

```
📱 Tournament Detail
├─ AppBar(tournament.name)
├─ Header card (infos du tournoi)
│   ├─ Mode, Finish, Venue, Date
│   ├─ Inscriptions: "12 / 16 joueurs"
│   └─ Bouton "S'inscrire" / "Se désinscrire" / "Inscrit ✓"
├─ TabBar: ["Joueurs", "Poules", "Bracket"]
├─ Tab Joueurs:
│   └─ Liste des TournamentPlayer avec avatar, username, ELO, seed
├─ Tab Poules:
│   ├─ Si pas encore générées → "Les poules seront générées..."
│   └─ Pour chaque poule :
│       ├─ Titre "Poule A"
│       └─ Table DataTable avec colonnes:
│           [#, Joueur, J, V, LW, LL, +/-, Pts]
├─ Tab Bracket:
│   ├─ Si pas encore généré → "Le bracket sera généré..."
│   └─ Visualisation bracket (voir Tâche B.4)
└─ Si créateur : bouton admin flottant
    ├─ "Générer les poules" (si phase = registration)
    ├─ "Passer au bracket" (si phase = pools)
    └─ "Disqualifier un joueur"
```

### Tâche B.3 : Page Création Tournoi

Fichier : `lib/features/tournaments/presentation/tournament_create_screen.dart`

Formulaire avec :
- Nom (TextField, required)
- Description (TextField, multiline, optional)
- Mode (SegmentedButton: 301, 501, 701, Cricket)
- Finish (SegmentedButton: Double Out, Single Out, Master Out)
- Max joueurs (Counter: 4, 8, 16, 32)
- Format (SegmentedButton: "Élimination directe" / "Poules + Élimination")
- Si format "Poules + Élimination" :
  - Nombre de poules (Counter)
  - Qualifiés par poule (Counter, default 2)
- Config legs/sets poules (si applicable)
- Config legs/sets bracket
- Lieu (TextField)
- Date et heure (DateTimePicker)
- Frais d'inscription (TextField numeric, default 0)
- Booton "Créer" → `POST /tournaments`
- Bouton "Annuler" → context.pop()

### Tâche B.4 : Visualisation du Bracket

Créer `lib/features/tournaments/widgets/bracket_view.dart`

Widget custom pour afficher un bracket de tournoi à élimination directe :
- Scroll horizontal (`SingleChildScrollView(scrollDirection: Axis.horizontal)`)
- Chaque round est une `Column` de matchs
- Lignes de connexion entre les matchs (utiliser `CustomPaint` pour les lignes)
- Chaque match :
  ```
  Container (140 x 70)
  ├─ Row [Text(player1.name), Text(score1)]
  ├─ Divider
  └─ Row [Text(player2.name), Text(score2)]
  ```
  - Match en cours : bordure `AppColors.primary`
  - Match terminé : winner en bold
  - Match à venir : noms en `textHint`

Labels au-dessus de chaque colonne : "Quarts", "Demis", "Finale" (adapter selon le nombre de rounds).

---

## PARTIE C : Models Flutter

### `lib/features/tournaments/models/tournament_model.dart`
```dart
class TournamentModel {
  final String id;
  final String name;
  final String? description;
  final String mode;
  final String finish;
  final String format; // 'single_elimination' | 'pools_then_elimination'
  final int maxPlayers;
  final int enrolledPlayers;
  final String currentPhase;
  final String? venueName;
  final String? venueAddress;
  final String? city;
  final double entryFee;
  final DateTime scheduledAt;
  final String creatorId;
  final bool isRegistered; // calculé côté client
  // ...
}
```

### `lib/features/tournaments/models/pool_model.dart`
```dart
class PoolModel { ... }
class PoolStandingEntry { ... }
```

### `lib/features/tournaments/models/bracket_match_model.dart`
```dart
class BracketMatchModel { ... }
```

### Controller : `lib/features/tournaments/controller/tournament_controller.dart`
Riverpod providers :
```dart
final tournamentsListProvider = FutureProvider<List<TournamentModel>>((ref) => ...);
final tournamentDetailProvider = FutureProvider.family<TournamentDetail, String>((ref, id) => ...);
final tournamentPoolsProvider = FutureProvider.family<List<PoolModel>, String>((ref, tournamentId) => ...);
final tournamentBracketProvider = FutureProvider.family<List<BracketMatchModel>, String>((ref, tournamentId) => ...);
```

---

## Contraintes
- Le refactoring backend doit être rétrocompatible : l'endpoint `GET /tournaments` doit toujours fonctionner.
- Ne pas supprimer `tournament_registrations` en production s'il y a des données — ajouter une condition de vérification. En dev, le DROP est OK.
- Le bracket doit pouvoir gérer des byes (joueur seul dans un match = victoire automatique) pour les puissances de 2 non complètes (ex: 12 joueurs dans un bracket de 16 → 4 byes au round 1).
- La visualisation du bracket doit fonctionner pour 4, 8, 16 et 32 joueurs.
- L'inscription à un tournoi est individuelle (pas par club). Un joueur peut s'inscrire seul.
- La disqualification est réservée au créateur du tournoi.
- Tous les textes en français.
- Utiliser les widgets existants (GlassCard, StatCard, SectionHeader, PlayerAvatar) partout.
