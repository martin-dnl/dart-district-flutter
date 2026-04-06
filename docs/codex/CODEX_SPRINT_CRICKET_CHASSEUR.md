# CODEX SPRINT — Cricket & Chasseur Game Modes + Correctifs Play

> **Date** : 2026-04-06
> **Cible** : GPT5-Codex — Flutter (Dart) — Architecture Riverpod + GoRouter
> **Priorité** : P0 (correctif Play) → P1 (Cricket) → P2 (Chasseur)

---

## TABLE DES MATIÈRES

1. [Contexte Architectural](#1-contexte-architectural)
2. [Correctif 0 — Play Screen : Sections & Padding](#2-correctif-0--play-screen--sections--padding)
3. [Feature 1 — Mode Cricket : Règles & Écran de jeu](#3-feature-1--mode-cricket)
4. [Feature 2 — Mode Chasseur : Règles & Écran de jeu](#4-feature-2--mode-chasseur)
5. [Feature commune — Adaptation du GameSetupScreen](#5-feature-commune--adaptation-du-gamesetupscreen)
6. [Fichiers à créer / modifier — Résumé](#6-fichiers-à-créer--modifier--résumé)

---

## 1. CONTEXTE ARCHITECTURAL

### Stack

- **Framework** : Flutter 3.x, Dart
- **State Management** : Riverpod (`StateNotifier`, `Provider`, `FutureProvider`)
- **Navigation** : GoRouter (`context.push`, `context.go`, `context.pop`)
- **Design System** : `AppColors` (dark theme, neon-lime primary `#C8FF00`)
- **Widgets partagés** : `SectionHeader`, `DartButton`, `PlayerAvatar`, `Scoreboard`, `DartInput`, `DartboardInput`

### Architecture existante des matchs X01

```
lib/features/play/
├── controller/play_controller.dart    # GameConfig, GameMode enum, FinishType enum
├── presentation/
│   ├── play_screen.dart               # Hub des modes de jeu
│   ├── game_setup_screen.dart         # Configuration pré-match
│   ├── qr_scan_screen.dart            # Scan QR (user/club)
│   └── match_invite_player_screen.dart
├── widgets/
│   ├── game_mode_card.dart            # Tuile mode de jeu
│   └── ongoing_matches_tile.dart      # Matchs en cours

lib/features/match/
├── controller/
│   ├── match_controller.dart          # StateNotifier<MatchModel> — logique X01
│   ├── ongoing_matches_controller.dart
│   └── pending_invitation_controller.dart
├── models/
│   ├── match_model.dart               # MatchModel, PlayerMatch, RoundScore, DartPosition
│   └── match_report_data.dart
├── data/
│   ├── match_service.dart             # API REST pour matchs
│   └── match_realtime_service.dart    # Socket.IO temps réel
├── presentation/
│   ├── match_live_screen.dart         # Écran de jeu X01 actif
│   ├── match_report_screen.dart       # Rapport post-match
│   └── match_spectate_screen.dart
├── widgets/
│   ├── scoreboard.dart                # Affichage score/legs/sets
│   ├── dart_input.dart                # Saisie manuelle clavier
│   ├── dartboard_input.dart           # Saisie visuelle cible
│   └── round_details.dart             # Historique tours
```

### Modèles clés existants

**GameMode** (enum dans `play_controller.dart`) :
```dart
enum GameMode { x01_301, x01_501, x01_701, cricket, chasseur }
```

**MatchModel** (dans `match_model.dart`) :
```dart
class MatchModel {
  final String id;
  final String mode;           // '301', '501', '701', 'Cricket', 'Chasseur'
  final int startingScore;
  final List<PlayerMatch> players;
  final int currentPlayerIndex;
  final int currentRound, currentLeg, currentSet;
  final MatchStatus status;
  final List<RoundScore> roundHistory;
  final int setsToWin, legsPerSet;
  final String finishType;     // 'doubleOut', 'singleOut', 'masterOut'
  final bool isRanked, isTerritorial;
  // ...
}
```

**PlayerMatch** :
```dart
class PlayerMatch {
  final String name;
  final int score;
  final int legsWon, setsWon;
  final List<int> throwScores;
  final double average;
  final int doublesAttempted, doublesHit;
}
```

**MatchController.setupMatch()** — initialise un match X01 avec score de départ.

**SectionHeader** (dans `lib/shared/widgets/section_header.dart`) :
```dart
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  // Utilise GoogleFonts.rajdhani, fontSize 30, padding horizontal 16, vertical 8
}
```

### Routes existantes (extrait `app_routes.dart`)

```
/play               → PlayScreen
/play/setup          → GameSetupScreen (extra: gameMode string)
/play/setup/invite-player
/play/qr-scan
/match               → MatchLiveScreen
/match/:id/report    → MatchReportScreen
```

---

## 2. CORRECTIF 0 — Play Screen : Sections & Padding

### Fichier : `lib/features/play/presentation/play_screen.dart`

### État actuel (problème)

Les `SectionHeader` ont été supprimés par erreur. Le play screen affiche les tuiles X01 et les modes spéciaux sans titre de section, et le padding n'est pas harmonisé.

### Instructions

1. **Réimporter** `SectionHeader` :
```dart
import '../../../shared/widgets/section_header.dart';
```

2. **Restructurer le `CustomScrollView.slivers`** avec cette structure exacte :

```dart
slivers: [
  // Espacement supérieur
  const SliverToBoxAdapter(child: SizedBox(height: 12)),

  // Section: Modes de jeu
  const SliverToBoxAdapter(
    child: SectionHeader(title: 'Modes de jeu'),
  ),

  // Tuiles X01 — Row horizontale
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: GameModeCard(title: '301', subtitle: 'Classique', icon: Icons.gps_fixed, color: AppColors.primary, onTap: () => context.push(AppRoutes.gameSetup, extra: '301'))),
          const SizedBox(width: 12),
          Expanded(child: GameModeCard(title: '501', subtitle: 'Standard', icon: Icons.gps_fixed, color: AppColors.secondary, onTap: () => context.push(AppRoutes.gameSetup, extra: '501'))),
          const SizedBox(width: 12),
          Expanded(child: GameModeCard(title: '701', subtitle: 'Long', icon: Icons.gps_fixed, color: AppColors.accent, onTap: () => context.push(AppRoutes.gameSetup, extra: '701'))),
        ],
      ),
    ),
  ),

  // Espacement inter-section
  const SliverToBoxAdapter(child: SizedBox(height: 8)),

  // Modes spéciaux — Cricket & Chasseur (même section, pas de nouveau SectionHeader)
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _LargeGameModeCard(title: 'Cricket', ...),
          const SizedBox(height: 12),
          _LargeGameModeCard(title: 'Chasseur', ...),
        ],
      ),
    ),
  ),

  // Matchs en cours
  SliverToBoxAdapter(child: OngoingMatchesTile()),
  const SliverToBoxAdapter(child: SizedBox(height: 24)),
],
```

3. **Paddings à harmoniser** :
   - Toutes les sections de contenu : `EdgeInsets.symmetric(horizontal: 16)`
   - Espacement vertical entre sections : 8px (via `SizedBox(height: 8)`)
   - Espacement haut de page : 12px
   - Espacement bas : 24px

4. **NE PAS utiliser `const` devant les `SliverToBoxAdapter`** qui contiennent `SectionHeader` car `SectionHeader` utilise `GoogleFonts.rajdhani` qui n'est pas const.

### Résultat attendu

Un seul titre de section "Modes de jeu" en haut, suivi des 3 tuiles X01 en ligne, puis les 2 grandes cartes Cricket/Chasseur en colonne, puis les matchs en cours. Padding uniforme.

---

## 3. FEATURE 1 — Mode Cricket

### 3.1 Règles du Cricket

- **Joueurs** : 1v1 (2 joueurs)
- **Tours** : 3 fléchettes par joueur par tour (comme X01)
- **Zones à fermer** : 20, 19, 18, 17, 16, 15, Bullseye (7 zones)
- **Fermeture d'une zone** : toucher 3 fois la zone. Les doubles comptent comme 2 touches, les triples comme 3 touches.
- **Points infligés** : Si un joueur a fermé une zone et retouche cette zone, il inflige le score de la fléchette à chaque adversaire n'ayant pas encore fermé cette zone. Si tous les joueurs ont fermé la zone, pas de points infligés.
  - Exemple : Le joueur lance D20 (= 40 points, 2 touches sur le 20). S'il avait 1 touche dans le 20, il passe à 3 = zone fermée. S'il avait 0 touches, il passe à 2 (pas encore fermé).
  - Exemple : Le joueur a déjà fermé le 20 et lance T20 (= 3 touches × 20 = 60 pts infligés si adversaire n'a pas fermé le 20).
- **Points** : Le score de chaque joueur s'initialise à 0. Les points reçus (infligés par l'adversaire) s'ajoutent au score.
- **Condition de victoire du leg** : un joueur a fermé les 7 zones ET son score (points reçus) est ≤ au score de l'adversaire.
  - Si un joueur ferme tout mais a plus de points que l'adversaire, le jeu continue.

### 3.2 Modèle — CricketMatchState

**Créer** : `lib/features/match/models/cricket_match_state.dart`

```dart
/// Zones du cricket dans l'ordre d'affichage
const List<int> cricketZones = [20, 19, 18, 17, 16, 15, 25]; // 25 = Bull

class CricketPlayerState {
  final String name;
  final int score;                        // Points reçus (infligés par adversaire)
  final Map<int, int> hits;               // zone → nombre de touches (0..max)
  final int legsWon;
  final int setsWon;

  const CricketPlayerState({
    required this.name,
    this.score = 0,
    this.hits = const {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0},
    this.legsWon = 0,
    this.setsWon = 0,
  });

  bool isClosed(int zone) => (hits[zone] ?? 0) >= 3;
  bool get allClosed => cricketZones.every(isClosed);

  CricketPlayerState copyWith({...});
}

class CricketMatchState {
  final String id;
  final List<CricketPlayerState> players;  // Toujours 2
  final int currentPlayerIndex;
  final int currentDartInTurn;             // 0, 1, 2 (3 fléchettes/tour)
  final int currentRound;
  final int currentLeg;
  final int currentSet;
  final int setsToWin;
  final int legsPerSet;
  final MatchStatus status;
  final List<CricketRoundEntry> roundHistory;

  // Derived
  bool get isLegOver { ... }
}

class CricketRoundEntry {
  final int playerIndex;
  final int round;
  final List<CricketDart> darts;   // Exactement 3 fléchettes par tour
}

class CricketDart {
  final int zone;       // 15-20 ou 25 (bull); -1 si hors zone cricket
  final int multiplier; // 1 = single, 2 = double, 3 = triple
  final int hitsApplied;  // Nombre de touches appliquées à la zone
  final int pointsInflicted; // Points infligés à l'adversaire (0 si zone pas fermée ou adversaire a fermé)
}
```

### 3.3 Controller — CricketMatchController

**Créer** : `lib/features/match/controller/cricket_match_controller.dart`

```dart
class CricketMatchController extends StateNotifier<CricketMatchState> {
```

#### Méthode `setupMatch()`
- Paramètres : `playerNames`, `setsToWin`, `legsPerSet`, `startingPlayerIndex`
- Initialise l'état avec scores à 0, hits à 0 pour chaque zone, status = inProgress

#### Méthode `registerDart(int zone, int multiplier)`

Cette méthode est appelée à chaque clic sur une case du tableau cricket.

Logique :
1. Vérifier que `status == inProgress` et `currentDartInTurn < 3`
2. Si `zone` n'est pas dans `cricketZones`, enregistrer un dart "miss" (hors zone), incrémenter dartInTurn
3. Calculer le nombre de touches = `multiplier` (1, 2 ou 3)
4. Récupérer les hits actuels du joueur courant dans cette zone
5. Calculer les touches effectives :
   - `touchesBeforeClose = max(0, 3 - currentHits)` → touches qui comptent pour fermer
   - `touchesAfterClose = max(0, totalTouches - touchesBeforeClose)` → touches excédentaires
6. Mettre à jour `hits[zone] = min(currentHits + totalTouches, 6)` (cap pour affichage, mais 3+ = fermé)
7. Si `touchesAfterClose > 0` ET l'adversaire n'a PAS fermé cette zone :
   - `pointsInflicted = touchesAfterClose × zoneValue` (valeur de la zone : 20, 19…15, ou 25 pour bull)
   - Ajouter `pointsInflicted` au `score` de l'adversaire
8. Incrémenter `currentDartInTurn`
9. Si `currentDartInTurn == 3` → fin du tour :
   - Ajouter `CricketRoundEntry` à l'historique
   - Vérifier condition de victoire du leg
   - Si pas de victoire : passer au joueur suivant, reset `currentDartInTurn = 0`

#### Méthode `_checkLegWin() → bool`

```
Le joueur courant gagne le leg si :
  - Il a fermé toutes les zones (allClosed == true)
  - ET son score (points reçus) ≤ score de l'adversaire
```

Si le leg est gagné :
- Incrémenter `legsWon` du joueur
- Vérifier victoire du set (legsWon >= ceil(legsPerSet / 2))
- Si set gagné → incrémenter `setsWon`, vérifier match gagné
- Si match gagné → `status = finished`
- Sinon → reset leg (scores à 0, hits à 0, alterner le joueur qui commence)

#### Méthode `undoLastDart()`

- Si `currentDartInTurn > 0` : annuler le dernier dart du tour en cours
- Si `currentDartInTurn == 0` et qu'il y a un historique : revenir au tour précédent (3ème dart)
- Recalculer hits et scores infligés en sens inverse

#### Provider Riverpod

```dart
final cricketMatchControllerProvider =
    StateNotifierProvider<CricketMatchController, CricketMatchState>((ref) {
  return CricketMatchController();
});
```

### 3.4 Écran — CricketMatchScreen

**Créer** : `lib/features/match/presentation/cricket_match_screen.dart`

#### Layout global

```
┌─────────────────────────────────────┐
│  Scoreboard simplifié (noms+scores) │  ← Score = points reçus
│  Joueur 1: 0    Joueur 2: 40       │
│  Legs 0-0  Sets 0-0                │
├─────────────────────────────────────┤
│  Tour: 3  │  Fléchette: 2/3        │  ← Info tour courant
├──────┬──────────┬───────────────────┤
│  J1  │  Zone    │  J2               │  ← En-tête colonnes
├──────┼──────────┼───────────────────┤
│  ╳●  │   20     │                   │  ← J1 a 3 touches (fermé)
│  ╳   │   19     │  /                │  ← J1: 2, J2: 1
│  /   │   18     │  ╳                │  ← J1: 1, J2: 2
│      │   17     │                   │  ← Aucun des deux
│      │   16     │  /                │  
│  ╳●  │   15     │  ╳●               │  ← Les deux ont fermé
│      │  BULL    │                   │
├──────┴──────────┴───────────────────┤
│  [Undo]              [Fléchette ▶] │  ← Actions
└─────────────────────────────────────┘
```

#### Structure du widget

```dart
class CricketMatchScreen extends ConsumerStatefulWidget { ... }

class _CricketMatchScreenState extends ConsumerState<CricketMatchScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cricketMatchControllerProvider);
    final controller = ref.read(cricketMatchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Cricket'), actions: [...]),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Scoreboard header
            _CricketScoreboard(state: state),
            // 2. Indicateur tour/fléchette
            _TurnIndicator(round: state.currentRound, dart: state.currentDartInTurn),
            // 3. Tableau cricket principal
            Expanded(child: _CricketGrid(state: state, onCellTap: _onCellTap)),
            // 4. Actions (undo, etc.)
            _ActionBar(onUndo: controller.undoLastDart),
          ],
        ),
      ),
    );
  }
}
```

#### Widget `_CricketScoreboard`

- Deux côtés (joueur 1 / joueur 2)
- Affiche le nom du joueur
- Affiche le `score` (points reçus) en grand
- Affiche legs/sets en petit
- Surligne le joueur actif avec `AppColors.primary`

#### Widget `_CricketGrid`

- Widget table 7 lignes × 3 colonnes
- **Colonne gauche** : hits du joueur 1 (cliquable si c'est son tour)
- **Colonne centre** : numéro de zone (20, 19, 18, 17, 16, 15, BULL)
- **Colonne droite** : hits du joueur 2 (cliquable si c'est son tour)

**Logique de tap** :
- Au tap sur une cellule de la colonne du joueur courant :
  - Incrémenter le nombre de touches pour cette zone
  - Appeler `controller.registerDart(zone, 1)` pour un single
  
- **IMPORTANT** : Pour saisir les doubles/triples, implémenter un système de tap :
  - **1 tap** = Single (1 touche)
  - **2 taps rapides** (double-tap) = Double (2 touches)
  - **Long press** = Triple (3 touches)
  - Afficher un feedback visuel bref indiquant "S", "D" ou "T"

**Affichage des touches** (par cellule joueur) :
- 0 touches : cellule vide
- 1 touche : trait oblique `/` → utiliser `CustomPaint` ou un `Icon` slash
- 2 touches : croix `╳` → superposer deux traits ou utiliser `Icons.close`
- 3+ touches (fermé) : cercle barré `⊗` → croix + cercle autour

Implémentation recommandée via `CustomPainter` :

```dart
class _CricketHitsPainter extends CustomPainter {
  final int hits;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final markSize = size.shortestSide * 0.3;

    if (hits >= 1) {
      // Trait oblique /
      canvas.drawLine(
        Offset(cx - markSize, cy + markSize),
        Offset(cx + markSize, cy - markSize),
        paint,
      );
    }
    if (hits >= 2) {
      // Trait oblique \ → forme la croix ╳
      canvas.drawLine(
        Offset(cx - markSize, cy - markSize),
        Offset(cx + markSize, cy + markSize),
        paint,
      );
    }
    if (hits >= 3) {
      // Cercle autour de la croix → fermé ⊗
      canvas.drawCircle(Offset(cx, cy), markSize * 1.3, paint);
    }
  }
}
```

- Si la zone est fermée par le joueur ET fermée par l'adversaire : afficher en gris atténué
- Si la zone est fermée par le joueur mais PAS par l'adversaire : afficher en `AppColors.primary` (le joueur peut scorer dessus)
- Zone non fermée : afficher en `AppColors.textPrimary`

#### Couleurs des cellules

- Cellule du joueur actif, zone non encore fermée : fond `AppColors.card` avec bordure subtile `AppColors.surfaceLight`
- Cellule du joueur actif, zone fermée mais adversaire pas fermé : fond `AppColors.primary.withOpacity(0.1)` (indique qu'il peut scorer)
- Cellule du joueur actif, zone fermée et adversaire fermé aussi : fond grisé `AppColors.surface`
- Cellule de l'autre joueur (non interactif ce tour) : fond `AppColors.surface`, pas de tap
- Colonne centrale (zones) : fond `AppColors.card`, texte en gras

#### Widget `_TurnIndicator`

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('Tour $currentRound', style: ...),
      Text('Fléchette ${currentDart + 1}/3', style: ...),
    ],
  ),
)
```

#### Dialog de fin de leg/match

- Réutiliser le pattern existant de `match_live_screen.dart` pour les dialogues de fin
- Afficher : gagnant du leg, tableau récapitulatif des zones fermées, score final
- Boutons : "Leg suivant" / "Terminer" / "Voir rapport"

### 3.5 Route

Dans `app_routes.dart`, ajouter :

```dart
GoRoute(
  path: '/match/cricket',
  builder: (context, state) => const CricketMatchScreen(),
),
```

### 3.6 Lancement depuis GameSetupScreen

Dans `_startMatch()` du `game_setup_screen.dart`, ajouter un branchement :

```dart
if (widget.gameMode == 'Cricket') {
  ref.read(cricketMatchControllerProvider.notifier).setupMatch(
    playerNames: [currentUserName, opponentLabel],
    setsToWin: _setsToWin,
    legsPerSet: _legsPerSet,
    startingPlayerIndex: _startingPlayerIndex,
  );
  context.go('/match/cricket');
  return;
}
```

---

## 4. FEATURE 2 — Mode Chasseur

### 4.1 Règles du Chasseur

- **Joueurs** : 2+ joueurs (multi-joueurs possible)
- **Assignation initiale** : Au début du leg, chaque joueur se voit assigner une zone cible (de 1 à 20 ou Bull/25). La saisie se fait manuellement via un écran de sélection.
- **Vies** : Chaque joueur commence avec **1 vie**. Maximum **4 vies**.
- **Tour du joueur** (3 fléchettes) :
  - Le joueur doit toucher **sa propre zone assignée** pour gagner des vies
  - Single = +1 vie, Double = +2 vies, Triple = +3 vies
  - Cap à 4 vies maximum
  - S'il touche la zone d'un autre joueur, rien ne se passe (sauf s'il est chasseur)
- **Statut Chasseur** :
  - Dès qu'un joueur atteint **4 vies**, il devient **Chasseur**
  - Un Chasseur peut viser les zones des adversaires pour leur enlever des vies
  - S'il touche la zone d'un adversaire : Single = -1 vie, Double = -2 vies, Triple = -3 vies
  - Le joueur chasseur peut aussi continuer à toucher sa zone, mais ses vies sont capées à 4
- **Élimination** : un joueur est éliminé quand ses vies passent à **-1** (en dessous de 0)
  - Un joueur à 0 vie n'est PAS encore éliminé
- **Victoire** : Le leg se termine quand il ne reste plus qu'**un seul joueur** en jeu
- **Note** : Pas de legs/sets pour le chasseur dans un premier temps, une seule manche = match complet. Mais garder la structure extensible.

### 4.2 Modèle — ChasseurMatchState

**Créer** : `lib/features/match/models/chasseur_match_state.dart`

```dart
class ChasseurPlayerState {
  final String name;
  final int zone;          // Zone assignée (1-20 ou 25 pour bull)
  final int lives;         // Vies actuelles (démarre à 1, max 4)
  final bool isEliminated; // true si vies < 0
  final bool isHunter;     // true si vies == 4

  const ChasseurPlayerState({
    required this.name,
    required this.zone,
    this.lives = 1,
    this.isEliminated = false,
    this.isHunter = false,
  });

  ChasseurPlayerState copyWith({...});
}

class ChasseurMatchState {
  final String id;
  final List<ChasseurPlayerState> players;
  final int currentPlayerIndex;     // Index du joueur qui joue (skip les éliminés)
  final int currentDartInTurn;      // 0, 1, 2
  final int currentRound;
  final MatchStatus status;
  final ChasseurPhase phase;        // zoneSelection, playing
  final List<ChasseurRoundEntry> roundHistory;

  int get activePlayers => players.where((p) => !p.isEliminated).length;
}

enum ChasseurPhase { zoneSelection, playing }

class ChasseurRoundEntry {
  final int playerIndex;
  final int round;
  final List<ChasseurDart> darts;
}

class ChasseurDart {
  final int zone;         // Zone touchée
  final int multiplier;   // 1, 2, 3
  final int livesChanged; // +1/+2/+3 si propre zone, -1/-2/-3 si chasseur touche adversaire, 0 sinon
  final int? targetPlayerIndex; // Index du joueur ciblé (si chasseur), null si touche propre zone
}
```

### 4.3 Controller — ChasseurMatchController

**Créer** : `lib/features/match/controller/chasseur_match_controller.dart`

```dart
class ChasseurMatchController extends StateNotifier<ChasseurMatchState> {
```

#### Méthode `setupMatch(playerNames, startingPlayerIndex)`
- Phase initiale = `zoneSelection`
- Initialise les joueurs avec nom, zone = -1 (pas encore assigné), lives = 1

#### Méthode `assignZone(int playerIndex, int zone)`
- Valider que la zone est entre 1-20 ou 25
- Valider qu'aucun autre joueur n'a déjà cette zone (zones uniques par joueur)
- Affecter la zone au joueur
- Si tous les joueurs ont une zone : passer en `phase = playing`, `status = inProgress`

#### Méthode `registerDart(int zone, int multiplier)`

Logique complète :
1. Vérifier `phase == playing`, `status == inProgress`, `currentDartInTurn < 3`
2. Identifier le joueur courant
3. Déterminer l'effet :

```
SI zone == joueur_courant.zone :
  → Le joueur touche sa propre zone
  → livesGain = multiplier
  → nouvelles_vies = min(4, joueur_courant.lives + livesGain)
  → Mettre à jour isHunter = (nouvelles_vies == 4)
  → targetPlayerIndex = null

SINON SI joueur_courant.isHunter :
  → Chercher le joueur dont la zone == zone touchée
  → Si trouvé ET pas éliminé :
    → livesLost = multiplier
    → nouvelles_vies_cible = joueur_cible.lives - livesLost
    → Si nouvelles_vies_cible < 0 : joueur_cible.isEliminated = true
    → targetPlayerIndex = index du joueur cible
  → Si pas trouvé ou déjà éliminé : dart manqué (0 effet)

SINON :
  → Dart hors zone pertinente, pas d'effet
```

4. Enregistrer le `ChasseurDart` dans le tour
5. Incrémenter `currentDartInTurn`
6. Si `currentDartInTurn == 3` :
   - Enregistrer `ChasseurRoundEntry`
   - Vérifier : `activePlayers <= 1` → match terminé, dernier joueur = gagnant
   - Sinon : avancer au prochain joueur non éliminé

#### Méthode `_nextActivePlayer() → int`

```dart
int _nextActivePlayer() {
  var next = (state.currentPlayerIndex + 1) % state.players.length;
  while (state.players[next].isEliminated) {
    next = (next + 1) % state.players.length;
  }
  return next;
}
```

#### Méthode `undoLastDart()`

- Logique inverse à `registerDart`

#### Provider

```dart
final chasseurMatchControllerProvider =
    StateNotifierProvider<ChasseurMatchController, ChasseurMatchState>((ref) {
  return ChasseurMatchController();
});
```

### 4.4 Écran — Phase de sélection des zones

**Créer** : `lib/features/match/presentation/chasseur_zone_selection_screen.dart`

Layout :
```
┌─────────────────────────────────────┐
│     🎯 Sélection des zones          │
│                                     │
│  Joueur 1: [___▼]  ← Dropdown 1-20 + Bull │
│  Joueur 2: [___▼]                   │
│  ...                                │
│                                     │
│  [Commencer la chasse]              │
└─────────────────────────────────────┘
```

- Pour chaque joueur, afficher un `DropdownButton` ou une grille 4×5 + Bull pour sélectionner la zone
- Valider que chaque joueur a une zone unique
- Bouton "Commencer" appelle `controller.assignZone()` pour chaque joueur, puis navigue vers l'écran de jeu

**Alternative recommandée** : Utiliser une grille interactive plutôt qu'un dropdown (plus visuel et adapté au thème gaming) :

```dart
GridView.count(
  crossAxisCount: 5,
  children: [
    for (var i = 1; i <= 20; i++) _ZoneTile(zone: i, ...),
    _ZoneTile(zone: 25, label: 'Bull', ...),
  ],
)
```

Chaque `_ZoneTile` affiche le numéro, grisé si déjà pris par un autre joueur, surligné en `AppColors.primary` si sélectionné.

### 4.5 Écran — ChasseurMatchScreen (phase de jeu)

**Créer** : `lib/features/match/presentation/chasseur_match_screen.dart`

Layout :
```
┌─────────────────────────────────────┐
│  🎯 Chasseur — Tour 3              │
│  Fléchette 2/3                     │
├─────────────────────────────────────┤
│  ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ J1  │ │ J2  │ │ J3  │          │  ← Joueurs en cercle/row
│  │ ♥♥♥♥│ │ ♥♡  │ │ ☠️  │          │  ← Vies (♥=vie, ♡=perdue, ☠=éliminé)
│  │ z:17│ │ z:20│ │ z:5 │          │  
│  │CHAS.│ │     │ │ OUT │          │  ← Badge chasseur / éliminé
│  └─────┘ └─────┘ └─────┘          │
├─────────────────────────────────────┤
│                                     │
│   Grille de zones cibles            │
│   ┌──┬──┬──┬──┬──┐                 │
│   │ 1│ 2│ 3│ 4│ 5│                 │
│   ├──┼──┼──┼──┼──┤                 │
│   │ 6│ 7│ 8│ 9│10│                 │
│   ├──┼──┼──┼──┼──┤                 │
│   │11│12│13│14│15│                 │
│   ├──┼──┼──┼──┼──┤                 │
│   │16│17│18│19│20│                 │
│   ├──┴──┴──┼──┴──┤                 │
│   │  Bull  │     │                 │
│   └────────┘     │                 │
│                                     │
│   Saisie: [1 tap=S, 2 taps=D, LP=T]│
├─────────────────────────────────────┤
│  [Undo]              [Passer ▶]    │
└─────────────────────────────────────┘
```

#### Widget `_PlayerCard` (pour chaque joueur)

```dart
Container(
  padding: EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: isActive ? AppColors.primary.withOpacity(0.15) : AppColors.card,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: isActive ? AppColors.primary : AppColors.surfaceLight,
      width: isActive ? 2 : 0.5,
    ),
  ),
  child: Column(
    children: [
      Text(player.name, style: ...),
      _LivesDisplay(lives: player.lives, maxLives: 4),
      Text('Zone: ${player.zone == 25 ? "Bull" : player.zone}'),
      if (player.isHunter) _HunterBadge(),
      if (player.isEliminated) _EliminatedBadge(),
    ],
  ),
)
```

#### Widget `_LivesDisplay`

Afficher les vies sous forme de cœurs :
- `♥` (plein, `AppColors.error`) pour chaque vie restante
- `♡` (vide, `AppColors.textHint`) pour chaque vie manquante (jusqu'à 4)
- Si éliminé : afficher `☠` ou croix rouge

```dart
Row(
  mainAxisSize: MainAxisSize.min,
  children: List.generate(4, (i) {
    if (player.isEliminated) return Icon(Icons.close, color: AppColors.error, size: 16);
    return Icon(
      i < player.lives ? Icons.favorite : Icons.favorite_border,
      color: i < player.lives ? AppColors.error : AppColors.textHint,
      size: 16,
    );
  }),
)
```

#### Grille de saisie

- Grille 4×5 + bull (21 cases)
- La **zone du joueur courant** est visuellement surlignée en `AppColors.primary`
- Les **zones des adversaires** sont surlignées en `AppColors.error` (si le joueur est chasseur)
- Les zones des joueurs éliminés sont grisées
- Les zones non assignées à aucun joueur sont en `AppColors.card` standard

**Système de saisie** (identique au cricket) :
- **1 tap** = Single
- **Double-tap** = Double
- **Long press** = Triple

Au tap, appeler `controller.registerDart(zone, multiplier)`.

#### Feedback visuel de chaque dart

Après enregistrement d'un dart, afficher brièvement (300ms) un toast/badge sur la grille :
- Touche sa zone : `+1 ♥` / `+2 ♥` / `+3 ♥` en vert
- Chasseur touche adversaire : `-1 ♥ J2` en rouge
- Touche hors zone utile : `Miss` en gris

### 4.6 Route

```dart
GoRoute(
  path: '/match/chasseur',
  builder: (context, state) => const ChasseurMatchScreen(),
),
GoRoute(
  path: '/match/chasseur/zones',
  builder: (context, state) => const ChasseurZoneSelectionScreen(),
),
```

### 4.7 Lancement depuis GameSetupScreen

```dart
if (widget.gameMode == 'Chasseur') {
  ref.read(chasseurMatchControllerProvider.notifier).setupMatch(
    playerNames: [currentUserName, opponentLabel],
    startingPlayerIndex: _startingPlayerIndex,
  );
  context.go('/match/chasseur/zones');
  return;
}
```

---

## 5. FEATURE COMMUNE — Adaptation du GameSetupScreen

### Fichier : `lib/features/play/presentation/game_setup_screen.dart`

### Logique conditionnelle selon le mode

Quand `widget.gameMode == 'Cricket'` ou `widget.gameMode == 'Chasseur'` :

1. **Masquer** la section "Type de match" (Classé/Amical + Territorial) :
   - Ces modes sont **systématiquement amicaux**
   - `_isRanked = false` et `_isTerritorial = false` forcés

2. **Masquer** la section "Type de finish" (Double Out / Single Out / Master Out) :
   - Pas applicable au Cricket ni au Chasseur

3. **Conserver** les sections suivantes :
   - Options de jeu (Inviter / Scan / Local)
   - Legs par set et Sets pour gagner (pour Cricket seulement — Chasseur = 1 manche)
   - Qui commence
   - Bouton "Commencer la partie"

4. Pour le **Chasseur spécifiquement** :
   - Masquer aussi "Legs par set" et "Sets pour gagner" (une seule manche)
   - Ou les afficher en hint grisé non modifiable

### Implémentation

Ajouter un getter helper en haut du `_GameSetupScreenState` :

```dart
bool get _isSpecialMode =>
    widget.gameMode == 'Cricket' || widget.gameMode == 'Chasseur';

bool get _isCricketMode => widget.gameMode == 'Cricket';
bool get _isChasseurMode => widget.gameMode == 'Chasseur';
```

Puis wrapper les sections conditionnelles :

```dart
// Section "Type de match" — seulement pour X01
if (!_isSpecialMode && !isGuest) ...[
  // ... switch Classé/Amical
  // ... switch Territorial
],

// Section "Type de finish" — seulement pour X01
if (!_isSpecialMode) ...[
  // ... sélecteur Double/Single/Master Out
],

// Section "Legs/Sets" — seulement pour X01 et Cricket
if (!_isChasseurMode) ...[
  // ... compteurs legs/sets
],
```

### Lancement conditionnel dans `_startMatch()`

Modifier la méthode `_startMatch()` pour brancher selon le mode :

```dart
Future<void> _startMatch({ContactModel? selectedOpponent}) async {
  final currentUserName = ref.read(authControllerProvider).user?.username ?? 'Moi';
  final opponentLabel = selectedOpponent?.username ?? 'Adversaire';
  final playerNames = [currentUserName, opponentLabel];

  // Branchement Cricket
  if (_isCricketMode) {
    ref.read(cricketMatchControllerProvider.notifier).setupMatch(
      playerNames: playerNames,
      setsToWin: _setsToWin,
      legsPerSet: _legsPerSet,
      startingPlayerIndex: _startingPlayerIndex,
    );
    context.go('/match/cricket');
    return;
  }

  // Branchement Chasseur
  if (_isChasseurMode) {
    ref.read(chasseurMatchControllerProvider.notifier).setupMatch(
      playerNames: playerNames,
      startingPlayerIndex: _startingPlayerIndex,
    );
    context.go('/match/chasseur/zones');
    return;
  }

  // X01 existant — code actuel inchangé
  // ...
}
```

---

## 6. FICHIERS À CRÉER / MODIFIER — RÉSUMÉ

### Fichiers à CRÉER

| Fichier | Description |
|---------|-------------|
| `lib/features/match/models/cricket_match_state.dart` | Modèle d'état Cricket (CricketPlayerState, CricketMatchState, CricketDart, CricketRoundEntry) |
| `lib/features/match/controller/cricket_match_controller.dart` | Controller Cricket (registerDart, undoLastDart, setupMatch, _checkLegWin) |
| `lib/features/match/presentation/cricket_match_screen.dart` | Écran de jeu Cricket (grille 3 colonnes, scoreboard, input) |
| `lib/features/match/models/chasseur_match_state.dart` | Modèle d'état Chasseur (ChasseurPlayerState, ChasseurMatchState, ChasseurDart) |
| `lib/features/match/controller/chasseur_match_controller.dart` | Controller Chasseur (assignZone, registerDart, undoLastDart, _nextActivePlayer) |
| `lib/features/match/presentation/chasseur_match_screen.dart` | Écran de jeu Chasseur (grille zones, player cards, vies) |
| `lib/features/match/presentation/chasseur_zone_selection_screen.dart` | Sélection des zones initiale pour chaque joueur |

### Fichiers à MODIFIER

| Fichier | Modifications |
|---------|---------------|
| `lib/features/play/presentation/play_screen.dart` | Réintégrer `SectionHeader('Modes de jeu')`, harmoniser paddings |
| `lib/features/play/presentation/game_setup_screen.dart` | Masquer sections inapplicables pour Cricket/Chasseur, brancher `_startMatch()` |
| `lib/core/config/app_routes.dart` | Ajouter routes `/match/cricket`, `/match/chasseur`, `/match/chasseur/zones` |

### Fichiers à NE PAS toucher

- `match_controller.dart` — reste dédié X01
- `match_live_screen.dart` — reste dédié X01
- `match_model.dart` — les modes Cricket et Chasseur ont leurs propres modèles séparés
- `scoreboard.dart`, `dart_input.dart`, `dartboard_input.dart` — restent dédiés X01

### Contraintes techniques

1. **Riverpod** : utiliser `StateNotifierProvider` pour les nouveaux controllers (pattern identique à `matchControllerProvider`)
2. **GoRouter** : les nouvelles routes doivent être des enfants du shell route principal pour bénéficier de `AppScaffold`
3. **AppColors** : utiliser exclusivement la palette existante, ne pas créer de nouvelles couleurs
4. **Imports** : organiser avec les 3 groupes habituels (dart/flutter, packages, relative)
5. **CustomPainter** : pour les marques de hits cricket et les icônes de vies chasseur, préférer `CustomPaint` pour un rendu pixel-perfect
6. **Pas de backend** : ces modes sont locaux uniquement pour cette itération (pas d'API, pas de Socket.IO, pas de classement)
7. **État en mémoire** : les matchs Cricket et Chasseur vivent uniquement dans le provider Riverpod. Pas de persistance locale pour cette itération.

### Ordre d'implémentation recommandé

1. `play_screen.dart` — correctif sections/padding (5 min)
2. `game_setup_screen.dart` — conditionnels mode spécial (15 min)
3. Modèle + Controller Cricket
4. Écran Cricket
5. Routes Cricket
6. Modèle + Controller Chasseur
7. Écran sélection zones Chasseur
8. Écran jeu Chasseur
9. Routes Chasseur
10. Test intégration complet
