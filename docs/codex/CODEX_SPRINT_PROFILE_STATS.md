# CODEX SPRINT — Profil, Stats, Badges, Social Feed

> **Projet** : Dart District (Flutter + NestJS/TypeORM/PostgreSQL)
> **Objectif** : Corriger le calcul des stats utilisateur en fin de match classé, les afficher correctement sur la page profil, enrichir les badges, ajuster l'ELO/dartboard/historique et brancher le social feed sur l'icône cloche.

---

## Table des matières

1. [Contexte technique](#1-contexte-technique)
2. [Tâche 1 — Calcul des stats en fin de match classé](#2-tâche-1--calcul-des-stats-en-fin-de-match-classé)
3. [Tâche 2 — Affichage correct des stats sur le profil](#3-tâche-2--affichage-correct-des-stats-sur-le-profil)
4. [Tâche 3 — Progression ELO : refresh et style](#4-tâche-3--progression-elo--refresh-et-style)
5. [Tâche 4 — Dartboard Précision : couleurs des zones](#5-tâche-4--dartboard-précision--couleurs-des-zones)
6. [Tâche 5 — Historique des 5 derniers matchs](#6-tâche-5--historique-des-5-derniers-matchs)
7. [Tâche 6 — Badges (10+ badges, niveaux de difficulté, grisés si non obtenus)](#7-tâche-6--badges)
8. [Tâche 7 — Social Feed sur icône cloche](#8-tâche-7--social-feed-sur-icône-cloche)
9. [Conventions & règles](#9-conventions--règles)
10. [Arborescence des fichiers impactés](#10-arborescence-des-fichiers-impactés)

---

## 1. Contexte technique

### Stack

| Couche | Technologie |
|--------|------------|
| Mobile | Flutter 3.x, Dart, Riverpod (StateNotifier), GoRouter |
| Backend | NestJS, TypeORM, PostgreSQL |
| Theme | Dark mode — `AppColors` (primary=#C8FF00, secondary=#6A6FFF, background=#060A14, card=#161F33, stroke=#2A3350) |
| Animations | `TweenAnimationBuilder`, staggered `_ProfileReveal` |
| Charts | `fl_chart` (LineChart pour ELO) |
| Fonts | `google_fonts` (Manrope) |

### Architecture Flutter

```
lib/
├── core/
│   ├── config/
│   │   ├── app_colors.dart          # Thème couleurs
│   │   ├── app_routes.dart          # GoRouter routes
│   │   └── translation_service.dart # i18n via t()
│   └── network/
│       └── api_providers.dart       # apiClientProvider (Dio)
├── features/
│   ├── auth/
│   │   ├── controller/auth_controller.dart  # currentUserProvider
│   │   └── models/user_model.dart           # UserModel + PlayerStats
│   ├── match/
│   │   ├── controller/match_controller.dart
│   │   └── widgets/dartboard_input_stats.dart  # Dartboard heatmap painter
│   ├── profile/
│   │   ├── controller/profile_controller.dart  # ProfileController, AchievementBadge
│   │   ├── data/profile_service.dart           # API calls profil
│   │   ├── presentation/
│   │   │   ├── profile_screen.dart             # Écran profil principal
│   │   │   └── badges_screen.dart              # Écran badges complet
│   │   └── widgets/
│   │       ├── elo_chart.dart                  # Graphe ELO
│   │       ├── precision_section.dart          # Dartboard précision heatmap
│   │       ├── badge_grid.dart                 # Grille badges
│   │       └── match_history_tile.dart         # Tuile historique match
│   ├── social/
│   │   ├── presentation/social_feed_screen.dart
│   │   └── controller/social_feed_controller.dart
│   └── notifications/
│       ├── controller/notifications_controller.dart
│       └── presentation/notifications_screen.dart
└── shared/
    ├── models/
    │   ├── match_history_summary.dart
    │   └── dartboard_heatmap_models.dart
    └── widgets/
        ├── app_scaffold.dart        # Shell scaffold (bottom nav + header + cloche)
        ├── match_history_list.dart
        └── player_avatar.dart
```

### Architecture Backend

```
backend/src/modules/
├── matches/
│   └── matches.service.ts     # submitScore, completeLeg, checkMatchCompletion, getMatchReport
├── stats/
│   ├── stats.service.ts       # updateAfterMatch, processElo, processTerritoryPoints
│   └── entities/
│       └── player-stat.entity.ts  # PlayerStat entity (TypeORM)
└── users/
    └── users.service.ts
```

### Schéma SQL pertinent

```sql
-- Table player_stats
CREATE TABLE player_stats (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    matches_played    INTEGER NOT NULL DEFAULT 0,
    matches_won       INTEGER NOT NULL DEFAULT 0,
    avg_score         NUMERIC(6,2) NOT NULL DEFAULT 0,
    best_avg          NUMERIC(6,2) NOT NULL DEFAULT 0,
    checkout_rate     NUMERIC(5,2) NOT NULL DEFAULT 0,
    total_180s        INTEGER NOT NULL DEFAULT 0,
    high_finish       INTEGER NOT NULL DEFAULT 0,
    best_leg_darts    INTEGER NOT NULL DEFAULT 0,
    precision_t20     NUMERIC(5,2) NOT NULL DEFAULT 0,
    precision_t19     NUMERIC(5,2) NOT NULL DEFAULT 0,
    precision_double  NUMERIC(5,2) NOT NULL DEFAULT 0,
    count_140_plus    INT DEFAULT 0,
    count_100_plus    INT DEFAULT 0,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Table badges + user_badges
CREATE TABLE badges (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(50) UNIQUE NOT NULL,
    name        VARCHAR(100) NOT NULL,
    description TEXT,
    image_asset VARCHAR(200) NOT NULL,
    category    VARCHAR(50) DEFAULT 'general',
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE user_badges (
    id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, badge_id)
);

-- Table elo_history
CREATE TABLE elo_history (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id),
    match_id   UUID,
    elo_before INTEGER NOT NULL,
    elo_after  INTEGER NOT NULL,
    delta      INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
```

---

## 2. Tâche 1 — Calcul des stats en fin de match classé

### Problème actuel

La méthode `updateAfterMatch()` existe dans `backend/src/modules/stats/stats.service.ts` mais **n'est jamais appelée** dans le flux de fin de match. Seuls `processElo()` et `processTerritoryPoints()` sont appelés dans `checkMatchCompletion()`.

### Ce qu'il faut faire

#### 2.1 Backend — `matches.service.ts`

Dans la méthode `checkMatchCompletion()`, **après** les appels `processElo()` et `processTerritoryPoints()`, ajouter l'appel à `updateAfterMatch()` pour **les deux joueurs** (gagnant ET perdant).

```typescript
// Dans checkMatchCompletion(), après processTerritoryPoints :

if (match.is_ranked) {
  // Agréger les stats pour chaque joueur
  for (const mp of match.players) {
    const playerId = mp.user.id;
    const isWinner = mp.is_winner;

    // Récupérer tous les throws du joueur dans ce match
    const allThrows = []; // Agréger depuis tous les legs de tous les sets
    for (const set of match.sets) {
      for (const leg of set.legs) {
        const legThrows = leg.throws.filter(t => t.user_id === playerId);
        allThrows.push(...legThrows);
      }
    }

    const totalScore = allThrows.reduce((sum, t) => sum + t.score, 0);
    const throwCount = allThrows.length;
    const avg = throwCount > 0 ? totalScore / throwCount : 0;

    // Highest checkout (score du throw marqué is_checkout)
    const highCheckout = allThrows
      .filter(t => t.is_checkout)
      .reduce((max, t) => Math.max(max, t.score), 0);

    const count180s = allThrows.filter(t => t.score === 180).length;
    const count140Plus = allThrows.filter(t => t.score >= 140).length;
    const count100Plus = allThrows.filter(t => t.score >= 100).length;

    // Checkout attempts et hits
    const checkoutHits = allThrows.filter(t => t.is_checkout).length;
    // checkoutAttempts = nombre de throws sur des segments double en fin de leg
    // Utiliser la même logique que getMatchReport() si elle existe
    const checkoutAttempts = allThrows
      .filter(t => this.isDoubleAttempt(t))
      .length;

    // Precision T20, T19, Double
    const t20Throws = allThrows.filter(t => this.isT20Attempt(t));
    const t19Throws = allThrows.filter(t => this.isT19Attempt(t));
    const doubleThrows = allThrows.filter(t => this.isDoubleZone(t));

    await this.statsService.updateAfterMatch(playerId, {
      avg: avg * 3, // Conversion en moyenne pour 3 fléchettes (avg_score = 3-dart avg)
      highCheckout,
      count180s,
      count140Plus,
      count100Plus,
      checkoutHits,
      checkoutAttempts,
      t20Hits: t20Throws.filter(t => t.hit_target).length,
      t20Attempts: t20Throws.length,
      t19Hits: t19Throws.filter(t => t.hit_target).length,
      t19Attempts: t19Throws.length,
      doubleHits: doubleThrows.filter(t => t.hit_target).length,
      doubleAttempts: doubleThrows.length,
      won: isWinner,
    });
  }
}
```

#### Points d'attention

- **Moyenne 3-dart** : `avg_score` dans `player_stats` est la moyenne pour 3 fléchettes. Si les throws sont stockés individuellement (1 throw = 3 darts = 1 score), alors `avg = totalScore / throwCount` est déjà la 3-dart avg. **Vérifier** la granularité des throws dans la table `throws`.
- **`high_finish`** : C'est le plus haut score de checkout (finish d'un leg en double-out). Le throw est marqué `is_checkout = true` quand le joueur finit le leg. La valeur est le score de ce throw.
- **`best_leg_darts`** : (Optionnel pour ce sprint) Nombre minimum de fléchettes pour finir un leg. Nécessite de compter les throws par leg et garder le minimum. Ajouter dans `updateAfterMatch()` :
  ```typescript
  if (matchData.bestLegDarts && matchData.bestLegDarts < stat.best_leg_darts) {
    stat.best_leg_darts = matchData.bestLegDarts;
  }
  ```
- Ne modifier les stats que pour les matchs `is_ranked === true`.
- L'appel doit se faire **après** `processElo` car `matches_played` est incrémenté dans `updateAfterMatch`.

---

## 3. Tâche 2 — Affichage correct des stats sur le profil

### Problème actuel

1. Le modèle Flutter `PlayerStats` **ne contient pas** `high_finish` ni `best_leg_darts`.
2. La tuile `SCREEN.PROFILE.HIGHEST_SCORE` affiche actuellement `count140Plus + count100Plus` (un total de compteurs), au lieu du **plus haut score de finish**.

### Ce qu'il faut faire

#### 3.1 Flutter — `lib/features/auth/models/user_model.dart`

Ajouter les champs manquants dans `PlayerStats` :

```dart
class PlayerStats {
  final int matchesPlayed;
  final int matchesWon;
  final double averageScore;
  final double checkoutRate;
  final int highest180s;       // maps to total_180s
  final int count140Plus;
  final int count100Plus;
  final double bestAverage;    // maps to best_avg
  final int highFinish;        // NOUVEAU — maps to high_finish
  final int bestLegDarts;      // NOUVEAU — maps to best_leg_darts

  // ... constructeur avec highFinish = 0, bestLegDarts = 0

  factory PlayerStats.fromApi(Map<String, dynamic> json) {
    return PlayerStats(
      // ... champs existants ...
      highFinish: _toInt(json['high_finish']),
      bestLegDarts: _toInt(json['best_leg_darts']),
    );
  }

  double get winRate =>
      matchesPlayed > 0 ? (matchesWon / matchesPlayed) * 100 : 0;
}
```

#### 3.2 Flutter — `lib/features/profile/presentation/profile_screen.dart`

Corriger chaque tuile de stats pour afficher la bonne valeur :

| Clé i18n | Valeur à afficher | Explication |
|----------|-------------------|-------------|
| `SCREEN.PROFILE.MATCHES` | `user.stats.matchesPlayed` | Nombre de matchs classés joués |
| `SCREEN.PROFILE.WINS` | `user.stats.winRate.toStringAsFixed(0)%` | Pourcentage de victoires |
| `SCREEN.PROFILE.AVERAGE` | `user.stats.averageScore.toStringAsFixed(1)` | Moyenne 3-dart sur tous les matchs classés |
| `SCREEN.PROFILE.CHECKOUT` | `user.stats.checkoutRate.toStringAsFixed(1)%` | % de doubles réussis (nb finish legs / nb doubles tentés) |
| `SCREEN.PROFILE.BEST_AVG` | `user.stats.bestAverage.toStringAsFixed(1)` | Meilleure moyenne 3-dart sur un match classé |
| `SCREEN.PROFILE.SHOTS_180` | `user.stats.highest180s` | Nombre total de 180 en classé |
| `SCREEN.PROFILE.HIGHEST_SCORE` | `user.stats.highFinish` | **Score de finish le plus haut** en classé |

**Correction critique** sur la tuile `HIGHEST_SCORE` — remplacer :

```dart
// AVANT (FAUX) :
'${(user?.stats.count140Plus ?? 0) + (user?.stats.count100Plus ?? 0)}'

// APRÈS (CORRECT) :
'${user?.stats.highFinish ?? 0}'
```

#### 3.3 Supprimer les calculs estimés inutiles

Dans le `build()` de `_ProfileScreenState`, les variables `est501`, `est301`, `estCricket` sont des estimations fictives. Si aucune donnée réelle par format n'existe en base, conserver tels quels ou supprimer la section "Performance par format" si elle n'est pas alimentée.

---

## 4. Tâche 3 — Progression ELO : refresh et style

### Ce qu'il faut faire

#### 4.1 Actualiser le composant ELO à l'affichage du profil

Le `ProfileController._loadProfile()` charge déjà les données ELO via `/stats/me/elo-history`. **Vérifier** que l'endpoint backend retourne bien les données au format attendu :

```json
{
  "data": {
    "points": [
      { "date": "2026-04-05", "elo": 1024 },
      { "date": "2026-04-06", "elo": 1032 }
    ],
    "period_label": "7 avr – 13 avr 2026"
  }
}
```

Si le graphe ELO est vide alors qu'il devrait avoir des données, vérifier :
- Que `processElo()` crée bien des entrées dans `elo_history` à chaque match classé.
- Que l'endpoint agrège correctement par période (week/month/year).

#### 4.2 Ajuster le style des boutons ELO au thème de l'app

Fichier : `lib/features/profile/widgets/elo_chart.dart`

Le `SegmentedButton` et les `IconButton` de navigation de période doivent être stylés avec le thème `AppColors` :

```dart
SegmentedButton<EloPeriodMode>(
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary.withValues(alpha: 0.15);
      }
      return AppColors.card;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primary;
      }
      return AppColors.textSecondary;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const BorderSide(color: AppColors.primary);
      }
      return const BorderSide(color: AppColors.stroke);
    }),
    shape: WidgetStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  // ...
)
```

Les `IconButton` de navigation (chevron left/right) :

```dart
IconButton(
  style: IconButton.styleFrom(
    backgroundColor: AppColors.card,
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.stroke),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
  // ...
)
```

---

## 5. Tâche 4 — Dartboard Précision : couleurs des zones

### Problème actuel

La légende du heatmap (`_HeatLegend`) affiche un gradient :
```
Faible [AppColors.info → #F59A4A → #FF8C00 → AppColors.error] Forte
```

Mais la méthode `_heatColor(double t)` dans `_DartboardHeatmapPainter` utilise ces mêmes stops :
- `t < 0.34` : `AppColors.info` → `#F59A4A`
- `t < 0.68` : `#F59A4A` → `#FF8C00`
- `t >= 0.68` : `#FF8C00` → `AppColors.error`

### Ce qu'il faut vérifier

Les valeurs de `AppColors.info` et `AppColors.error` dans `app_colors.dart`. Si elles ne correspondent pas visuellement à la légende (par ex. si `info` est un bleu et que la légende montre un vert, ou si les stops sont décalés), **aligner les couleurs** :

- Vérifier que `AppColors.info` est bien la couleur "froid/faible" de la légende.
- Vérifier que `AppColors.error` est bien la couleur "chaud/forte" de la légende.

**Si les couleurs ne matchent pas**, modifier la légende OU le painter pour qu'ils soient identiques. Les deux doivent utiliser exactement les mêmes constantes de couleur dans le même ordre.

Fichiers à modifier :
- `lib/features/match/widgets/dartboard_input_stats.dart` — `_HeatLegend` et `_heatColor()`

---

## 6. Tâche 5 — Historique des 5 derniers matchs

### Problème actuel

Le `ProfileController._loadProfile()` charge les 20 derniers matchs. Le profil utilise `profileState.matchHistory.take(5).toList()` dans la variable `recentMatches`, et la section historique est rendue avec `MatchHistoryList(matches: recentMatches, ...)`.

### Ce qu'il faut vérifier

1. Que le composant `MatchHistoryList` reçoit bien les 5 matchs.
2. Que la variable `recentMatches` est bien utilisée dans le `build()`.
3. Que les matchs affichés sont bien les matchs **classés** (`is_ranked = true`). Si ce n'est pas le cas, filtrer côté backend avec le paramètre `ranked=true` dans la requête `/matches/me`.

### Vérifier la requête backend

L'endpoint `/matches/me` accepte-t-il un paramètre `ranked` ? Si oui, ajouter :

```dart
// Dans profile_controller.dart, _loadProfile()
final matchesResponse = await api.get<Map<String, dynamic>>(
  '/matches/me',
  queryParameters: const {
    'limit': '5',        // Limiter à 5
    'status': 'completed',
    'ranked': 'true',    // Seulement les classés
  },
);
```

Si le paramètre `ranked` n'existe pas dans le backend, **l'ajouter** dans `matches.service.ts` → `findByUser()`.

---

## 7. Tâche 6 — Badges

### État actuel

- 14 badges sont définis en dur dans `ProfileController._buildBadges()`.
- Les badges sont affichés dans `BadgeGrid` (grille 3 colonnes, opacité réduite si non obtenus).
- `BadgesScreen` affiche tous les badges avec `Opacity(opacity: badge.unlocked ? 1 : 0.3)`.
- Les badges utilisent des **emojis** comme icônes.

### Ce qu'il faut faire

#### 7.1 Enrichir à 10+ badges avec niveaux de difficulté variés

Voici la liste de badges à implémenter (remplacer/enrichir la liste existante) :

| # | key | name | description | icon | difficulty | condition |
|---|-----|------|-------------|------|------------|-----------|
| 1 | `rookie_first_match` | Premier Match | Jouer son premier match classé | 🎯 | Bronze | matchesPlayed > 0 |
| 2 | `grinder_10` | Série 10 | Jouer 10 matchs classés | 🧱 | Bronze | matchesPlayed >= 10 |
| 3 | `centurion` | Centurion | Jouer 100 matchs classés | 🏛️ | Or | matchesPlayed >= 100 |
| 4 | `first_win` | Première Victoire | Gagner son premier match classé | 🥇 | Bronze | matchesWon >= 1 |
| 5 | `win_machine` | Machine à Gagner | Atteindre 50 victoires | 🏆 | Or | matchesWon >= 50 |
| 6 | `first_180` | 180 ! | Réaliser un 180 en classé | 🔥 | Argent | total180s > 0 |
| 7 | `triple_thunder` | Triple Foudre | Réaliser 3 fois 180 | ⚡ | Or | total180s >= 3 |
| 8 | `ton_80_master` | Ton-80 Master | Réaliser 10 fois 180 | 💫 | Diamant | total180s >= 10 |
| 9 | `factory_140` | 140+ Factory | Faire 25 scores à 140+ | 💥 | Argent | count140Plus >= 25 |
| 10 | `checkout_sniper` | Sniper Checkout | Atteindre 40% de checkout | 🎯 | Argent | checkoutRate >= 40 |
| 11 | `checkout_master` | Checkout Master | Atteindre 60% de checkout | 💎 | Diamant | checkoutRate >= 60 |
| 12 | `high_finish_100` | Big Fish | Réaliser un finish de 100+ | 🐟 | Argent | highFinish >= 100 |
| 13 | `high_finish_150` | Finisseur Élite | Réaliser un finish de 150+ | 🦈 | Or | highFinish >= 150 |
| 14 | `avg_75` | Le Mur des 75 | Signer une meilleure moyenne à 75+ | 🗿 | Légende | bestAvg >= 75 |
| 15 | `streak_3_days` | Régulier | Jouer 3 jours d'affilée | 📅 | Bronze | Tracking backend (voir ci-dessous) |
| 16 | `territory_warlord` | Conquérant IRIS | Faire gagner une zone à son club | 🗺️ | Légende | Backend-awarded |
| 17 | `tournament_king` | Roi du Tournoi | Remporter un tournoi officiel | 👑 | Légende | Backend-awarded |

#### 7.2 Badge "Régulier" (streak 3 jours)

Ce badge nécessite un tracking côté backend. Options :
- **Option A** (simple) : Ajouter un champ `consecutive_days_played` et `last_played_date` dans `player_stats`. À chaque match, si `last_played_date` est hier, incrémenter le compteur. Si c'est aujourd'hui, ne rien faire. Sinon, reset à 1.
- **Option B** : Le calculer dynamiquement depuis `matches.created_at` en comptant les jours consécutifs. Plus coûteux en query.

Implémenter l'option A dans `updateAfterMatch()` :

```typescript
const today = new Date().toISOString().slice(0, 10);
const lastPlayed = stat.last_played_date?.toISOString().slice(0, 10);

if (lastPlayed === today) {
  // Déjà joué aujourd'hui, ne rien changer
} else {
  const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
  if (lastPlayed === yesterday) {
    stat.consecutive_days_played += 1;
  } else {
    stat.consecutive_days_played = 1;
  }
  stat.last_played_date = new Date();
}
```

**SQL migration** :
```sql
ALTER TABLE player_stats
  ADD COLUMN IF NOT EXISTS consecutive_days_played INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_played_date DATE;
```

#### 7.3 Affichage des badges grisés

Fichier : `lib/features/profile/presentation/badges_screen.dart`

Le badge non obtenu doit être :
- En opacité 0.3 (✅ déjà fait).
- Ajouter une icône de cadenas centré en overlay sur l'icône du badge.
- Ajouter un filtre grayscale (optionnel via `ColorFiltered` + `ColorFilter.mode(Colors.grey, BlendMode.saturation)`).

```dart
Stack(
  alignment: Alignment.center,
  children: [
    ColorFiltered(
      colorFilter: badge.unlocked
          ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
          : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
      child: Text(badge.icon, style: const TextStyle(fontSize: 32)),
    ),
    if (!badge.unlocked)
      Icon(Icons.lock_outline, size: 18, color: AppColors.textHint.withValues(alpha: 0.7)),
  ],
)
```

#### 7.4 Images/icônes des badges

Les badges utilisent des emojis dans le champ `icon`. Pour une meilleure expérience :
- Conserver les emojis en tant que fallback.
- Si un `image_asset` est renseigné dans la table `badges`, l'utiliser en priorité (via `Image.asset` ou `Image.network`).
- Le `AchievementBadge` model a déjà un champ `icon` (String). On peut y mettre un emoji ou un chemin d'asset.

---

## 8. Tâche 7 — Social Feed sur icône cloche

### État actuel

L'icône cloche (notifications) dans `app_scaffold.dart` navigue actuellement vers `AppRoutes.socialFeed` via `GoRouter.of(context).go(AppRoutes.socialFeed)`.

### Ce qu'il faut faire

Confirmer que :
1. L'icône cloche dans le header de `AppScaffold` pointe vers le Social Feed (`/social-feed`).
2. Le `SocialFeedScreen` affiche bien le fil d'activité des amis.
3. Le `SocialFeedScreen` a un bouton de navigation vers les notifications — c'est déjà le cas via l'`IconButton` dans l'`AppBar.actions`.

**Vérifier** que la route `AppRoutes.socialFeed` (`/social-feed`) est bien enregistrée dans GoRouter sous `_rootNavigatorKey`. C'est déjà le cas d'après le code existant.

**Si le bouton ne fonctionne pas** (navigation ne se fait pas) :
- Le problème était que `context.push()` ne fonctionnait pas depuis le ShellRoute. La correction `GoRouter.of(context).go()` a été appliquée.
- **Valider** que ça fonctionne en test.

---

## 9. Conventions & règles

### Règles de code Flutter

- Utiliser `AppColors` pour toutes les couleurs (pas de couleurs en dur sauf noir/blanc).
- Utiliser `t('KEY', fallback: 'texte')` pour tout texte affiché.
- Utiliser `GoogleFonts.manrope()` pour les textes stylés.
- Riverpod : `StateNotifier` + `StateNotifierProvider`.
- Navigation : `GoRouter` — `context.push()` pour empiler, `context.go()` pour remplacer.
- Les écrans sont des `ConsumerWidget` ou `ConsumerStatefulWidget`.
- Pas de `print()` en production — utiliser `debugPrint()` si nécessaire.
- Formater avec `dart format` avant commit.
- Analyser avec `flutter analyze lib` — 0 erreurs/warnings.

### Règles de code Backend

- TypeORM avec entities — pas de raw SQL dans le service.
- Les endpoints retournent `{ data: ... }` wrapper.
- Les migrations SQL sont numérotées : `027_xxx.sql`, `028_xxx.sql`, etc.
- Pas de `console.log` en production.
- Les calculs de stats utilisent une moyenne pondérée (`weightedRate()`).

### Test

- Après chaque modification, exécuter `flutter analyze lib` pour vérifier 0 erreurs.
- Tester le flux complet : créer un match classé → jouer → finir → vérifier que les stats du profil sont mises à jour.
- Tester l'affichage profil avec un utilisateur ayant 0 matchs (valeurs par défaut).

---

## 10. Arborescence des fichiers impactés

```
backend/
├── sql/
│   └── 027_streak_tracking.sql        # NOUVEAU — migration pour streak badges
├── src/modules/
│   ├── matches/
│   │   └── matches.service.ts         # MODIFIER — ajouter appel updateAfterMatch
│   └── stats/
│       ├── stats.service.ts           # MODIFIER — ajouter best_leg_darts + streak logic
│       └── entities/
│           └── player-stat.entity.ts  # MODIFIER — ajouter consecutive_days_played, last_played_date

lib/
├── features/
│   ├── auth/models/
│   │   └── user_model.dart            # MODIFIER — ajouter highFinish, bestLegDarts dans PlayerStats
│   ├── profile/
│   │   ├── controller/
│   │   │   └── profile_controller.dart # MODIFIER — mettre à jour _buildBadges avec nouveaux badges
│   │   ├── presentation/
│   │   │   ├── profile_screen.dart     # MODIFIER — corriger HIGHEST_SCORE, vérifier affichage stats
│   │   │   └── badges_screen.dart      # MODIFIER — grayscale + lock overlay pour badges non obtenus
│   │   └── widgets/
│   │       ├── elo_chart.dart          # MODIFIER — style boutons SegmentedButton + IconButton
│   │       └── badge_grid.dart         # MODIFIER — grayscale + lock overlay
│   └── match/widgets/
│       └── dartboard_input_stats.dart  # VÉRIFIER — aligner couleurs légende ↔ painter
└── shared/widgets/
    └── app_scaffold.dart               # VÉRIFIER — navigation cloche → social feed
```

---

## Résumé des livrables

| # | Tâche | Priorité | Fichiers |
|---|-------|----------|----------|
| 1 | Appeler `updateAfterMatch()` en fin de match classé | 🔴 Critical | `matches.service.ts` |
| 2 | Ajouter `highFinish` + `bestLegDarts` dans Flutter `PlayerStats` | 🔴 Critical | `user_model.dart` |
| 3 | Corriger `HIGHEST_SCORE` → `highFinish` | 🔴 Critical | `profile_screen.dart` |
| 4 | Vérifier chaque stat affichée correspond à la bonne valeur | 🟡 Important | `profile_screen.dart` |
| 5 | Styler les boutons ELO avec thème AppColors | 🟢 Style | `elo_chart.dart` |
| 6 | Aligner couleurs dartboard légende ↔ heatmap | 🟡 Important | `dartboard_input_stats.dart` |
| 7 | Afficher 5 derniers matchs classés dans historique | 🟡 Important | `profile_controller.dart` |
| 8 | Enrichir les badges (10+), grayscale non obtenus | 🟢 Feature | `profile_controller.dart`, `badges_screen.dart`, `badge_grid.dart` |
| 9 | Migration SQL pour streak tracking | 🟢 Feature | `027_streak_tracking.sql`, `player-stat.entity.ts` |
| 10 | Valider navigation cloche → social feed | 🟡 Important | `app_scaffold.dart` |
