# 🏗️ CODEX PROMPT 01 – Backend : Migrations SQL & Endpoints Prérequis

## Contexte
Tu travailles sur le backend NestJS du projet **Dart District** (`backend/`). La base de données est PostgreSQL. Respecte les conventions de `ai_project_guidelines.md` : DTO obligatoires, validation class-validator, modules découplés, pas de logique métier dans les controllers, snake_case pour les fichiers, PascalCase pour les classes.

## Objectif
Créer **toutes les migrations et endpoints prérequis** identifiés dans l'analyse des besoins V2.

---

## Tâche 1 : Migration SQL `010_v2_evolution.sql`

Créer le fichier `backend/sql/010_v2_evolution.sql` avec les instructions suivantes :

```sql
-- 1. Ajout du booléen ranked sur les matchs
ALTER TABLE matches ADD COLUMN IF NOT EXISTS is_ranked BOOLEAN DEFAULT false;

-- 2. Ajout du champ surrendered_by sur les matchs
ALTER TABLE matches ADD COLUMN IF NOT EXISTS surrendered_by UUID REFERENCES users(id) ON DELETE SET NULL;

-- 3. Ajout du nombre de cibles sur les clubs
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS dart_boards_count INT DEFAULT 0;

-- 4. Ajout des compteurs 140+ et 100+ dans player_stats
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS count_140_plus INT DEFAULT 0;
ALTER TABLE player_stats ADD COLUMN IF NOT EXISTS count_100_plus INT DEFAULT 0;

-- 5. Tag abandon tournoi sur les users
ALTER TABLE users ADD COLUMN IF NOT EXISTS has_tournament_abandon BOOLEAN DEFAULT false;

-- 6. Table badges
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(50) UNIQUE NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  image_asset VARCHAR(200) NOT NULL, -- nom de l'asset local ou URL
  category VARCHAR(50) DEFAULT 'general',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. Table user_badges
CREATE TABLE IF NOT EXISTS user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, badge_id)
);

-- 8. Index pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_matches_is_ranked ON matches(is_ranked) WHERE is_ranked = true;
CREATE INDEX IF NOT EXISTS idx_matches_status_ranked ON matches(status, is_ranked);
CREATE INDEX IF NOT EXISTS idx_user_badges_user ON user_badges(user_id);
```

## Tâche 2 : Endpoint Upload Avatar

Créer/modifier les fichiers suivants :
- `backend/src/modules/users/users.controller.ts` : Ajouter `POST /users/me/avatar` (multipart/form-data)
- `backend/src/modules/users/users.service.ts` : Méthode `uploadAvatar(userId, file)` qui :
  1. Valide le type MIME (image/jpeg, image/png, image/webp uniquement)
  2. Valide la taille (max 5 Mo)
  3. Génère deux variantes avec `sharp` :
     - `{uuid}_md.webp` (200x200, quality 80)
     - `{uuid}_sm.webp` (64x64, quality 70)
  4. Sauvegarde dans `uploads/avatars/`
  5. Met à jour `avatar_url` de l'utilisateur avec le chemin relatif de la variante `_md`
  6. Supprime l'ancien avatar s'il existe
  7. Retourne les URLs des deux variantes

**Configuration** :
- Utiliser `@UseInterceptors(FileInterceptor('avatar'))` de `@nestjs/platform-express`
- Installer `sharp` : `npm install sharp @types/sharp`
- Servir les fichiers statiques via `app.useStaticAssets('uploads', { prefix: '/uploads' })` dans `main.ts`

## Tâche 3 : Pagination sur `GET /matches/me`

Modifier `backend/src/modules/matches/matches.controller.ts` et `matches.service.ts` :
- Ajouter `@Query('offset') offset?: number` et `@Query('status') status?: string` et `@Query('ranked') ranked?: string`
- Le service filtre sur `status = 'completed'` si demandé, `is_ranked = true` si `ranked=true`
- Offset-based pagination : `.skip(offset).take(limit)`

## Tâche 4 : Recherche clubs avec géolocalisation

Modifier `backend/src/modules/clubs/clubs.controller.ts` et `clubs.service.ts` :
- Ajouter endpoint `GET /clubs/search` avec params `q`, `lat`, `lng`, `limit`
- Si `lat` et `lng` fournis : trier par distance Haversine (SQL natif) :
```sql
SELECT *, (6371 * acos(cos(radians($1)) * cos(radians(latitude)) * cos(radians(longitude) - radians($2)) + sin(radians($1)) * sin(radians(latitude)))) AS distance
FROM clubs
WHERE name ILIKE $3 OR city ILIKE $3
ORDER BY distance ASC
LIMIT $4
```
- Si pas de coordonnées : trier par nom alphabétique
- Ajouter `@Query('q') q?: string` et `@Query('city') city?: string` sur `GET /clubs`

## Tâche 5 : Mise à jour des entities

Mettre à jour les entities TypeORM pour refléter les nouvelles colonnes :
- `Match` : ajouter `is_ranked`, `surrendered_by`
- `Club` : ajouter `dart_boards_count`
- `PlayerStat` : ajouter `count_140_plus`, `count_100_plus`
- `User` : ajouter `has_tournament_abandon`
- Créer les entities `Badge` et `UserBadge` dans un nouveau module `badges/`

## Tâche 6 : Mise à jour StatsService

Dans `backend/src/modules/stats/stats.service.ts` :
- Ajouter les champs `count140Plus` et `count100Plus` dans l'interface de `updateAfterMatch`
- Conditionner l'appel au processElo sur `match.is_ranked === true`
- Les compteurs 140+ et 100+ sont transmis par le caller

## Tâche 7 : Endpoint rapport de match

Créer `GET /matches/:id/report` qui retourne :
```json
{
  "match_id": "...",
  "mode": "501",
  "final_sets": [2, 1],
  "players": [
    {
      "user_id": "...",
      "username": "...",
      "avg_score": 58.3,
      "legs_won": 4,
      "count_180": 2,
      "count_140_plus": 5,
      "count_100_plus": 8,
      "checkout_rate": 33.3,
      "highest_checkout": 120
    },
    { ... }
  ],
  "timeline": [
    { "set": 1, "leg": 1, "winner_username": "Player1" },
    { "set": 1, "leg": 2, "winner_username": "Player2" },
    ...
  ]
}
```

---

## Contraintes
- Ne pas casser les endpoints existants (rétrocompatibilité)
- Toutes les nouvelles colonnes doivent avoir une valeur par défaut
- Tester chaque endpoint avec un curl ou un test minimal
- Respecter la structure modulaire NestJS existante
