# Codex Prompts — Dart District v2 Sprint

> Ce document contient les prompts structurés pour GPT-5 Codex, découpés par ticket.
> Chaque prompt est autonome et contient le contexte nécessaire.

---

## TICKET 1 — Guest User : Enregistrement local uniquement (pas de persistance BDD)

### Contexte projet
- **Stack** : Flutter (Riverpod, GoRouter) + NestJS (TypeORM, PostgreSQL)
- **Fichiers concernés** :
  - `lib/features/auth/data/auth_repository.dart` — méthode `continueAsGuest()` (L37-46)
  - `lib/features/auth/models/user_model.dart` — propriété `isGuest` (basée sur `id == 'guest'`)
  - `backend/src/modules/auth/auth.service.ts` — méthode `guestLogin()` (L127-138)
  - `backend/src/modules/auth/auth.controller.ts` — endpoint `POST /auth/guest` (L64-69)

### Objectif
Modifier le flux Guest pour que l'utilisateur invité soit créé **uniquement côté client Flutter** sans aucune persistance en base de données PostgreSQL.

### Spécifications détaillées

#### Backend
1. Modifier `POST /auth/guest` pour qu'il retourne un JWT éphémère (durée de vie = session, ex: 24h) **sans créer d'entrée dans la table `users`**.
2. Le JWT guest doit contenir un payload identifiable : `{ sub: 'guest', is_guest: true, username: 'Invité' }`.
3. Supprimer la logique de création d'un `User` avec `is_guest: true` dans `auth.service.ts > guestLogin()`.
4. Ajouter dans le `JwtStrategy` (guard) la gestion du cas `sub === 'guest'` : ne pas chercher en BDD, retourner un objet user minimal.
5. Les endpoints protégés par `@UseGuards(JwtAuthGuard)` doivent rester accessibles en lecture pour les guests (GET clubs, GET tournois, GET map), mais bloquer les écritures sensibles (POST match ranked, POST club/join, POST tournament/register, DELETE users/me).

#### Frontend (Flutter)
6. Dans `auth_repository.dart`, modifier `continueAsGuest()` :
   - Appeler `POST /auth/guest` pour obtenir le token éphémère
   - Créer un `UserModel` local avec `id: 'guest'`, `username: 'Invité'`, `isGuest: true`
   - Stocker le token via `TokenStorage.saveTokens()` pour que les appels API en lecture fonctionnent
7. S'assurer que `UserModel.isGuest` est dérivé de `id == 'guest'` (déjà le cas).

### Contraintes
- Le guest ne doit générer AUCUNE ligne dans les tables `users`, `auth_providers`, `refresh_tokens`
- Les tokens guest ne doivent pas être rafraîchissables (pas de refresh token)
- Le guest qui ferme et relance l'app doit repasser par l'écran de connexion

### Tests attendus
- Vérifier qu'après `continueAsGuest()`, aucune entrée n'est créée en BDD
- Vérifier que les appels GET (clubs, tournois, map) fonctionnent avec le token guest
- Vérifier que les appels POST protégés retournent 403 pour un guest

---

## TICKET 2 — Restrictions UI pour l'utilisateur Guest

### Contexte
L'utilisateur guest (`UserModel.isGuest == true`) doit avoir un accès restreint à certaines fonctionnalités UI.

### Fichiers à modifier

#### 2.1 — Contacts : Masquer le bouton "Ajouter"
- **Fichier** : `lib/features/contacts/presentation/contacts_screen.dart`
- **Widget** : `_SearchResultTile` (L265-288)
- **Action** : Conditionner l'affichage du `ElevatedButton('Ajouter')` avec `if (!currentUser.isGuest)`
- **Accès au user** : Utiliser le provider Riverpod `authProvider` ou `currentUserProvider` pour obtenir `isGuest`

#### 2.2 — Game Setup : Seul "VS Invité" accessible
- **Fichier** : `lib/features/play/presentation/game_setup_screen.dart`
- **Widget** : GridView des 4 `_OptionCard` (L88-138)
- **Action** :
  - Si `isGuest` : n'afficher que la carte "Vs Invite" (ou griser/désactiver les 3 autres)
  - Sélectionner "Vs Invite" par défaut pour les guests
  - Masquer le toggle ranked/casual (les guests ne peuvent pas jouer en ranked)

#### 2.3 — Clubs : Masquer les boutons "Rejoindre"
- **Fichier** : `lib/features/club/presentation/club_detail_screen.dart`
- **Action** : Conditionner le bouton de rejoindre le club avec `if (!currentUser.isGuest)`
- **Note** : L'écran de détail club est actuellement un placeholder — le bouton sera à masquer dès son implémentation

#### 2.4 — Tournois : Masquer le bouton "S'inscrire"
- **Fichier** : `lib/features/tournaments/presentation/tournament_detail_screen.dart`
- **Widget** : `FilledButton` "Rejoindre" / "Se désinscrire" (L186-198)
- **Action** : Wrapper dans `if (!currentUser.isGuest)` ou afficher un message "Connectez-vous pour participer"

#### 2.5 — Paramètres : Masquer "Supprimer le compte"
- **Fichier** : `lib/features/profile/presentation/settings_screen.dart`
- **Widget** : `ElevatedButton.icon` "Supprimer mon compte" (L75-94)
- **Action** : `if (!currentUser.isGuest)` pour masquer le bouton

#### 2.6 — Profil : Masquer le bouton QR Code
- **Fichier** : `lib/features/profile/presentation/profile_screen.dart`
- **Widget** : `IconButton` QR code (L307-314)
- **Action** : Modifier la condition `if (isOwnProfile)` en `if (isOwnProfile && !currentUser.isGuest)`

#### 2.7 — Menu : "Créer tournoi" inaccessible
- **Fichier** : `lib/features/home/presentation/home_screen.dart`
- **Widget** : QuickAction "Créer tournoi" (L103-109)
- **Action** : Si `isGuest`, masquer le bouton ou le désactiver avec un tooltip "Connectez-vous pour créer un tournoi"

### Pattern recommandé
Créer un helper réutilisable :
```dart
// lib/shared/utils/guest_guard.dart
bool isGuestUser(WidgetRef ref) {
  final user = ref.watch(currentUserProvider);
  return user?.isGuest ?? false;
}
```

### Tests attendus
- Navigation en tant que guest → vérifier l'absence de chaque bouton listé
- Navigation en tant que user connecté → vérifier la présence de chaque bouton

---

## TICKET 3 — Localisation des clubs sur la carte

### Contexte
- Le backend a déjà les champs `latitude`, `longitude` dans l'entité `Club`
- La carte utilise `flutter_map` + `vector_map_tiles_pmtiles` pour afficher les zones IRIS
- Les tiles PMTiles contiennent les contours IRIS de France
- L'API hit-test `/territories/map/hit` résout déjà des coordonnées en `code_iris`

### 3.1 — Autocomplétion d'adresse Google Places API (création de club)

#### Fichiers concernés
- `lib/features/club/presentation/club_create_screen.dart` (L91-102 : champ adresse)
- Nouveau service : `lib/features/club/data/places_service.dart`
- Config : `config/flutter.env.json` (ajouter la clé API Google)

#### Spécifications
1. Remplacer le `TextFormField` adresse par un widget d'autocomplétion :
   - Utiliser le package `google_places_flutter` ou appeler directement l'API REST Google Places (New)
   - Endpoint : `https://places.googleapis.com/v1/places:autocomplete` (Places API New)
   - Puis `Place Details (Essentials)` pour récupérer `location.latitude`, `location.longitude`, `formattedAddress`
2. La clé API Google doit être stockée dans `config/flutter.env.json` et chargée par le service de configuration existant
3. À la sélection d'une adresse :
   - Remplir automatiquement les champs `address`, `city`
   - Stocker `latitude` et `longitude` dans le state du formulaire
4. Restreindre l'autocomplétion à la France (`componentRestrictions: { country: 'fr' }`)

### 3.2 — Géolocalisation et association territoire IRIS (enregistrement du club)

#### Fichiers concernés
- `backend/src/modules/clubs/clubs.service.ts`
- `backend/src/modules/clubs/entities/club.entity.ts` (ajouter champ `code_iris`)
- `backend/src/modules/territories/territories.service.ts`

#### Spécifications
1. **Ajouter `code_iris: string | null`** à l'entité `Club` (migration SQL nécessaire)
2. Au `POST /clubs` (création) :
   - Si `latitude` et `longitude` sont fournis par le frontend (via Google Places) :
     - Utiliser la Geolocation API (Google) pour confirmer/affiner les coordonnées si nécessaire
     - Faire un hit-test spatial en SQL (ST_Contains avec les géométries IRIS) pour trouver le `code_iris` contenant le point `(lat, lng)`
     - Stocker le `code_iris` dans le club
   - Si pas de coordonnées : `code_iris` reste `null`
3. Créer une migration SQL :
```sql
ALTER TABLE clubs ADD COLUMN code_iris VARCHAR(9) NULL;
CREATE INDEX idx_clubs_code_iris ON clubs(code_iris);
```

### 3.3 — Filtrer les tiles PMTiles pour n'afficher que les zones avec clubs

#### Fichiers concernés
- `backend/src/modules/territories/territories.controller.ts`
- `backend/src/modules/territories/territories.service.ts`
- `lib/features/map/presentation/map_screen.dart`
- `lib/features/map/controller/map_controller.dart`

#### Spécifications
1. **Nouveau endpoint backend** : `GET /territories/clubs/zones`
   - Retourne la liste des `code_iris` ayant au moins un club (`SELECT DISTINCT code_iris FROM clubs WHERE code_iris IS NOT NULL`)
   - Retourne aussi les infos territoire associées (nom, status)

2. **Frontend** : Modifier le chargement de la carte :
   - Récupérer la liste des `code_iris` avec clubs via le nouvel endpoint
   - Filtrer le rendu des tiles pour ne colorer/afficher que les zones dont le `code_iris` est dans cette liste
   - Les autres zones IRIS restent invisibles ou très transparentes

### 3.4 — Modale info territoire au clic sur une zone

#### Fichiers concernés
- `lib/features/map/presentation/map_screen.dart`
- Nouveau widget : `lib/features/map/presentation/widgets/territory_info_modal.dart`

#### Spécifications
1. Au clic/tap sur une tile zone colorée :
   - Faire un hit-test pour identifier le `code_iris`
   - Afficher une modale (BottomSheet ou Dialog) avec :
     - Nom du territoire (IRIS)
     - Code IRIS
     - Statut du territoire (available, conquered, etc.)
     - Nom du club propriétaire (si conquered)
   - Bouton "Fermer"

### 3.5 — Afficher les clubs sur la carte avec icône cliquable

#### Fichiers concernés
- `lib/features/map/presentation/map_screen.dart`
- `lib/features/map/controller/map_controller.dart`
- Nouveau widget : `lib/features/map/presentation/widgets/club_marker_modal.dart`
- Nouveau endpoint ou extension de l'existant

#### Spécifications
1. **Backend** : `GET /clubs/map` — retourne les clubs avec coordonnées :
   ```json
   [{ "id": "uuid", "name": "Club X", "latitude": 48.8, "longitude": 2.3 }]
   ```

2. **Frontend** — Couche de marqueurs clubs :
   - Ajouter un `MarkerLayer` par-dessus la couche tiles/zones
   - Chaque club = un `Marker` avec une icône de cible/fléchette (🎯) ou `Icons.gps_fixed`
   - Taille du marqueur : 40x40px, hitbox élargie : 60x60px (`GestureDetector` avec padding)
   - Le marqueur doit être rendu **au-dessus** des zones tiles (z-index via l'ordre des layers)

3. **Modale club au clic** :
   - Afficher un `BottomSheet` ou un `Tooltip` avec :
     - Nom du club
     - Lien "Voir le club" → `context.push(AppRoutes.clubDetail, extra: clubId)`
   - Si plusieurs clubs au même endroit (rare) : afficher une liste

### Contraintes techniques
- Utiliser la **Places API (New)** de Google, pas l'ancienne Places SDK
- Les appels Google Places doivent passer côté client Flutter (pas via le backend) pour réduire la latence d'autocomplétion
- Protéger la clé API Google avec des restrictions (HTTP referrers, package name)
- Les tiles PMTiles restent servies depuis le fichier statique existant ; seul le filtrage change

---

## TICKET 4 — Correctif : Inscription SSO non fonctionnelle

### Contexte du bug
- La connexion SSO (Google/Apple) sur la page login fonctionne pour les comptes existants
- L'inscription SSO (nouveau compte) ne fonctionne pas : le login récupère le token mais ne chain pas vers l'inscription
- Le backend renvoie `is_new_user: true` mais le frontend ne récupère pas les infos pour créer le profil

### Fichiers concernés
- `lib/features/auth/data/auth_repository.dart` — `loginWithGoogle()`, `loginWithApple()` (L48-87)
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/sso_username_screen.dart`
- `backend/src/modules/auth/auth.service.ts` — `socialLogin()` (L95-123)
- `backend/src/modules/auth/auth.controller.ts` — `POST /auth/google`, `POST /auth/apple`

### Spécifications de correction

#### Backend
1. Dans `socialLogin()`, quand un nouveau user est créé :
   - Récupérer l'email depuis le token Google/Apple décodé
   - Hasher un mot de passe aléatoire (ou null, puisque l'auth passe par le provider SSO)
   - Retourner dans la réponse : `{ access_token, refresh_token, is_new_user: true, email, provider }`
   - Le user est créé avec un username temporaire (`Joueur_` + UUID slice) — c'est déjà le cas

#### Frontend
2. Dans `loginWithGoogle()` / `loginWithApple()` :
   - Vérifier le flag `is_new_user` dans la réponse
   - Si `is_new_user == true` :
     - Stocker les tokens (déjà fait)
     - Router vers `AppRoutes.subscriptionStep1` (pas `ssoUsernameSetup`) pour le flux complet d'inscription
     - Passer l'email récupéré en paramètre pour pré-remplir si nécessaire
   - Si `is_new_user == false` :
     - Connexion normale, router vers `AppRoutes.home`

3. Dans le flow d'inscription (step1 → step2 → step3) :
   - Détecter si on vient du SSO (flag ou paramètre de route)
   - Si SSO : ne pas demander email/password (déjà authentifié), ne demander que username, level, hand
   - Le `PATCH /users/me` final met à jour le username, level, preferred_hand

### Cas limite à traiter
- Si l'utilisateur commence l'inscription SSO mais quitte avant de finir step1 :
  - Le user existe en BDD avec username temporaire
  - Au prochain login SSO, `is_new_user` sera `false` mais le username sera `Joueur_xxx`
  - Détecter ce cas (username starts with "Joueur_") et relancer le flow d'inscription

### Tests attendus
- Login Google avec compte existant → accès direct au home
- Login Google avec nouveau compte → redirection vers step1 → step2 → step3 → home
- Login Apple avec nouveau compte → même flow
- Interruption mid-flow → relance correcte au prochain login

---

## TICKET 5 — Correctif : Page conditions d'utilisation (step 2) non scrollable

### Contexte du bug
La page `subscription_step2_screen.dart` contient 4 cartes de conditions d'utilisation dans un `Column` qui dépasse la hauteur de l'écran. L'absence de `SingleChildScrollView` empêche de scroller vers le bouton "Commencer".

### Fichier
`lib/features/auth/presentation/subscription_step2_screen.dart`

### Correction
1. Wrapper le contenu principal (Column contenant les 4 `_RuleCard` + checkbox + bouton) dans un `SingleChildScrollView`
2. Ou mieux : utiliser un `CustomScrollView` avec des `SliverToBoxAdapter` pour un scroll plus fluide
3. S'assurer que le header (back + titre + "Refuser") et la progress bar restent **fixés en haut** (pas dans le scroll)
4. Seul le contenu en dessous (cards + checkbox + bouton) doit scroller

### Structure cible
```dart
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        // FIXE : Header + Progress bar
        _buildHeader(),
        _buildProgressBar(),
        // SCROLLABLE : Contenu
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTitle(),
                _RuleCard(...), // x4
                _buildCheckbox(),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
)
```

### Tests attendus
- Sur petit écran (SE, 5.5") : scroll fluide, bouton accessible
- Sur grand écran (14 Pro Max) : contenu visible sans scroll si possible
- Le header et la progress bar restent visibles pendant le scroll

---

## TICKET 6 — Correctif : Login SSO → Compte inexistant → Chaîner avec inscription

### Contexte du bug
Si un utilisateur tente de se connecter via SSO (Google/Apple) sur la page login, et que le compte associé à l'email n'existe pas en BDD, il faut automatiquement enchaîner sur le processus d'inscription au lieu d'afficher une erreur.

### Lien avec TICKET 4
Ce ticket est un sous-cas du TICKET 4. La résolution du TICKET 4 couvre ce cas :
- Le backend `socialLogin()` crée automatiquement un user quand l'email n'existe pas
- Il retourne `is_new_user: true`
- Le frontend redirige vers le flow d'inscription

### Vérification supplémentaire
1. S'assurer que le backend ne retourne PAS une erreur 404/401 quand l'email SSO n'existe pas
2. Le flow doit être transparent : l'utilisateur clique "Connexion avec Google" → si pas de compte → création automatique + redirection step1
3. Aucun message d'erreur ne doit apparaître à l'utilisateur dans ce cas

### Tests attendus
- Clic "Se connecter avec Google" avec email inconnu → redirection vers inscription step1
- Clic "Se connecter avec Apple" avec email inconnu → redirection vers inscription step1
- Pas de message d'erreur intermédiaire

---

# Ordre d'exécution recommandé

| Priorité | Ticket | Complexité | Dépendances |
|----------|--------|------------|-------------|
| 1        | TICKET 5 | Faible    | Aucune      |
| 2        | TICKET 4 + 6 | Moyenne | Aucune   |
| 3        | TICKET 1 | Moyenne   | Aucune      |
| 4        | TICKET 2 | Faible    | TICKET 1    |
| 5        | TICKET 3.1-3.2 | Haute | Config Google API |
| 6        | TICKET 3.3-3.5 | Haute | TICKET 3.1-3.2 |

---

# Conventions du projet à respecter

- **Flutter** : Architecture feature-based (`lib/features/<feature>/{data,models,presentation,controller}`)
- **State management** : Riverpod (providers, StateNotifier)
- **Navigation** : GoRouter (`context.push()`, `context.go()`)
- **API calls** : Dio via `_api` dans les repositories
- **Design** : `AppColors` pour les couleurs, `_inputDecoration()` pour les champs
- **Backend** : NestJS, TypeORM, PostgreSQL, JWT auth
- **Migrations SQL** : Fichiers numérotés dans `backend/sql/` (prochain : `015_xxx.sql`)
- **Noms de variables** : camelCase (Flutter), snake_case (backend/SQL)
- **Langue UI** : Français
