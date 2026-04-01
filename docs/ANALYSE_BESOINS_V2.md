# 📋 Analyse Complète des Besoins d'Évolution Fonctionnelle – Dart District V2

> Document d'analyse rédigé après audit complet du code Flutter + NestJS existant.
> Chaque point du cahier des charges est vérifié pour sa cohérence, ses prérequis et ses éventuels manques.

---

## 📑 Table des matières

1. [Composant Menu (Home)](#1-composant-menu-home)
2. [Composant Navigation Bar](#2-composant-navigation-bar)
3. [Onglet Club](#3-onglet-club)
4. [Page Configuration de Partie](#4-page-configuration-de-partie)
5. [Process Match](#5-process-match)
6. [Page Profil](#6-page-profil)
7. [Page Contact](#7-page-contact)
8. [Page Rapport de Partie](#8-page-rapport-de-partie)
9. [Mode Spectateur](#9-mode-spectateur)
10. [Tournois](#10-tournois)

---

## 1. Composant Menu (Home)

### 1.1 Photo utilisateur dans le header + upload avatar

**Besoin** : Afficher la photo (ou icône par défaut) + username / club dans le header. Clic sur l'avatar dans Profil → modale camera/galerie. Compression + crop carré. Deux formats (icône standard + miniature bulle).

**État actuel** :
- `HomeScreen` affiche un `_HomeHeader` avec `clubName`, `location`, `avatarUrl` — l'avatar est déjà passé mais pas cliquable.
- `UserModel` a un `avatarUrl` (string nullable).
- `User` entity backend a `avatar_url` (text nullable).
- `UpdateUserDto` accepte déjà `avatar_url?: string`.
- **PAS d'endpoint d'upload de fichier côté backend.**

**Analyse & Préconisations** :
- ✅ Cohérent. La structure de données existe.
- ⚠️ **Manque critique** : Endpoint `POST /users/me/avatar` avec `multipart/form-data` côté backend.
- **Préconisation stockage** : Stocker les images dans un répertoire serveur `uploads/avatars/` (pas en base binaire). Stocker le chemin relatif dans `avatar_url`. Servir via Nginx (ou static files NestJS). C'est la solution standard la plus performante :
  - Image originale croppée + compressée côté Flutter avant envoi (quality ~80%, max ~400x400px pour l'icône standard, ~80x80 pour la miniature).
  - Le backend génère deux variantes : `{uuid}_md.webp` (200x200) et `{uuid}_sm.webp` (64x64).
  - Utiliser le format **WebP** pour le poids optimal.
- **Prérequis** :
  - Package Flutter : `image_picker`, `image_cropper` (ou `crop_your_image`)
  - Package backend : `multer` (déjà natif NestJS), `sharp` pour le redimensionnement
  - Migration SQL : aucune (colonne `avatar_url` existe déjà)
  - Nouvelle route API : `POST /users/me/avatar` (multipart)
  - Mise à jour `UpdateUserDto` : la réponse retourne les URLs des deux variantes

**Manque identifié** :
- Le besoin ne précise pas si l'upload est immédiat ou avec confirmation. **Recommandation** : upload immédiat après crop, spinner de chargement, puis rafraîchissement du provider auth.

---

### 1.2 Tuile "Match à valider" masquée (garder en sample)

**Besoin** : La tuile `_PendingMatchCard` ne doit plus s'afficher mais on veut garder le code.

**État actuel** : `_PendingMatchCard` est affiché directement dans le `CustomScrollView` de `HomeScreen`.

**Analyse** : Simple. Commenter le widget ou le wrapper dans un `if (false)`.

**Préconisation** : Déplacer le widget dans un fichier dédié `lib/features/home/widgets/pending_match_card_sample.dart` et le retirer du tree du `HomeScreen`. Annoter `@Deprecated` ou un commentaire `// SAMPLE: kept for future use`.

**Prérequis** : Aucun.

---

### 1.3 Clic header → profil

**Besoin** : Clic sur username ou photo dans le header redirige vers `/profile`.

**État actuel** : Le header n'a pas de `GestureDetector` / `InkWell` sur l'avatar ou le username.

**Analyse** : ✅ Trivial. Wrapper le widget dans un `GestureDetector` → `context.go(AppRoutes.profile)`.

**Prérequis** : Aucun.

---

### 1.4 Bouton "Territoires contrôlés" → Carte

**Besoin** : Clic → `AppRoutes.map`.

**État actuel** : `_MetricCard` est un widget statique sans `onTap`.

**Analyse** : ✅ Ajouter un callback `onTap` à `_MetricCard`. Trivial.

**Prérequis** : Aucun.

---

### 1.5 Bouton "Points de conquête" → Club

**Besoin** : Clic → `AppRoutes.club`.

**Analyse** : Idem 1.4. Trivial.

---

### 1.6 Forme récente – "Voir l'historique" → page historique paginée

**Besoin** : Page d'historique dédiée avec 10 matchs, bouton "voir plus" pour les 10 suivants (lazy load).

**État actuel** :
- `HomeScreen` a un `_SectionTitle` avec un action "Voir l'historique" (non fonctionnel).
- Le backend a `GET /matches/me?limit=N` mais **pas de pagination offset/cursor**.

**Analyse** :
- ⚠️ **Manque backend** : Ajouter un paramètre `offset` ou `cursor` sur `GET /matches/me`.
- Côté Flutter, créer une nouvelle page `MatchHistoryScreen` avec une `ListView` + bouton "voir plus" en bas.
- Nouvelle route : `AppRoutes.matchHistory = '/match-history'`.

**Prérequis** :
- Backend : Ajouter `@Query('offset') offset?: number` sur `GET /matches/me`
- Flutter : Nouvelle page + route

---

### 1.7 Forme récente – 5 derniers matchs ranked

**Besoin** : Afficher uniquement les 5 derniers matchs ranked (terminés). Tuile : `{{pseudo adversaire}} {{score sets}}` + badge V/D. Pourcentage victoire sur ces 5.

**État actuel** :
- Le `Match` entity n'a **pas de champ `ranked` (booléen)**. Il a `is_offline` et `is_territorial`.
- Le `HomeController` charge des données mock pour `recentResults`, `recentRecord`, etc.
- Pas de filtrage ranked côté backend.

**Analyse** :
- ⚠️ **Manque critique** : Le booléen `ranked` n'existe pas dans le modèle `Match`.
- **Prérequis** :
  - Migration SQL : `ALTER TABLE matches ADD COLUMN is_ranked BOOLEAN DEFAULT false;`
  - Mise à jour entity `Match` backend + DTO
  - Mise à jour `MatchModel` Flutter
  - Endpoint API ou paramètre filtre : `GET /matches/me?ranked=true&limit=5&status=completed`
  - Calcul du % victoire côté Flutter ou backend

**Manque identifié** :
- Le besoin dit "matchs ranked" mais le switch "Classé/Amical" est défini plus loin dans la page de config. Il faut s'assurer de la cohérence : un match est `is_ranked = true` quand le switch est sur "Classé".
- **Question** : Les matchs territoriaux sont-ils automatiquement ranked ? **Recommandation** : Oui, un match territorial devrait être ranked par défaut.

---

### 1.8 Bouton "Créer tournoi" → page création tournoi

**Besoin** : Redirige vers page future.

**État actuel** : Il y a une section tournoi dans le `HomeScreen` (TODO).

**Analyse** : Créer la route `AppRoutes.tournamentCreate` et une page placeholder.

---

### 1.9 Section "Effectif Actif" supprimée

**État actuel** : `activeMembers` dans `HomeState`, affiché dans `HomeScreen`.

**Analyse** : ✅ Supprimer le widget et le champ du state.

---

## 2. Composant Navigation Bar

### 2.1 Supprimer les labels

**État actuel** : `_DockItem` affiche un `Text(label)` sous l'icône.

**Analyse** : ✅ Supprimer le `Text` et augmenter la taille de l'icône (actuellement `size: 20`, passer à `26-28`).

---

### 2.2 Remplacer icône "Tournois" (pointant vers Play) par icône "cible"

**État actuel** : L'index 2 pointe vers `AppRoutes.play` mais l'item s'appelle "Tournois" avec `Icons.sports_score_rounded`.

**Analyse** :
- ✅ L'icône "cible" utilisée dans la page game setup est `Icons.gps_fixed`.
- Remplacer `Icons.sports_score_rounded` par `Icons.gps_fixed` pour l'item index 2 qui pointe vers `/play`.

---

### 2.3 Remplacer bouton Profil par bouton Tournois

**État actuel** : 6 items : Accueil, Carte, Tournois(→Play), Club, Contacts, Profil.

**Besoin** : Supprimer Profil de la nav bar, remplacer par Tournois (icône podium).

**Analyse** :
- ⚠️ **Incohérence détectée** : Si on retire Profil de la nav bar, comment y accéder ? → Via le header du Menu (clic avatar/username comme défini en 1.3). C'est cohérent.
- La nav bar finale sera : **Accueil (home), Carte (map), Jouer (gps_fixed → /play), Club (groups), Contacts (forum), Tournois (emoji_events → /tournaments)**.
- **Prérequis** : Créer `AppRoutes.tournaments` et `TournamentsListScreen` (même si placeholder).
- Mettre à jour les index dans `AppScaffold`.
- Retirer `/profile` du `ShellRoute` (accessible uniquement via push depuis le header).

**Manque identifié** :
- La page Profil ne sera plus dans le `ShellRoute`. Il faut la déplacer en route full-screen (comme `gameSetup`) ou la garder dans le shell et simplement ne pas l'afficher dans la barre.
- **Recommandation** : Garder Profil comme route plein écran (`parentNavigatorKey: _rootNavigatorKey`) avec bouton retour.

---

## 3. Onglet Club

### 3.1 Bouton "Trouver un club" → liste des 10 clubs les plus proches

**État actuel** :
- `ClubScreen` existe mais pas de fonctionnalité de recherche.
- Backend : `GET /clubs` retourne **tous les clubs** avec un `limit`. **Pas de tri par distance**.
- `Club` entity a `latitude` et `longitude`.

**Analyse** :
- ⚠️ **Manque backend** : Endpoint `GET /clubs/nearby?lat=XX&lng=XX&limit=10` avec tri par distance (formule Haversine ou PostGIS).
- Fallback si pas de localisation : `GET /clubs?sort=name&limit=10`.

**Prérequis** :
- Backend : Nouvel endpoint ou ajout de paramètres `lat`, `lng` sur `GET /clubs`
- Flutter : Utiliser `Geolocator` pour la position (déjà dans le projet)
- SQL : Pas besoin de PostGIS, le calcul Haversine en SQL natif suffit pour 10 résultats

---

### 3.2 Zone de recherche nom/ville

**Besoin** : Barre de recherche comme sur la page Map.

**État actuel** :
- Backend : `GET /clubs` n'a **pas de filtre texte** (pas de `?q=` ni `?city=`).

**Prérequis** :
- Backend : Ajouter `@Query('q') q?: string` et filtrer sur `name ILIKE` ou `city ILIKE`
- Flutter : Widget `TextField` + debounce, comme dans `MapScreen`

---

### 3.3 Tuiles de club (nom, membres, adresse, cibles)

**État actuel** :
- `Club` entity a `name`, `address`. Le nombre de cibles (`dart_boards_count`) **n'existe pas**.
- Le nombre de membres est déduit de la relation `members`.

**Prérequis** :
- Migration SQL : `ALTER TABLE clubs ADD COLUMN dart_boards_count INT DEFAULT 0;`
- Mise à jour entity, DTO, service
- Nouveau champ dans `CreateClubDto` et `UpdateClubDto`

**Manque identifié** :
- Le besoin parle de "au clic sur la tuile → page du club" avec bouton retour gardant le filtre. C'est un pattern standard : le filtre est conservé dans le state Riverpod, pas dans la route.

---

## 4. Page Configuration de Partie

### 4.1 Nouvelle option "Territoire" – disposition 2x2

**État actuel** : 3 options en Row (Inviter ami, Scanner QR, Vs Invité).

**Analyse** :
- Passer de Row à un Grid 2x2 : (Inviter ami, Scanner QR) / (Vs Invité, Territoire).
- ✅ Cohérent.

---

### 4.2 Switch "Classé / Amical" pour modes Inviter ami et Scanner QR

**Besoin** : Switch visible uniquement si option = inviteFriend ou scanQr. Valorise booléen `ranked`.

**État actuel** : Aucun switch. Le booléen `ranked` n'existe pas dans les modèles.

**Prérequis** :
- Ajouter `is_ranked` au `MatchModel` Flutter
- Ajouter `is_ranked` à l'entity backend (cf. section 1.7)
- Passer la valeur dans `createMatchInvitation` et `setupMatch`

---

### 4.3 Scanner QR n'affiche plus la notification

**État actuel** : Un `SnackBar` s'affiche au tap.

**Analyse** : ✅ Supprimer le `showSnackBar`.

---

### 4.4 Scanner QR ouvre la caméra → lire UUID utilisateur

**Besoin** : La caméra s'ouvre, lit un QR = UUID utilisateur. Succès → pseudo adversaire affiché. Échec → retour config avec sélections gardées.

**État actuel** :
- Le package `qr_code_scanner` est dans le projet (il y a un dossier `build/qr_code_scanner/`).
- Pas d'implémentation de scan dans `GameSetupScreen`.

**Analyse** :
- ⚠️ Le package `qr_code_scanner` est **déprécié**. Préférer `mobile_scanner` (plus actif, meilleur support).
- Superposer la caméra en overlay (Modal bottom sheet ou fullscreen overlay) au lieu de naviguer vers une nouvelle page → conserver le state de config.
- Après scan UUID, appeler `GET /users/:id` pour récupérer le pseudo.
- Valider que le contenu est bien un UUID v4 (regex).

**Prérequis** :
- Package Flutter : `mobile_scanner` (remplacer `qr_code_scanner`)
- Backend : L'endpoint `GET /users/:id` existe déjà
- Logique : Adapter le state du `GameSetupScreen` pour stocker l'adversaire trouvé par QR

---

### 4.5 Mode "Territoire" → scan QR club → liste membres → sélection adversaire

**Besoin** : QR = UUID club. Si trouvé → liste membres. Sélection adversaire → pseudo affiché. `is_territorial = true` + lien club.

**État actuel** :
- Backend : `GET /clubs/:id` retourne le club avec ses `members` et `members.user`. ✅ Exploitable.
- La table `matches` a déjà `is_territorial` et `territory_id`.

**Analyse** :
- Le QR contient l'UUID du **club** (pas du territoire). Le besoin ne mentionne pas comment associer le **territoire** à la partie. Le territoire dépend de la localisation géographique.
- ⚠️ **Manque** : Comment déterminer le `territory_id` ? Via la localisation GPS du joueur au moment du scan ? Via le QR code qui inclurait aussi le territoire ?
- **Recommandation** : Le QR du club contient uniquement le club UUID. Le territoire est déterminé automatiquement par le backend via l'endpoint `GET /territories/map/hit?lat=&lng=` avec la position GPS du joueur.

**Prérequis** :
- Flutter : Implémentation du scan QR club + appel `GET /clubs/:id` + affichage liste membres
- Nouveau composant : `ClubMembersPickerSheet` (bottom sheet avec liste des membres)
- Stocker `selectedOpponent`, `is_territorial = true`, `club_id` dans le state du `GameSetupScreen`

---

### 4.6 Section "Qui commence ?" – segmented button

**Besoin** : Apparaît seulement si adversaire défini. Segmented button avec pseudos. Par défaut = utilisateur.

**État actuel** : Le `startingPlayerIndex` existe dans `MatchModel` (default 0 = Joueur 1).

**Analyse** : ✅ Cohérent. Utiliser un `SegmentedButton` Flutter Material 3.

**Prérequis** : Aucun côté backend.

---

### 4.7 Bouton "Commencer la partie" cliquable seulement si adversaire défini

**État actuel** : Le bouton est toujours cliquable sauf pour "Inviter ami" sans sélection.

**Analyse** : ✅ Conditionner `onPressed` à `(hasOpponent ? () => ... : null)`.

**Manque identifié** :
- En mode "Vs Invité", faut-il considérer qu'un adversaire est toujours défini (nom = "Invité") ? **Recommandation** : Oui, "Vs Invité" implique un adversaire automatique.

---

### 4.8 Partie "Vs Invité" non sauvegardée en base

**État actuel** : Les parties sont envoyées au backend dans le cas `inviteFriend`. Le mode `guest` semble local seulement.

**Analyse** : ✅ À confirmer que `setupMatch` en mode guest ne fait pas d'appel API. Actuellement c'est le cas.

---

## 5. Process Match

### 5.1 Ne pas sauvegarder en base les matchs `is_offline`

**Analyse** : ✅ Côté Flutter, les matchs offline ne passent pas par l'API (déjà le cas). Vérifier que le sync offline ne les remonte pas non plus.

---

### 5.2 Noms des joueurs : utilisateur en premier, adversaire en second

**État actuel** : L'ordre dans `playerNames` est fixé dans `setupMatch`.

**Analyse** : ✅ S'assurer que l'ordre est toujours `[currentUser, opponent]` dans toutes les méthodes d'initialisation.

---

### 5.3 Titre : "Leg X / Set Y"

**État actuel** : Le titre affiché dépend du widget `Scoreboard`. Il faudrait afficher `Leg ${currentLeg} / Set ${currentSet}`.

**Analyse** : ✅ `MatchModel` a `currentLeg` et `currentSet`. Juste un changement UI.

---

### 5.4 Legs par set = Best Of (BO)

**Besoin** : `legsPerSet = 3` → BO3 → le SET se termine quand un joueur gagne 2 legs (majority).

**État actuel** : Dans `MatchController.submitScore`, la condition est :
```dart
if (currentPlayer.legsWon + 1 >= state.legsPerSet)
```
Cela signifie que si `legsPerSet = 3`, il faut gagner 3 legs pour gagner le set. Ce n'est **PAS** un BO3.

**⚠️ BUG/INCOHERENCE CRITIQUE** : La logique actuelle traite `legsPerSet` comme "nombre de legs à gagner" et non comme "nombre max de legs dans le set". Pour un BO3, le seuil devrait être `ceil(legsPerSet / 2)` = 2.

**Correction nécessaire** :
```dart
final legsToWin = (state.legsPerSet / 2).ceil(); // BO3 → 2 legs pour gagner
if (currentPlayer.legsWon + 1 >= legsToWin)
```

**Prérequis** :
- Modifier `MatchController` Flutter
- Vérifier la logique backend dans `MatchesService.submitScore`
- Adapter le label UI ("BO3" au lieu de "3 legs par set" ou clarifier)

---

### 5.5 Suggestions de finish double (checkout chart)

**Besoin** : Afficher jusqu'à 3 combinaisons de finish possibles en double sous le score du joueur, à partir de 170.

**Analyse** :
- **Préconisation : données en local**. Les patterns de checkout sont statiques (170 combinaisons connues, de 170 à 2). Les charger depuis un fichier JSON local ou une map Dart est la solution la plus performante — pas besoin d'appel API.
- Créer un fichier `lib/features/match/data/checkout_chart.dart` avec une `Map<int, List<List<String>>>` (score → liste de combinaisons, chaque combinaison = 1-3 fléchettes).
- Afficher 3 tuiles carrées alignées sous le score quand le score est ≤ 170 et qu'un finish existe.

**Prérequis** :
- Nouveau fichier de données statiques
- Nouveau widget `CheckoutSuggestions`
- Uniquement affiché en mode Double Out (pas en Single Out)

---

### 5.6 Modale nombre de doubles tentés

**Besoin** : Quand un finish est possible (score ≤ 170 et combinaison existe), modale pour demander combien de doubles ont été tentés (0, 1, 2, 3).

**État actuel** : La modale `_askDoubleAttempts` existe déjà dans `MatchLiveScreen` mais ne s'affiche que quand le score atteint 0.

**Analyse** :
- Il faut distinguer deux cas :
  1. **Score atteint 0** : la modale actuelle de checkout s'affiche (nombre de doubles tentés pour réussir)
  2. **Score ne descend pas à 0 mais un finish était possible** : demander combien de doubles ont été tentés (0 = pas de tentative, 1-3 = ratés)
- ⚠️ **Clarification nécessaire** : La modale doit-elle s'afficher **à chaque tour** quand le score est ≤ 170, ou uniquement quand le score saisi ne ferme pas le leg ? **Recommandation** : à chaque tour où un double finish était possible et que le joueur n'a PAS fermé. Si le joueur ferme (score = 0), on passe à la modale de checkout existante.

**Prérequis** :
- Nouveau widget modale `DoubleAttemptModal` (boutons horizontaux 0-1-2-3), réutilisable
- Stocker les doubles tentés dans les stats

---

### 5.7 Modale finish si score = 0

**État actuel** : Déjà implémenté via `_askDoubleAttempts`.

**Analyse** : ✅ Vérifier que la modale s'affiche bien ET empêche de continuer sans réponse.

---

### 5.8 Moyenne par 3 fléchettes sur l'ensemble du match

**État actuel** : `_computePlayerAverage` dans `MatchController` fait le calcul — vérifier s'il est resettée à chaque leg.

**Analyse** :
- ⚠️ Actuellement le `roundHistory` est accumulatif mais les `throwScores` dans `PlayerMatch` sont potentiellement reset à chaque leg (dans le bloc de reset). Il faut s'assurer que la moyenne est calculée sur **tous les throws du match**, pas juste le leg courant.
- **Correction** : Accumuler `totalDartsThrown` et `totalScoreAccumulated` à travers les legs au niveau du `PlayerMatch`. La moyenne = `totalScoreAccumulated / (totalDartsThrown / 3)`.

**Prérequis** :
- Ajouter `totalDartsThrown` et `totalPointsScored` à `PlayerMatch` (ne pas les reset entre les legs)

---

### 5.9 Bouton abandon (drapeau rouge)

**Besoin** : Bouton drapeau rouge en haut à droite. Modale : choix du joueur qui abandonne (toggle). Bouton "Abandonner" rouge / "Continuer" vert.

**État actuel** : Aucun bouton d'abandon.

**Analyse** : ✅ Cohérent.

**Prérequis** :
- Nouveau widget `SurrenderModal`
- Ajouter statut `MatchStatus.surrendered` ou utiliser `MatchStatus.finished` avec un flag `surrendered_by`
- Côté backend : ajouter `surrendered_by_player_index` ou `abandoner_id` sur le Match
- Migration SQL : `ALTER TABLE matches ADD COLUMN surrendered_by UUID REFERENCES users(id);`

---

## 6. Page Profil

### 6.1 Refonte des tuiles de stats

**Besoin** :
- Ligne 1 (3 colonnes) : ELO, Avg. pour 3 fléchettes, % réussite au double
- Ligne 2 (2 colonnes) : Victoires, Défaites
- Ligne 3 (3 colonnes) : 180s, 140+, 100+

**État actuel** :
- 4 `StatCard` en Row : ELO, Victoires, Moyenne, Checkout
- `PlayerStats` a `matchesPlayed`, `matchesWon`, `averageScore`, `checkoutRate`, `highest180s`, `bestAverage`
- **140+ et 100+ n'existent pas** dans `PlayerStats` et `PlayerStat` (backend).

**Prérequis** :
- Migration SQL : Ajouter `count_140_plus INT DEFAULT 0` et `count_100_plus INT DEFAULT 0` dans `player_stats`
- Mise à jour entity backend + `StatsService.updateAfterMatch`
- Mise à jour `PlayerStats` Flutter
- "Défaites" = `matchesPlayed - matchesWon` (pas besoin d'un champ supplémentaire)
- Compteur 140+/100+ : À calculer lors du `submitScore` — vérifier quand le score d'un tour ≥ 140 ou ≥ 100

---

### 6.2 Badges : 4 derniers + page "Voir tout"

**État actuel** :
- `BadgeGrid` et `profileState.badges` existent déjà.
- Les badges sont chargés dans `ProfileController`.

**Analyse** :
- Limiter à 4 badges sur la page profil.
- Créer `BadgesListScreen` avec tous les badges (acquis + grisés).
- **Préconisation stockage images badges** : Stocker les images de badges en tant qu'assets locaux dans l'app (`assets/badges/`), car ce sont des images fixes connues d'avance, pas du contenu dynamique utilisateur. Référencer le nom de l'asset en base.
  - Si les badges peuvent être ajoutés dynamiquement par un admin → stocker côté serveur dans `uploads/badges/` et charger via URL.
  - **Recommandation** : Assets locaux pour la V1, migration vers serveur si besoin futur.

**Prérequis** :
- Backend : Table `badges` et `user_badges` si pas déjà fait (vérifier)
- Flutter : Route `AppRoutes.badges` + `BadgesListScreen`

---

### 6.3 Historique des parties (composant réutilisable)

**Besoin** : Même comportement que sur le menu. Composant réutilisable. Au clic → page rapport de partie.

**Analyse** : ✅ Créer un widget `RecentMatchesList` (5 derniers) + bouton "Voir l'historique". Réutilisable dans `HomeScreen` et `ProfileScreen`.

---

### 6.4 Actualisation des statistiques

**Question posée** : Recalculer systématiquement à l'affichage ou à la fin d'un match ranked ?

**Préconisation** : **Recalculer à la fin d'un match ranked**, pas à chaque affichage.
- Raisons :
  - Plus performant (pas de recalcul O(n) à chaque ouverture du profil)
  - Cohérence des données entre les vues
  - Le recalcul systématique est lourd si le joueur a 500+ matchs
- Le service `StatsService.updateAfterMatch` existe déjà et fait exactement cela.
- Ajouter une condition `if (match.is_ranked)` avant d'appeler `updateAfterMatch`.

---

### 6.5 Progression ELO – batch quotidien ?

**Question posée** : Batch nocturne pour alimenter la table ELO du jour J-1 ?

**Préconisation** : **Non, pas de batch quotidien**.
- L'ELO est **déjà mis à jour en temps réel** via `StatsService.processElo` à la fin de chaque match.
- La table `elo_history` enregistre déjà chaque changement avec le `created_at`.
- Pour le graphique de progression : agréger côté backend avec `GROUP BY DATE(created_at)` pour obtenir l'ELO journalier. Endpoint : `GET /stats/me/elo-history?granularity=daily`.
- **Fuseau horaire** : Stocker tout en UTC (c'est déjà le cas avec `timestamptz`). Convertir côté Flutter avec le fuseau local de l'appareil.
- Si plus tard les performances posent problème (> 100k entrées), alors créer une table `elo_daily_snapshots` alimentée par un CRON. Mais en V1 ce n'est pas nécessaire.

---

### 6.6 Bouton QR Code en haut à gauche du profil

**Besoin** : Icône QR verte → affiche le QR Code du profil (valeur = UUID utilisateur).

**Analyse** : ✅ Simple. Utiliser un package comme `qr_flutter` pour générer le QR en widget.

**Prérequis** :
- Package Flutter : `qr_flutter`
- Dialog/Modal affichant le QR généré à partir de `user.id`

---

## 7. Page Contact

### 7.1 Bouton raccourci lancer une partie

**Besoin** : Icône raccourci → redirige vers la page Jouer avec adversaire pré-rempli (mode "Inviter Ami" + nom affiché).

**État actuel** : `ContactsScreen` et `ContactsChatScreen` existent.

**Analyse** :
- Passer l'adversaire en `extra` dans la route vers `GameSetupScreen`.
- Le `GameSetupScreen` doit accepter un `ContactModel?` en paramètre optionnel pour pré-sélectionner l'adversaire et le mode.

**Prérequis** :
- Modifier la route `gameSetup` pour accepter un extra plus riche (objet avec `mode` + `opponent`)
- Adapter `GameSetupScreen` pour lire et pré-remplir

---

### 7.2 Retirer label du bouton CHAT

**Analyse** : ✅ Trivial. Retirer le `Text` et garder uniquement l'icône.

---

## 8. Page Rapport de Partie

### 8.1 Création de la page

**Besoin** : Deux colonnes (utilisateur / adversaire). Stats : moyenne, legs gagnés, 180s, 140+, 100+. Timeline legs/sets. Score final sets en haut.

**État actuel** : **Aucune page de rapport n'existe**.

**Analyse** :
- Nouvelle page `MatchReportScreen` accessible via route `AppRoutes.matchReport = '/match/:id/report'`.
- Les données viennent de `GET /matches/:id` qui retourne le match complet avec sets, legs, throws.
- Les stats individuelles doivent être calculées côté backend ou Flutter à partir des données du match.

**Prérequis** :
- Nouvelle route + page Flutter
- Backend : Vérifier que `GET /matches/:id` retourne assez de données (throws par joueur, legs gagnés, etc.)
- Possiblement ajouter un endpoint `GET /matches/:id/report` qui retourne des données agrégées
- Timeline des legs/sets : widget custom (similaire à un stepper horizontal)

---

## 9. Mode Spectateur

### 9.1 Reprise de la page Game en lecture seule

**Besoin** : Voir une partie en cours sans pouvoir interagir.

**État actuel** : `MatchLiveScreen` est conçue pour le joueur actif.

**Analyse** :
- Option A : Créer un `MatchSpectatorScreen` dédié (plus propre)
- Option B : Ajouter un mode `isSpectator` à `MatchLiveScreen` qui masque les contrôles
- **Recommandation** : Option B (moins de duplication). Passer un paramètre `spectator: true` via la route.
- Les données arrivent via WebSocket (`match.gateway` → `join_match` + écoute des events).

**Prérequis** :
- Nouvelle route `AppRoutes.matchSpectator = '/match/:id/spectate'`
- Adaptation de `MatchLiveScreen` ou création de `MatchSpectatorScreen`
- Vérifier que le gateway permet à un non-joueur de rejoindre un match room

---

## 10. Tournois

### 10.1 Modèle de données tournoi (refonte majeure)

**État actuel** : Le `Tournament` entity existe avec des champs basiques. **Mais le modèle actuel est orienté "clubs" (inscription par club), pas "joueurs individuels"** comme décrit dans les besoins.

**⚠️ INCOHÉRENCE MAJEURE** : Les besoins parlent de joueurs individuels (inscription individuelle, poules de joueurs, bracket de joueurs), mais le backend actuel gère des inscriptions par **club** (`TournamentRegistration` avec `club_id`).

**Restructuration nécessaire** :
```
tournaments
  - id UUID PK
  - owner_id UUID FK → users (responsable)
  - name VARCHAR(150)
  - status ENUM ('upcoming', 'in_progress', 'completed')
  - min_players INT
  - max_players INT
  - start_date TIMESTAMPTZ
  - end_date TIMESTAMPTZ
  - tournament_mode ENUM ('pools_and_bracket', 'bracket_only')
  - pool_size INT (nullable, si pools)
  - pool_qualifiers INT (nullable, nombre de qualifiés par poule)
  - club_id UUID FK → clubs (nullable, pour l'adresse)
  - venue_address TEXT (nullable, terrain neutre)
  - adapt_bracket_odd BOOLEAN DEFAULT false
  - game_mode ENUM ('301', '501', '701')
  - best_of_legs INT
  - total_sets INT
  - set_gap INT DEFAULT 1 (écart pour gagner un match)
  - leg_gap INT DEFAULT 1 (écart pour gagner un set)
  - finish_type ENUM ('double_out', 'single_out', 'master_out')
  - is_private BOOLEAN DEFAULT false
  - password_hash VARCHAR (nullable)
  - min_elo INT (nullable)
  - min_avg_score NUMERIC (nullable)
  - winner_id UUID FK → users (nullable)
  - created_at, updated_at

tournament_registrations
  - id UUID PK
  - tournament_id UUID FK
  - user_id UUID FK (joueur, pas club)
  - registered_at TIMESTAMPTZ
  - status ENUM ('registered', 'disqualified')
  - disqualified_reason TEXT (nullable)

tournament_pools
  - id UUID PK
  - tournament_id UUID FK
  - pool_name VARCHAR (A, B, C...)
  - pool_number INT

tournament_pool_players
  - id UUID PK
  - pool_id UUID FK
  - user_id UUID FK
  - wins INT DEFAULT 0
  - losses INT DEFAULT 0
  - leg_diff INT DEFAULT 0
  - rank INT (nullable)

tournament_bracket_matches
  - id UUID PK
  - tournament_id UUID FK
  - round INT (1 = finale, 2 = demi, etc. ou inversé)
  - position INT (position dans le round)
  - player1_id UUID FK (nullable)
  - player2_id UUID FK (nullable)
  - match_id UUID FK → matches (nullable, lié au match réel)
  - winner_id UUID FK (nullable)
  - status ENUM ('pending', 'in_progress', 'completed', 'walkover')
```

**Prérequis** :
- Refonte complète de l'entity `Tournament` et des DTOs
- Nouvelles tables/entities pour pools et bracket
- Suppression de `TournamentRegistration` par club → par joueur
- Algorithme de génération des poules (random distribution)
- Algorithme de génération du bracket (seeding basé sur le classement des poules)
- Gestion du nombre impair (bye/exempt)

### 10.2 Pages Flutter nécessaires

1. **`TournamentsListScreen`** : Liste des tournois (5 plus proches en date/distance)
2. **`TournamentCreateScreen`** : Formulaire de création
3. **`TournamentDetailScreen`** : Description + onglets (Joueurs, Poules, Bracket)
4. **Widget Bracket** : Composant visuel de bracket (recommandation : `flutter_bracket` package ou composant custom avec `InteractiveViewer` + carrousel de rounds)

### 10.3 Disqualification et gestion

**Prérequis** :
- Ajout de `has_tournament_abandon BOOLEAN DEFAULT false` sur `users`
- Migration SQL
- Logique backend de propagation des victoires par défaut

### 10.4 Match en phase de tournoi

- Les matchs de tournoi ont `tournament_id` déjà dans le modèle.
- Ajouter `tournament_bracket_match_id` pour lier le match au bracket.
- À la fin d'un match de tournoi : mettre à jour le bracket, calculer le prochain adversaire.

---

## 🔴 Résumé des Manques Critiques Identifiés

| # | Manque | Impact |
|---|--------|--------|
| 1 | Pas d'endpoint upload avatar | Bloque la photo de profil |
| 2 | Pas de champ `is_ranked` sur `matches` | Bloque le filtrage ranked |
| 3 | Pas de pagination offset sur `GET /matches/me` | Bloque l'historique paginé |
| 4 | Pas de recherche text/geo sur `GET /clubs` | Bloque la recherche clubs |
| 5 | Pas de champ `dart_boards_count` sur `clubs` | Bloque l'affichage clubs |
| 6 | Logique BO incorrecte (legs_per_set) | Bug fonctionnel majeur |
| 7 | Pas de 140+/100+ dans `player_stats` | Bloque les stats profil |
| 8 | Modèle tournoi orienté clubs au lieu de joueurs | Refonte nécessaire |
| 9 | Pas de table badges/user_badges structurée | Bloque les badges |
| 10 | Package QR scanner déprécié | À remplacer |
| 11 | Pas de page rapport de partie | Fonctionnalité manquante |
| 12 | Pas de mode spectateur | Fonctionnalité manquante |

---

## 🟢 Points Déjà Couverts par le Code Existant

- Avatar URL dans le modèle User ✅
- WebSocket pour le temps réel ✅
- Invitation de match ✅
- Modèle Match avec sets/legs/throws ✅
- Système ELO ✅
- Navigation GoRouter ✅
- Riverpod state management ✅
- Geolocalisation (Geolocator) ✅
- QR Code entity backend ✅
