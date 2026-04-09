# 🎯 Dart District — Instructions Codex Sprint

> **Destinataire** : ChatGPT-5-3 Codex (agent autonome)  
> **Projet** : Dart District — Application mobile Flutter de fléchettes  
> **Date** : 09/04/2026  
> **Documents de référence** : `ai_project_guidelines.md`, `context_project.md`

---

## 📐 Contexte technique du projet

### Stack
| Couche | Technologie |
|--------|-------------|
| Frontend | Flutter (Dart) — Riverpod, GoRouter, fl_chart, flutter_map, vector_map_tiles |
| Backend | NestJS (TypeScript) — PostgreSQL, WebSockets |
| Base de données | PostgreSQL sur VPS Debian (dart-district.fr) |
| Stockage local | Hive (via `LocalStorage`) |
| Auth | JWT + Google Sign-In + Apple Sign-In |

### Architecture Flutter (feature-first)
```
lib/
├── core/
│   ├── config/         → app_colors.dart, app_constants.dart, app_routes.dart, app_theme.dart, patch_notes.dart
│   ├── database/       → local_storage.dart (Hive)
│   ├── errors/
│   ├── network/        → api_client.dart, websocket_client.dart, api_providers.dart, nominatim_service.dart
│   ├── security/
│   └── version/
├── features/
│   ├── auth/           → login, subscription (sso_username_screen), user_model
│   ├── club/           → club CRUD, member_list_tile, territory modals, club_model
│   ├── contacts/       → chat, contacts list
│   ├── home/           → home_screen, widgets (stats_summary, quick_actions, recent_matches, tournament_tile, territory_info, club_info)
│   ├── map/            → map_screen (flutter_map + PMTiles IRIS), territory_model, map_controller, ranking_list, territory_tile
│   ├── match/          → match_live_screen, cricket_match_screen, chasseur_match_screen, match_report_screen, match_history_screen
│   │                     widgets: scoreboard, dart_input, dartboard_input, dartboard_input_stats, tempo_zone_input, round_details, match_end_modal
│   │                     models: match_model, cricket_match_state, chasseur_match_state, match_report_data
│   │                     controllers: match_controller, cricket_match_controller, chasseur_match_controller
│   ├── play/           → play_screen, game_setup_screen, x01_modes_screen, cricket_mode_screen, chasseur_mode_screen, match_invite_player_screen, qr_scan_screen
│   ├── profile/        → profile_screen, settings_screen, badges_screen, about_screen
│   │                     widgets: elo_chart, precision_section, badge_grid, match_history_tile
│   └── tournaments/    → tournament CRUD, bracket_view, tournament_model
├── shared/
│   ├── models/         → dartboard_heatmap_models.dart, match_history_summary.dart
│   └── widgets/        → app_scaffold, confirm_dialog, dart_button, glass_card, match_history_list, player_avatar, score_display, section_header, stat_card, animated_counter_text
└── main.dart
```

### Palette de couleurs (AppColors — `lib/core/config/app_colors.dart`)
```dart
primary       = Color(0xFFC8FF00)  // Neon lime
secondary     = Color(0xFF6A6FFF)  // Electric indigo
accent        = Color(0xFFFFC70A)  // Gold
background    = Color(0xFF060A14)
surface       = Color(0xFF101728)
card          = Color(0xFF161F33)
success       = Color(0xFF29D97D)
error         = Color(0xFFFF4A55)
info          = Color(0xFF39C3FF)
```

### Modèle de données clés
- **UserModel** : id, username, email, avatarUrl, elo, clubId, clubName, isAdmin, stats (PlayerStats)
- **PlayerStats** : matchesPlayed, matchesWon, averageScore, checkoutRate, highest180s, count140Plus, count100Plus, bestAverage
- **MatchModel** : id, mode, startingScore, players, finishType ('doubleOut'|'singleOut'|'masterOut'), isRanked, isTerritorial, territoryClubId, territoryCodeIris, setsToWin, legsPerSet
- **TerritoryModel** : id, codeIris, name, status (TerritoryStatus enum), ownerClubId, ownerClubName, latitude, longitude
- **TerritoryStatus** : available, locked, alert, conquered, conflict
- **ClubMember** : username, avatarUrl, role, elo

### Backend SQL (migrations séquentielles dans `backend/sql/`)
Dernière migration : `021_territory_club_points_and_match_fields.sql`
Table existante : `club_territory_points(id, club_id, code_iris, points, created_at, updated_at)`

### Conventions
- Nommage fichiers : **snake_case**
- Classes : **PascalCase**
- Variables/méthodes : **camelCase**
- State management : **Riverpod** (providers, StateNotifier, AsyncNotifier)
- Routing : **GoRouter** (app_routes.dart)
- Pas de logique métier dans les widgets ni les controllers NestJS
- DTO obligatoires côté backend
- Endpoints versionnés `/api/v1/...`

---

## 📋 BLOC 1 — Corrections et améliorations UI/UX

### 1.1 Tiles de territoires sur la Map

**Fichiers concernés** : `lib/features/map/presentation/map_screen.dart`, `lib/features/map/models/territory_model.dart`, `lib/features/map/controller/map_controller.dart`

**Objectif** : Afficher les tuiles polygones IRIS sur la carte avec des couleurs dynamiques selon le statut du territoire.

**Règles de couleur** :
| Statut | Condition | Couleur |
|--------|-----------|---------|
| Disponible | Le territoire n'est contrôlé par aucun club | `AppColors.accent` (0xFFFFC70A — Gold) |
| Contrôlé par mon club | Le territoire est contrôlé par le club de l'utilisateur connecté | `AppColors.primary` (0xFFC8FF00 — Neon lime) |
| Bloqué (blocked) | Le territoire a le statut `locked` | Bleu — `AppColors.info` (0xFF39C3FF) |
| En conflit | Le club qui contrôle a **moins de 50 points d'avance** sur le 2e club sur ce territoire | Rouge — `AppColors.error` (0xFFFF4A55) |

**Détail d'implémentation** :
- Les statuts et associations club↔territoire sont calculés côté backend à la fin de chaque match « territorial ».
- Le frontend récupère la liste des territoires avec leur statut via l'API `/api/v1/territories`.
- Pour différencier « contrôlé par mon club » vs « contrôlé par un autre club », comparer `territory.ownerClubId` avec `currentUser.clubId`.
- Si `ownerClubId == currentUser.clubId` → couleur `AppColors.primary`.
- Si `ownerClubId != null && ownerClubId != currentUser.clubId` et statut `conquered` → couleur selon le club tiers (utiliser `AppColors.secondary` ou la couleur "conquered" standard).
- Si `status == conflict` → `AppColors.error`.
- Si `status == locked` → `AppColors.info`.
- Si `status == available` → `AppColors.accent`.
- Les polygones sont dessinés via les couches `vector_map_tiles` / PMTiles IRIS. Appliquer la couleur de remplissage (fill avec opacité ~0.35) et un contour (stroke) de la même couleur.
- Assurer que la légende en bas de la carte reflète ces 4 états.

---

### 1.2 Dartboard Input Stats — Correction des couleurs du heatmap

**Fichiers concernés** : `lib/features/match/widgets/dartboard_input_stats.dart`, `lib/shared/models/dartboard_heatmap_models.dart`

**Objectif** : Ajuster les couleurs du composant de visualisation de la cible (heatmap des zones fortes/faibles).

**Modifications** :
1. **Zone faible** (peu de tirs) → Couleur **bleue** (`AppColors.info` / 0xFF39C3FF)
2. **Zone forte** (beaucoup de tirs) → Couleur **rouge** (`AppColors.error` / 0xFFFF4A55)
3. **Dégradé** : bleu → orange (0xFFFF8C00) → rouge
4. **Fond derrière la cible** : doit être **transparent** (pas le `Color(0xFF0E1014)` actuel)

**Technique** :
- Dans le `Container` qui enveloppe la cible, remplacer `color: const Color(0xFF0E1014)` par `color: Colors.transparent`.
- Dans le `CustomPainter` de la heatmap, ajuster le gradient de couleurs :
  ```dart
  // Ancien : vert → jaune → rouge (ou similaire)
  // Nouveau :
  final gradient = [
    AppColors.info,         // 0xFF39C3FF — bleu (zone faible, fréquence basse)
    Color(0xFFFF8C00),      // orange (transition)
    AppColors.error,        // 0xFFFF4A55 — rouge (zone forte, fréquence haute)
  ];
  ```
- Mettre à jour la légende si `showLegend == true` pour refléter « Zone faible = bleu » et « Zone forte = rouge ».
- Ce composant est utilisé dans : fin de match (match_report_screen), historique (match_history_screen) et profil (precision_section). Vérifier la cohérence partout.

---

### 1.3 Progression ELO — Refonte complète du graphique

**Fichiers concernés** : `lib/features/profile/widgets/elo_chart.dart`, `lib/features/profile/controller/profile_controller.dart`, `lib/features/profile/data/profile_service.dart`

**Objectif** : Transformer le graphique ELO simple en un graphique interactif avec 3 modes d'affichage et navigation par swipe.

**Modes d'affichage** (boutons de sélection au-dessus du graphique) :

| Mode | Période affichée | Granularité des points |
|------|-------------------|----------------------|
| **Semaine** | 7 derniers jours | 1 point par jour |
| **Mois** | 30 derniers jours | 1 point par jour |
| **Année** | 12 derniers mois | 1 point par mois |

**Comportement par défaut** :
- Au chargement, afficher le mode **Semaine** avec les 7 derniers jours.
- Exemple pour l'année : si la date est le 08/04/2026, afficher un graphique mois par mois de 04/2025 à 04/2026 inclus (13 points).

**Navigation par swipe** :
- L'utilisateur peut **glisser le doigt vers la droite** pour voir les périodes précédentes :
  - En mode semaine : semaine précédente (J-14 à J-7, puis J-21 à J-14, etc.)
  - En mode mois : mois précédent (J-60 à J-30, etc.)
  - En mode année : année précédente
- Utiliser un `PageView` ou `GestureDetector` avec animation de transition horizontale.

**Boutons de sélection** :
```
[  Semaine  ] [   Mois   ] [  Année   ]
```
- Style : `ToggleButtons` ou `ChoiceChip` avec `AppColors.primary` pour la sélection active.
- Changer de mode remet automatiquement sur la période la plus récente.

**API Backend** :
- Créer ou adapter l'endpoint `GET /api/v1/users/:id/elo-history` (ou `/api/v1/profile/elo-history`) avec les paramètres :
  ```
  ?mode=week|month|year
  &offset=0      // 0 = période courante, 1 = période précédente, etc.
  ```
- Réponse :
  ```json
  {
    "success": true,
    "data": {
      "mode": "week",
      "period_label": "01/04/2026 - 08/04/2026",
      "points": [
        { "date": "2026-04-01", "elo": 1230 },
        { "date": "2026-04-02", "elo": 1245 },
        ...
      ]
    }
  }
  ```
- Pour le mode `year`, les `date` sont au format `"2025-04"`, `"2025-05"`, etc. et la valeur ELO est la moyenne ou la dernière valeur du mois.

**Graphique** :
- Utiliser `fl_chart` (`LineChart`) avec `curveType` activé (courbe lissée).
- Afficher les labels de l'axe X :
  - Semaine/Mois : `"Lun"`, `"Mar"`, ... ou `"01/04"`, `"02/04"`, ...
  - Année : `"Avr"`, `"Mai"`, ...
- Couleur de la courbe : `AppColors.primary`.
- Point de donnée : petit dot `AppColors.primary` avec halo.
- Zone sous la courbe : gradient `AppColors.primary.withOpacity(0.15)` → transparent.

**SQL Backend** :
- S'assurer qu'il existe une table `elo_history` ou similaire :
  ```sql
  CREATE TABLE IF NOT EXISTS elo_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    elo INTEGER NOT NULL,
    recorded_at DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE(user_id, recorded_at)
  );
  CREATE INDEX IF NOT EXISTS idx_elo_history_user_date ON elo_history(user_id, recorded_at DESC);
  ```
- À chaque fin de match classé, insérer/mettre à jour l'ELO du jour via un `INSERT ... ON CONFLICT (user_id, recorded_at) DO UPDATE SET elo = EXCLUDED.elo`.

---

### 1.4 Refonte des tuiles de stats du profil

**Fichier concerné** : `lib/features/profile/presentation/profile_screen.dart`

**Layout actuel** : Plusieurs tuiles individuelles (ELO, Victoires, Défaites, 180s, 140+, 100+, Moyenne, Checkout).

**Nouveau layout** :

```
Ligne 1 :
┌──────────┐ ┌──────────────────────┐
│   ELO    │ │        V / D         │
│  (1x1)   │ │       (2x1)          │
│   1230   │ │  45V / 12D           │
└──────────┘ └──────────────────────┘

Ligne 2 :
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Moyenne  │ │ Checkout │ │  Tirs    │ 
│  (1x1)   │ │  (1x1)   │ │ (1x1)    │
│  68.4    │ │  42.1%   │ │ 180s 12  │
│          │ │          │ │ 140+ 34  │
│          │ │          │ │ 100+ 89  │
└──────────┘ └──────────┘ └──────────┘
```

**Détails** :
- **Supprimer toutes les icônes** des tuiles.
- **ELO (1x1)** : Affiche la valeur ELO courante. Style : grande police `AppColors.primary`.
- **V/D (2x1 — double largeur)** : Fusionne Victoires et Défaites.
  - Format : `{{victoires}}V / {{défaites}}D`
  - Le nombre de victoires en couleur `AppColors.primary` (neon lime).
  - Le nombre de défaites en couleur `AppColors.error` (rouge).
  - Le `/` et `V`, `D` en `AppColors.textSecondary`.
- **Moyenne (1x1)** : Affiche `averageScore`.
- **Checkout (1x1)** : Affiche `checkoutRate` en `%`.
- **Tirs (1x1)** : Fusionne 180s + 140+ + 100+ en une seule tuile.
  - Titre : « Tirs »
  - Contenu empilé verticalement :
    ```
    12 × 180
    34 × 140+
    89 × 100+
    ```
  - Chaque ligne en petite police, valeur en gras.

**Implémentation** :
- Utiliser un `Wrap` ou `Row`/`Column` avec `Expanded` pour les proportions.
- Pour la tuile V/D double : `Expanded(flex: 2, ...)`.
- Utiliser le widget `StatCard` existant ou un dérivé adapté (sans icône).

---

### 1.5 Réorganisation du profil

**Fichier concerné** : `lib/features/profile/presentation/profile_screen.dart`

**Nouvel ordre des sections (de haut en bas)** :
1. En-tête profil (avatar, username, bouton paramètres)
2. Tuiles de stats (nouveau layout §1.4)
3. **Progression ELO** (nouveau composant §1.3) — déplacé ici, au-dessus de la section précision
4. Section Précision (heatmap dartboard — `PrecisionSection`)
5. **Section Historique** — Afficher le composant `MatchHistoryList` partagé (voir §1.6)
6. Section Badges

---

### 1.6 Composant historique généralisé

**Fichiers concernés** : `lib/shared/widgets/match_history_list.dart`, `lib/features/profile/presentation/profile_screen.dart`, `lib/features/home/presentation/home_screen.dart`

**Objectif** : Le composant `MatchHistoryList` (déjà utilisé côté menu/home) doit être réutilisé dans la section historique du profil.

**Actions** :
1. Vérifier que `MatchHistoryList` est bien un widget générique acceptant une liste de `MatchHistorySummary`.
2. Ajouter les props nécessaires si manquants (ex: `maxItems`, `showViewAll`, `onViewAll`).
3. Dans `profile_screen.dart`, ajouter une section « Historique » qui utilise `MatchHistoryList`.
4. Charger les données via `profileControllerProvider` ou un nouveau provider dédié.
5. S'assurer du même rendu visuel que dans le menu.

---

### 1.7 Score de conquête utilisateur

**Backend** :

1. **Migration SQL** (`backend/sql/022_user_conquest_score.sql`) :
```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS conquest_score INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_users_conquest_score ON users(conquest_score DESC);
```

2. **Logique backend** (service de fin de match territorial) :
- À la fin d'un match territorial, lorsque le joueur fait gagner des points à son club :
  - Incrémenter `users.conquest_score` du même nombre de points gagnés par le club.
  - Exception : si les deux joueurs sont du **même club**, pas de points de conquête pour le joueur ni pour le club (cf. §2.1).
- L'API `/api/v1/users/me` et `/api/v1/users/:id` doit retourner `conquest_score`.

**Frontend** :

3. **UserModel** (`lib/features/auth/models/user_model.dart`) :
- Ajouter le champ `int conquestScore` (default 0).
- Parser depuis `json['conquest_score']` dans `fromApi`.

4. **Tuile « Points de conquête » du menu** (`lib/features/home/presentation/home_screen.dart`) :
- La tuile `_MetricCard` qui affiche « Points de conquête » doit afficher `user.conquestScore` au lieu de `homeState.conquestPoints`.
- Au tap, rediriger vers la page club.

5. **Liste des membres d'un club** (`lib/features/club/widgets/member_list_tile.dart`) :
- Remplacer le bouton « Jouer » par l'affichage du score de conquête du joueur :
  - Valeur en couleur `AppColors.accent`.
  - Suivi de l'icône `Icons.emoji_events_outlined` en `AppColors.accent`.
  - Ex: `« 156 🏆 »` (le chiffre puis l'icône).
- Nécessite d'ajouter `conquestScore` au modèle `ClubMember`.

---

### 1.8 Recherche globale de joueurs dans l'invitation de partie

**Fichier concerné** : `lib/features/play/presentation/match_invite_player_screen.dart`

**Objectif** : Permettre de rechercher **tous les joueurs** (pas seulement les amis) pour inviter dans une partie.

**Implémentation** :
1. Garder la liste des amis comme résultat par défaut.
2. Ajouter un champ de recherche en haut de l'écran.
3. Lorsque l'utilisateur tape du texte (min 2 caractères) :
   - Appeler `GET /api/v1/users/search?q=<query>&limit=20` (debounce 400ms).
   - Afficher les résultats sous la liste d'amis, avec un séparateur « Autres joueurs ».
4. Chaque résultat affiche : avatar, username, ELO.
5. Au tap, sélectionner le joueur comme adversaire (même comportement qu'un ami).

**Backend** :
- Créer l'endpoint `GET /api/v1/users/search` :
  ```sql
  SELECT id, username, avatar_url, elo
  FROM users
  WHERE username ILIKE '%' || $1 || '%'
    AND id != $currentUserId
  ORDER BY username
  LIMIT 20;
  ```
- Protéger par JWT. Sanitizer le paramètre `q`.

---

### 1.9 Nom de l'application Android

**Fichiers concernés** :
- `android/app/src/main/AndroidManifest.xml` → `android:label="Dart District"`
- `android/app/build.gradle.kts` → Pas de changement nécessaire (applicationId reste `fr.dartdistrict.mobile`)
- Icône mini (adaptive icon pour mode onglet) : s'assurer que `android:roundIcon` et `ic_launcher` incluent une version « monochrome » (Android 13+).

**Actions** :
1. Dans `AndroidManifest.xml`, changer `android:label` de `dart_district` à `Dart District`.
2. Vérifier/ajouter `<adaptive-icon>` dans `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` avec un `<monochrome>` layer pour l'icône en mode onglet.
3. Si l'icône monochrome n'existe pas, créer un drawable vectoriel simplifié du logo.

---

### 1.10 Réorganisation du menu (Home Screen)

**Fichier concerné** : `lib/features/home/presentation/home_screen.dart`

**Modifications** :
1. **Déplacer « Actions rapides »** (`_QuickActions`) AVANT la section « Forme récente ».
2. **Renommer** « Forme Récente » en « Dernières parties ».
3. **Section « Prochains Tournois »** : ne pas afficher cette section entière si aucun tournoi n'est disponible.
   - Condition : si `activeTournaments` est un `AsyncData` avec une liste vide, ne pas rendre le `SliverToBoxAdapter` du titre ni du contenu de cette section.

**Nouvel ordre des sections** :
1. Header (avatar, username, club)
2. Tuiles métriques (Territoires, Points de conquête)
3. **Actions rapides** ← déplacé ici
4. **Dernières parties** ← renommé
5. **Prochains Tournois** ← conditionnel

---

## 📋 BLOC 2 — Vérifications et corrections

### 2.1 Tournois territoriaux — Génération des matchs

**Fichiers concernés** : Backend — module tournaments, module matches

**Objectif** : Vérifier et corriger que dans un tournoi « territorial » (`is_territorial = true`) :

1. **Tous les matchs générés** dans le tournoi sont de type `isTerritorial = true` et `isRanked = true` (classés systématiquement).
2. **Si deux joueurs du même club s'affrontent** :
   - L'ELO des deux joueurs évolue normalement à la fin du match.
   - **AUCUN point de conquête** n'est attribué : ni au club, ni aux joueurs.
   - Vérifier ce cas dans la logique de fin de match (`match completion handler`).
3. **Condition** pour sauter l'attribution de points de conquête :
   ```typescript
   if (player1.clubId === player2.clubId) {
     // Skip conquest points for both club_territory_points and users.conquest_score
   }
   ```

**Points de vérification backend** :
- Service `tournaments` — méthode de génération des matchs : s'assurer que `is_territorial` et `is_ranked` sont propagés.
- Service `matches` — méthode `completeMatch` ou équivalent : ajouter la garde `sameClub`.

---

### 2.2 Master-Out — Vérification du mode

**Fichiers concernés** : `lib/features/match/controller/match_controller.dart`, `lib/features/match/presentation/match_live_screen.dart`, `lib/features/play/presentation/game_setup_screen.dart`

**Règle du Master-Out** :
- Le joueur doit finir un leg par un **double OU un triple** (pas un single).
- C'est une variante de double-out élargie aux triples.

**Points de vérification** :

1. **GameSetupScreen** : Vérifier que `FinishType.masterOut` est bien proposé dans les options X01 et que la valeur `'masterOut'` est envoyée au `MatchModel`.

2. **MatchController** — Validation du score final :
   ```dart
   bool _isValidFinish(int remaining, int multiplier, String finishType) {
     if (remaining != 0) return false;
     switch (finishType) {
       case 'doubleOut':
       case 'double_out':
         return multiplier == 2;
       case 'masterOut':
       case 'master_out':
         return multiplier == 2 || multiplier == 3; // Double OU Triple
       case 'singleOut':
       case 'single_out':
         return true;
       default:
         return multiplier == 2;
     }
   }
   ```

3. **Modale de fin** (`match_end_modal.dart`) :
   - En mode `masterOut`, la modale de fin qui demande le **nombre de tentatives de finish** doit également s'afficher (comme en `doubleOut`).
   - Vérifier la condition d'affichage :
     ```dart
     final showFinishAttempts = finishType == 'doubleOut' || 
                                 finishType == 'double_out' ||
                                 finishType == 'masterOut' || 
                                 finishType == 'master_out';
     ```

4. **Backend** : Vérifier la même logique dans le service de validation côté serveur.

---

## 📋 BLOC 3 — Internationalisation (i18n)

### 3.1 Tables de base de données

**Migration SQL** (`backend/sql/023_internationalization.sql`) :

```sql
-- Table des langues disponibles
CREATE TABLE IF NOT EXISTS languages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(10) NOT NULL UNIQUE,        -- Ex: 'fr-FR', 'en-US', 'es-ES'
  country_name VARCHAR(100) NOT NULL,       -- Ex: 'France', 'United States'
  language_name VARCHAR(100) NOT NULL,      -- Ex: 'Français', 'English'
  flag_emoji VARCHAR(10) NOT NULL,          -- Ex: '🇫🇷', '🇺🇸' (emoji drapeau)
  is_available BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Données initiales
INSERT INTO languages (code, country_name, language_name, flag_emoji, is_available) VALUES
  ('fr-FR', 'France', 'Français', '🇫🇷', true),
  ('en-US', 'United States', 'English', '🇺🇸', true)
ON CONFLICT (code) DO NOTHING;

-- Table des traductions
CREATE TABLE IF NOT EXISTS translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(255) NOT NULL,               -- Ex: 'SCREEN.PLAY.CRICKET_LABEL'
  language_code VARCHAR(10) NOT NULL REFERENCES languages(code) ON DELETE CASCADE,
  value TEXT NOT NULL,                      -- La traduction
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(key, language_code)
);

CREATE INDEX IF NOT EXISTS idx_translations_key ON translations(key);
CREATE INDEX IF NOT EXISTS idx_translations_lang ON translations(language_code);

-- Ajout de la langue préférée sur l'utilisateur
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'fr-FR';
```

### 3.2 Convention de nommage des clés

Format hiérarchique : `SECTION.SOUS_SECTION.ELEMENT`

Exemples :
```
COMMON.YES
COMMON.NO
COMMON.CANCEL
COMMON.CONFIRM
COMMON.SAVE
COMMON.DELETE
COMMON.LOADING
COMMON.ERROR_GENERIC
COMMON.RETRY

NAV.HOME
NAV.MAP
NAV.PLAY
NAV.CLUB
NAV.PROFILE

SCREEN.HOME.TITLE
SCREEN.HOME.TERRITORIES_CONTROLLED
SCREEN.HOME.CONQUEST_POINTS
SCREEN.HOME.RANK
SCREEN.HOME.LIVE_MAP
SCREEN.HOME.QUICK_ACTIONS
SCREEN.HOME.LAST_MATCHES
SCREEN.HOME.UPCOMING_TOURNAMENTS
SCREEN.HOME.VIEW_HISTORY
SCREEN.HOME.VIEW_ALL

SCREEN.MAP.TITLE
SCREEN.MAP.SEARCH_PLACEHOLDER
SCREEN.MAP.LEGEND_AVAILABLE
SCREEN.MAP.LEGEND_MY_CLUB
SCREEN.MAP.LEGEND_BLOCKED
SCREEN.MAP.LEGEND_CONFLICT
SCREEN.MAP.RANKING

SCREEN.PLAY.TITLE
SCREEN.PLAY.MODE_301
SCREEN.PLAY.MODE_501
SCREEN.PLAY.MODE_701
SCREEN.PLAY.MODE_CRICKET
SCREEN.PLAY.MODE_CHASSEUR
SCREEN.PLAY.CRICKET_LABEL
SCREEN.PLAY.CHASSEUR_LABEL
SCREEN.PLAY.SETUP_TITLE
SCREEN.PLAY.FINISH_TYPE
SCREEN.PLAY.DOUBLE_OUT
SCREEN.PLAY.SINGLE_OUT
SCREEN.PLAY.MASTER_OUT
SCREEN.PLAY.LEGS_PER_SET
SCREEN.PLAY.SETS_TO_WIN
SCREEN.PLAY.RANKED
SCREEN.PLAY.TERRITORIAL
SCREEN.PLAY.START_MATCH
SCREEN.PLAY.INVITE_PLAYER
SCREEN.PLAY.SCAN_QR
SCREEN.PLAY.LOCAL
SCREEN.PLAY.GUEST_NAME_HINT
SCREEN.PLAY.FIRST_THROW

SCREEN.MATCH.VS
SCREEN.MATCH.ROUND
SCREEN.MATCH.LEG
SCREEN.MATCH.SET
SCREEN.MATCH.SCORE
SCREEN.MATCH.AVERAGE
SCREEN.MATCH.CHECKOUT_RATE
SCREEN.MATCH.DARTS_THROWN
SCREEN.MATCH.FINISH_ATTEMPTS
SCREEN.MATCH.WINNER
SCREEN.MATCH.MATCH_OVER
SCREEN.MATCH.CONFIRM_ABANDON
SCREEN.MATCH.ABANDON
SCREEN.MATCH.MANUAL_INPUT
SCREEN.MATCH.DARTBOARD_INPUT
SCREEN.MATCH.TEMPO_INPUT

SCREEN.CLUB.TITLE
SCREEN.CLUB.CREATE
SCREEN.CLUB.SEARCH_PLACEHOLDER
SCREEN.CLUB.MEMBERS
SCREEN.CLUB.TERRITORIES
SCREEN.CLUB.RANKING
SCREEN.CLUB.TOURNAMENTS
SCREEN.CLUB.JOIN
SCREEN.CLUB.LEAVE
SCREEN.CLUB.CONQUEST_POINTS

SCREEN.PROFILE.TITLE
SCREEN.PROFILE.ELO
SCREEN.PROFILE.WINS_LOSSES
SCREEN.PROFILE.AVERAGE
SCREEN.PROFILE.CHECKOUT
SCREEN.PROFILE.SHOTS
SCREEN.PROFILE.ELO_PROGRESSION
SCREEN.PROFILE.WEEK
SCREEN.PROFILE.MONTH
SCREEN.PROFILE.YEAR
SCREEN.PROFILE.PRECISION
SCREEN.PROFILE.HISTORY
SCREEN.PROFILE.BADGES
SCREEN.PROFILE.SETTINGS
SCREEN.PROFILE.NO_DATA

SCREEN.SETTINGS.TITLE
SCREEN.SETTINGS.SCORE_MODE
SCREEN.SETTINGS.LANGUAGE
SCREEN.SETTINGS.SIGN_OUT
SCREEN.SETTINGS.DELETE_ACCOUNT
SCREEN.SETTINGS.DART_SENSE

SCREEN.AUTH.LOGIN_TITLE
SCREEN.AUTH.SIGN_IN_GOOGLE
SCREEN.AUTH.SIGN_IN_APPLE
SCREEN.AUTH.GUEST_MODE
SCREEN.AUTH.CHOOSE_USERNAME
SCREEN.AUTH.USERNAME_HINT
SCREEN.AUTH.CHOOSE_LANGUAGE

SCREEN.MATCH_REPORT.TITLE
SCREEN.MATCH_REPORT.STATS
SCREEN.MATCH_REPORT.PRECISION
SCREEN.MATCH_REPORT.HEATMAP_EMPTY

SCREEN.TOURNAMENTS.TITLE
SCREEN.TOURNAMENTS.CREATE
SCREEN.TOURNAMENTS.NO_TOURNAMENTS
SCREEN.TOURNAMENTS.BRACKET

SCREEN.CONTACTS.TITLE
SCREEN.CONTACTS.SEARCH
SCREEN.CONTACTS.NO_CONTACTS

HEATMAP.WEAK_ZONE
HEATMAP.STRONG_ZONE

MATCH_STATUS.WIN
MATCH_STATUS.LOSS
MATCH_STATUS.IN_PROGRESS
MATCH_STATUS.ABANDONED

PERIOD.TODAY
PERIOD.YESTERDAY
PERIOD.THIS_WEEK
PERIOD.LAST_WEEK
```

### 3.3 Recensement et remplacement des libellés

**Processus** :
1. **Scanner tout le code Flutter** (`lib/`) pour identifier CHAQUE chaîne de caractères affichée à l'écran (textes dans `Text()`, `title:`, `label:`, `hintText:`, `SnackBar`, `AppBar`, etc.).
2. Créer la clé correspondante selon la convention §3.2.
3. Remplacer la chaîne hardcodée par un appel à un service de traduction :
   ```dart
   // Avant :
   Text('Forme Récente')
   // Après :
   Text(t('SCREEN.HOME.LAST_MATCHES'))
   ```

**Service de traduction Flutter** :
- Créer `lib/core/config/translation_service.dart` :
  ```dart
  class TranslationService {
    static final TranslationService _instance = TranslationService._();
    factory TranslationService() => _instance;
    TranslationService._();
    
    Map<String, String> _translations = {};
    String _currentLanguage = 'fr-FR';
    
    String get currentLanguage => _currentLanguage;
    
    Future<void> loadTranslations(String languageCode, Map<String, String> translations) async {
      _currentLanguage = languageCode;
      _translations = translations;
      // Sauvegarder en local (Hive)
      await LocalStorage.put('app_settings', 'language_code', languageCode);
      await LocalStorage.put('app_settings', 'translations', translations);
    }
    
    Future<void> loadFromLocal() async {
      final code = await LocalStorage.get<String>('app_settings', 'language_code');
      final cached = await LocalStorage.get<Map>('app_settings', 'translations');
      if (code != null) _currentLanguage = code;
      if (cached != null) _translations = Map<String, String>.from(cached);
    }
    
    String translate(String key) {
      return _translations[key] ?? key;
    }
  }
  
  // Global shorthand
  String t(String key) => TranslationService().translate(key);
  ```

**API Backend** :
- `GET /api/v1/translations/:languageCode` → Retourne toutes les traductions pour une langue.
  ```json
  { "success": true, "data": { "COMMON.YES": "Oui", "COMMON.NO": "Non", ... } }
  ```
- `GET /api/v1/languages?available=true` → Retourne les langues disponibles.
  ```json
  {
    "success": true,
    "data": [
      { "code": "fr-FR", "country_name": "France", "language_name": "Français", "flag_emoji": "🇫🇷" },
      { "code": "en-US", "country_name": "United States", "language_name": "English", "flag_emoji": "🇺🇸" }
    ]
  }
  ```

### 3.4 Populer les traductions

**Script SQL** (`backend/sql/024_seed_translations.sql`) :
- Insérer TOUTES les clés listées § 3.2 avec leurs traductions en **français** (`fr-FR`) puis en **anglais** (`en-US`).
- Utiliser `INSERT ... ON CONFLICT DO NOTHING` pour être idempotent.

### 3.5 Choix de la langue — Écran d'inscription

**Fichier concerné** : `lib/features/auth/presentation/sso_username_screen.dart`

**Ajouter** en dessous du champ username :
1. Un titre de section « Choisir votre langue ».
2. Une liste de langues disponibles (`is_available = true`).
3. Chaque ligne affiche :
   - **Drapeau** (emoji ou image) — `flag_emoji`
   - **Nom du pays** — `country_name`
   - **Langue entre parenthèses** — `(language_name)`
   - Ex: `🇫🇷 France (Français)`
4. Sélection via RadioListTile ou un design similaire au reste de l'app.
5. Au tap, charger les traductions de cette langue depuis l'API et les stocker localement.
6. Langue par défaut à l'installation : **Français** (`fr-FR`).

### 3.6 Choix de la langue — Page paramètres

**Fichier concerné** : `lib/features/profile/presentation/settings_screen.dart`

**Ajouter** : une entrée « Langue / Language » dans les paramètres.
- Au tap, ouvrir un `BottomSheet` ou une page de sélection avec la même liste que §3.5.
- Au changement, recharger les traductions et rafraîchir l'interface (`setState` ou invalidation Riverpod).

### 3.7 Comportement du chargement des traductions

1. **Installation** : langue = `fr-FR` par défaut. Les traductions françaises sont **embarquées dans l'app** (fichier JSON asset) pour fonctionner hors ligne dès le premier lancement.
2. **Changement de langue** : appel API pour télécharger les traductions → stockage Hive local.
3. **Lancement suivant** : charger depuis le cache local (Hive). Pas d'appel API si cache existant.
4. **Rafraîchissement** : à chaque ouverture de l'app, tenter de mettre à jour les traductions en background (silent refresh).

---

## 📋 BLOC 4 — Mode multijoueur local (2 à 4 joueurs)

### 4.1 Configuration de partie — Saisie des noms

**Fichier concerné** : `lib/features/play/presentation/game_setup_screen.dart`

**Modification** :
- Sous les boutons `Inviter / Scan / Local`, lorsque l'option **Local** est sélectionnée :
  - Afficher des champs de saisie pour les noms des joueurs invités.
  - L'utilisateur connecté est toujours le Joueur 1 (pas de champ pour lui).
  - Jusqu'à **3 champs supplémentaires** pour les invités (Joueur 2, Joueur 3, Joueur 4).
  - Bouton « + Ajouter un joueur » pour ajouter un champ (max 3 invités = 4 joueurs total).
  - Bouton « ✕ » sur chaque champ pour retirer un joueur.
  - Au moins 1 adversaire requis pour lancer la partie.

**Mise à jour du MatchModel** :
- Le `MatchModel.players` supporte déjà une `List<PlayerMatch>`.
- Pour les joueurs locaux, créer des `PlayerMatch` avec un `id` fictif (ex: `'local_1'`, `'local_2'`) et le nom saisi.

### 4.2 Match X01 — Mode 3-4 joueurs

**Fichier concerné** : `lib/features/match/presentation/match_live_screen.dart`, `lib/features/match/widgets/scoreboard.dart`

**Changements UNIQUEMENT si plus de 2 joueurs** :
1. **Scoreboard** : afficher jusqu'à 4 tuiles de score sur la même ligne.
   - Chaque tuile est compactée : nom, score restant, et legs gagnés.
   - Supprimer l'espace du libellé `VS`.
   - Supprimer l'affichage des taux de double dans le scoreboard (pour gagner de la place).
2. **Tuile active** : mettre en surbrillance la tuile du joueur actif (`AppColors.primary` border).
3. **Saisie** : le système de tour fonctionne déjà en séquence (currentPlayerIndex). Adapter si nécessaire pour supporter 3-4 joueurs.

### 4.3 Match Cricket — Mode 3-4 joueurs

**Fichier concerné** : `lib/features/match/presentation/cricket_match_screen.dart`

**Changements UNIQUEMENT si plus de 2 joueurs** :
1. **Scoreboard** : afficher jusqu'à 4 colonnes de score en haut.
2. **Grille Cricket** : ajouter jusqu'à 2 colonnes supplémentaires pour les scores de chaque joueur (actuellement 2 colonnes joueur).
3. Les colonnes sont identifiées par le nom du joueur en en-tête.
4. La colonne du joueur actif a un fond légèrement plus clair.

### 4.4 Match Chasseur — Mode 3-4 joueurs

**Fichier concerné** : `lib/features/match/presentation/chasseur_match_screen.dart`, `lib/features/match/widgets/tempo_zone_input.dart`

**Changements UNIQUEMENT si plus de 2 joueurs** :
1. **Scoreboard** : afficher jusqu'à 4 tuiles de score en layout **2×2** (grille 2 colonnes × 2 lignes).
2. **Zones cibles** : corriger pour que **plusieurs joueurs puissent avoir la même zone cible**.
   - Actuellement, les zones des autres joueurs sont bloquées dans le `TempoZoneInput` quand ce n'est pas le chasseur. **Supprimer cette restriction**.
   - Chaque joueur (sauf le chasseur) choisit sa propre zone indépendamment.
3. **Tour chasseur** : le chasseur vise les zones des proies. Si une proie et le chasseur ont la même zone, c'est possible.

### 4.5 Cycle de tour pour 3-4 joueurs

**Dans tous les modes**, vérifier que :
- `currentPlayerIndex` parcourt bien `0, 1, 2, 3` (ou moins selon le nombre de joueurs).
- Le round s'incrémente après que TOUS les joueurs ont joué.
- La fin de leg/match détecte correctement le vainqueur parmi N joueurs.
- En Chasseur, le rôle de « chasseur » tourne correctement entre tous les joueurs.

---

## 📋 BLOC 5 — Lecture des fléchettes via caméra (Dart-Sense)

### 5.1 Analyse de Dart-Sense

**Projet de référence** : [github.com/YOLOv8-dart-detection](https://github.com/) — modèle de détection de fléchettes basé sur YOLOv8/YOLOv5 (ou équivalent « Dart-Sense »).

**Architecture recommandée** : **Service Docker séparé sur le VPS** (pas embarqué dans l'app).

**Justification** :
- Le modèle YOLOv8 est trop lourd pour un appareil mobile (>100 MB, latence élevée).
- Un service Docker centralisé permet de contrôler la version du modèle, le GPU si disponible, et de faire évoluer le système.
- L'app Flutter envoie une photo → le serveur analyse → retourne les coordonnées/scores détectés.

### 5.2 Architecture du service Dart-Sense

```
dart-sense-service/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt         # ultralytics, fastapi, uvicorn, opencv-python
├── app/
│   ├── main.py              # FastAPI app
│   ├── detector.py          # Classe de détection dartboard + darts
│   ├── scorer.py            # Convertisseur position → score (zone, multiplier)
│   └── models/
│       └── dart_sense.pt    # Poids du modèle entraîné
└── README.md
```

**API du service** :
- `POST /detect` — Reçoit une image (multipart/form-data), retourne les fléchettes détectées :
  ```json
  {
    "success": true,
    "darts": [
      { "zone": 20, "multiplier": 3, "confidence": 0.92, "x": 0.45, "y": 0.32 },
      { "zone": 18, "multiplier": 1, "confidence": 0.87, "x": 0.61, "y": 0.55 }
    ]
  }
  ```

**Docker Compose** (à ajouter dans le VPS) :
```yaml
version: '3.8'
services:
  dart-sense:
    build: ./dart-sense-service
    ports:
      - "8001:8000"
    restart: unless-stopped
    environment:
      - MODEL_PATH=/app/models/dart_sense.pt
    volumes:
      - ./dart-sense-service/app/models:/app/models
```

**Intégration Nginx** : Ajouter un reverse proxy :
```nginx
location /api/dart-sense/ {
    proxy_pass http://localhost:8001/;
    client_max_body_size 10M;
}
```

### 5.3 Intégration Flutter

**Fichier à créer** : `lib/core/network/dart_sense_service.dart`

```dart
class DartSenseService {
  final Dio _dio;
  
  DartSenseService(this._dio);
  
  Future<List<DetectedDart>> detect(File imageFile) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await _dio.post('/api/dart-sense/detect', data: formData);
    final data = response.data['darts'] as List;
    return data.map((d) => DetectedDart.fromJson(d)).toList();
  }
}

class DetectedDart {
  final int zone;
  final int multiplier;
  final double confidence;
  final double x;
  final double y;
  // ...
}
```

### 5.4 Page de test Dart-Sense dans les réglages

**Fichier concerné** : `lib/features/profile/presentation/settings_screen.dart`

**Ajouter** un bouton « Dart Sense (Beta) » dans les paramètres :
1. Au tap, ouvrir la caméra (`ImagePicker` ou `camera` package).
2. L'utilisateur prend une photo de la cible avec les fléchettes.
3. Envoyer l'image au service Dart-Sense.
4. En attente : afficher un loader.
5. Quand le résultat arrive :
   - Afficher une **modale de confirmation** avec :
     - L'image prise
     - Les fléchettes détectées superposées sur l'image (overlay)
     - La valeur de chaque fléchette (ex: « T20 », « S18 », « D16 »)
     - Le total
     - Bouton « Confirmer » / « Reprendre la photo »
6. Si aucune fléchette détectée, afficher un message d'erreur.

### 5.5 Étapes de mise en place

1. **Cloner/adapter Dart-Sense** sur le VPS dans un répertoire dédié.
2. **Entraîner/télécharger** le modèle pré-entraîné `.pt`.
3. **Builder le Docker** : `docker-compose up -d --build`.
4. **Configurer Nginx** pour le reverse proxy.
5. **Tester l'API** avec `curl` :
   ```bash
   curl -X POST -F "image=@test_dartboard.jpg" https://dart-district.fr/api/dart-sense/detect
   ```
6. **Intégrer dans Flutter** via le `DartSenseService`.
7. **Ajouter le bouton** dans les settings.

---

## 📋 BLOC 6 — Résumé des fichiers à créer/modifier

### Nouvelles migrations SQL (backend/sql/)
| Fichier | Contenu |
|---------|---------|
| `022_user_conquest_score.sql` | `ALTER TABLE users ADD COLUMN conquest_score` |
| `023_internationalization.sql` | Tables `languages`, `translations`, colonne `preferred_language` |
| `024_seed_translations.sql` | INSERT de toutes les traductions FR + EN |
| `025_elo_history.sql` | Table `elo_history` pour le graphique ELO |

### Nouveaux fichiers Flutter (lib/)
| Fichier | Contenu |
|---------|---------|
| `core/config/translation_service.dart` | Singleton de traduction i18n |
| `core/network/dart_sense_service.dart` | Client API Dart-Sense |

### Fichiers Flutter à modifier
| Fichier | Modifications |
|---------|--------------|
| `features/map/presentation/map_screen.dart` | Couleurs des tiles par statut |
| `features/match/widgets/dartboard_input_stats.dart` | Couleurs heatmap + fond transparent |
| `features/profile/widgets/elo_chart.dart` | Refonte complète (modes semaine/mois/année, swipe, courbes lissées) |
| `features/profile/presentation/profile_screen.dart` | Nouveau layout tuiles, réorganisation sections, ajout historique |
| `features/profile/presentation/settings_screen.dart` | Ajout choix langue + bouton Dart Sense |
| `features/profile/data/profile_service.dart` | Nouvel endpoint elo-history |
| `features/profile/controller/profile_controller.dart` | State pour elo-history |
| `features/auth/models/user_model.dart` | Ajout `conquestScore` |
| `features/home/presentation/home_screen.dart` | Réorganisation sections, conquête, conditionnel tournois |
| `features/club/widgets/member_list_tile.dart` | Points conquête au lieu de bouton jouer |
| `features/club/models/club_model.dart` | Ajout `conquestScore` sur `ClubMember` |
| `features/play/presentation/game_setup_screen.dart` | Champs noms locaux (3-4 joueurs) |
| `features/play/presentation/match_invite_player_screen.dart` | Recherche globale joueurs |
| `features/match/presentation/match_live_screen.dart` | Support 3-4 joueurs X01 |
| `features/match/presentation/cricket_match_screen.dart` | Support 3-4 joueurs Cricket |
| `features/match/presentation/chasseur_match_screen.dart` | Support 3-4 joueurs + fix zones |
| `features/match/widgets/scoreboard.dart` | Layout adaptatif 2-4 joueurs |
| `features/match/widgets/tempo_zone_input.dart` | Débloquer zones partagées |
| `features/match/widgets/match_end_modal.dart` | Condition masterOut pour finish attempts |
| `features/match/controller/match_controller.dart` | Validation masterOut, cycle N joueurs |
| `features/match/controller/cricket_match_controller.dart` | Cycle N joueurs |
| `features/match/controller/chasseur_match_controller.dart` | Cycle N joueurs, zones partagées |
| `features/auth/presentation/sso_username_screen.dart` | Section choix langue |
| `shared/widgets/match_history_list.dart` | Vérifier généricité |
| `android/app/src/main/AndroidManifest.xml` | Label → `Dart District` |

### Nouveaux fichiers Docker (VPS)
| Fichier | Contenu |
|---------|---------|
| `dart-sense-service/Dockerfile` | Service Python FastAPI + YOLOv8 |
| `dart-sense-service/docker-compose.yml` | Orchestration du service |
| `dart-sense-service/app/main.py` | Endpoints FastAPI |
| `dart-sense-service/app/detector.py` | Logique de détection |
| `dart-sense-service/app/scorer.py` | Conversion position → score |

### Nouveaux endpoints backend NestJS
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/v1/users/:id/elo-history?mode=week\|month\|year&offset=0` | Historique ELO par période |
| GET | `/api/v1/users/search?q=<query>&limit=20` | Recherche globale de joueurs |
| GET | `/api/v1/translations/:languageCode` | Toutes les traductions d'une langue |
| GET | `/api/v1/languages?available=true` | Langues disponibles |

---

## ⚠️ Règles impératives pour l'implémentation

1. **Ne jamais casser ce qui fonctionne** — Chaque modification doit être rétrocompatible. Les matchs 1v1 existants ne doivent pas être affectés par le support 3-4 joueurs.
2. **Feature flags** — Les nouvelles fonctionnalités volumineuses (Dart-Sense, i18n) peuvent être gardées derrière un flag si nécessaire.
3. **Tests** — Ajouter des tests unitaires pour :
   - La validation masterOut
   - Le calcul des points de conquête (cas même club vs clubs différents)
   - Le service de traduction
   - Le cycle de tour pour N joueurs
4. **Migrations SQL** — Toujours idempotentes (`IF NOT EXISTS`, `ON CONFLICT DO NOTHING`).
5. **Sécurité** — Sanitizer les inputs utilisateur (recherche joueur, noms locaux). JWT sur tous les nouveaux endpoints.
6. **Performance** — Le chargement des traductions doit être en cache local. L'appel API est uniquement au changement de langue.
7. **Pas de logique métier dans les widgets** — Utiliser les controllers/services Riverpod.
8. **Conventions de nommage** — snake_case fichiers, PascalCase classes, camelCase variables.
9. **Incrementation version** — À la fin du sprint, incrémenter la version dans `pubspec.yaml` et ajouter l'entrée correspondante dans `patch_notes.dart`.

---

## 📌 Ordre de développement recommandé

1. ✅ Migrations SQL (022→025)
2. ✅ Backend endpoints (elo-history, user search, translations, languages)
3. ✅ Corrections UI simples (heatmap colors, app name, home reorder)
4. ✅ Verification masterOut + tournois territoriaux
5. ✅ Refonte profil (tuiles, ELO chart, historique)
6. ✅ Map — couleurs des territoires
7. ✅ Score de conquête (user model, member list, home)
8. ✅ Recherche joueurs invitation
9. ✅ Internationalisation (service, tables, seed, UI)
10. ✅ Mode multijoueur local (setup, X01, Cricket, Chasseur)
11. ✅ Dart-Sense (Docker, API, intégration settings)
