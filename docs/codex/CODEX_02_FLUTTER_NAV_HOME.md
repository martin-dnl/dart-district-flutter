# 🏗️ CODEX PROMPT 02 – Flutter : Navigation Bar + Home Screen (Menu)

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`). L'app utilise GoRouter, Riverpod, Material 3. Les couleurs sont dans `core/config/app_colors.dart`, le thème dans `app_theme.dart`, les routes dans `app_routes.dart`. La nav bar est dans `shared/widgets/app_scaffold.dart`.

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Refonte Navigation Bar (`shared/widgets/app_scaffold.dart`)

### 1.1 Supprimer les labels
- Dans `_DockItem`, retirer le widget `Text(label)` et le `SizedBox(height: 4)` au-dessus.
- Augmenter la taille de l'icône de `size: 20` à `size: 26`.

### 1.2 Remplacer les items
La barre finale doit avoir **6 items** dans cet ordre :
1. **Accueil** → `Icons.home_rounded` → `/home`
2. **Carte** → `Icons.map_rounded` → `/map`
3. **Jouer** → `Icons.gps_fixed` (icône cible) → `/play`
4. **Club** → `Icons.groups_rounded` → `/club`
5. **Contacts** → `Icons.forum_rounded` → `/contacts`
6. **Tournois** → `Icons.emoji_events_rounded` (icône podium) → `/tournaments`

Mettre à jour la constante `items` et la méthode `_onTap` et `_currentIndex` en conséquence.

### 1.3 Retirer Profil de la nav bar
- Supprimer l'entrée Profil de la barre.
- La page Profil restera accessible via le header du Home Screen (clic avatar/username).
- **Note** : La route `/profile` reste dans `app_routes.dart` mais en dehors du `ShellRoute` (comme une route plein écran avec `parentNavigatorKey: _rootNavigatorKey` et un bouton retour).

### 1.4 Ajouter la route Tournois
- Dans `app_routes.dart`, ajouter :
  ```dart
  static const String tournaments = '/tournaments';
  static const String tournamentCreate = '/tournaments/create';
  static const String tournamentDetail = '/tournaments/:id';
  ```
- Créer un placeholder `TournamentsListScreen` dans `lib/features/tournaments/presentation/tournaments_list_screen.dart` avec un texte "Tournois - À venir".
- L'ajouter au `ShellRoute`.

---

## Tâche 2 : Refonte Home Screen (`features/home/presentation/home_screen.dart`)

### 2.1 Refonte du Header
Modifier `_HomeHeader` pour afficher :
- **À gauche** : Photo de l'utilisateur (avatar circulaire 44x44, `PlayerAvatar` widget existant). Si pas de photo → icône par défaut (déjà géré par `PlayerAvatar`).
- **À droite du photo** : Username en gras (16px) + nom du Club en dessous (12px, couleur `textSecondary`). Si pas de club → ne rien afficher.
- **Au clic** sur la photo OU le username → `context.push(AppRoutes.profile)`.
- Utiliser un `GestureDetector` ou `InkWell` englobant l'avatar + le texte.

### 2.2 Masquer la tuile "Match à valider"
- Retirer l'appel à `_PendingMatchCard` du `CustomScrollView`.
- Déplacer le widget `_PendingMatchCard` dans un nouveau fichier `lib/features/home/widgets/pending_match_card_sample.dart`. Annoter avec un commentaire `// SAMPLE: Widget conservé pour référence future. Non utilisé dans le build.`

### 2.3 Rendre les tuiles métriques cliquables
- `_MetricCard` "Territoires contrôlés" : au clic → `context.go(AppRoutes.map)`
- `_MetricCard` "Points de conquête" : au clic → `context.go(AppRoutes.club)`
- Ajouter un paramètre `VoidCallback? onTap` à `_MetricCard`, wrapper dans un `GestureDetector`.

### 2.4 Section "Forme Récente" – refonte complète
**Affichage** :
- Afficher uniquement les **5 derniers matchs ranked terminés**.
- Chaque tuile contient :
  - Pseudo adversaire (aligné à gauche)
  - Score des sets (ex: "2 - 1") au centre
  - Badge V (vert, `AppColors.success`) ou D (rouge, `AppColors.error`) aligné à droite
- Au-dessus des tuiles : pourcentage de victoire calculé sur ces 5 matchs, ex: "60% Victoires (3V – 2D)"
- Bouton "Voir l'historique" → `context.push(AppRoutes.matchHistory)`

**Données** :
- Créer un nouveau provider `recentRankedMatchesProvider` qui appelle `GET /matches/me?ranked=true&status=completed&limit=5`
- Créer un modèle `RecentMatchSummary` : `opponentName`, `setsScore` (ex: "2-1"), `won` (bool)

### 2.5 Bouton "Créer tournoi"
- Dans la section Tournois, le bouton redirige vers `context.push(AppRoutes.tournamentCreate)`.
- Créer un placeholder `TournamentCreateScreen`.

### 2.6 Supprimer la section "Effectif Actif"
- Retirer le widget correspondant du `CustomScrollView`.
- Retirer `activeMembers` du `HomeState` et du `HomeController`.

### 2.7 Section Tournois en cours
- Si l'utilisateur est inscrit à un tournoi en cours, afficher une tuile de tournoi (composant réutilisable `TournamentTile`).
- Pour le moment, laisser cette section conditionnelle avec un check sur un futur provider `myActiveTournamentsProvider`.

---

## Tâche 3 : Page Historique des Matchs

Créer `lib/features/match/presentation/match_history_screen.dart` :
- Route : `AppRoutes.matchHistory = '/match-history'`
- Affiche les 10 premiers matchs terminés (ranked ou non, tous).
- Chaque tuile a le même format que dans la forme récente (pseudo adversaire, score sets, badge V/D).
- Au clic sur une tuile → `context.push('/match/${matchId}/report')` (page rapport, sera créée plus tard).
- Bouton "Voir plus" en bas qui charge les 10 suivants (offset-based).
- Utiliser un `ListView.builder` avec un `isLoadingMore` state.

**Routing** : Ajouter comme route plein écran dans `app_routes.dart`.

---

## Contraintes
- Ne casse pas les imports existants.
- Utilise les widgets existants (`PlayerAvatar`, `GlassCard`, `StatCard`, etc.) quand possible.
- Respecte le design system (couleurs `AppColors`, fonts `GoogleFonts.rajdhani` et `GoogleFonts.manrope`).
- Tous les textes hardcodés en français.
- Pas de logique métier dans les widgets.
