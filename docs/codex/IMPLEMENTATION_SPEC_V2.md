# Dart District — Spécification d'implémentation V2

> Document de référence pour l'implémentation de tous les besoins listés ci-dessous.
> Chaque section est autonome et indique les fichiers source et cibles, le comportement attendu, et les dépendances croisées.

---

## Table des matières

1. [Analyse de cohérence et factorisation](#1-analyse-de-cohérence-et-factorisation)
2. [Conventions et règles transverses](#2-conventions-et-règles-transverses)
3. [CHANTIER A — Refonte inscription Step 2 → CONDITIONS](#3-chantier-a--refonte-inscription-step-2--conditions)
4. [CHANTIER B — Écran tutoriel post-inscription](#4-chantier-b--écran-tutoriel-post-inscription)
5. [CHANTIER C — Bouton Rafraîchir tournois](#5-chantier-c--bouton-rafraîchir-tournois)
6. [CHANTIER D — Tuile contact : icône message](#6-chantier-d--tuile-contact--icône-message)
7. [CHANTIER E — Profil visiteur (vue publique)](#7-chantier-e--profil-visiteur-vue-publique)
8. [CHANTIER F — Navigation contacts → profil joueur](#8-chantier-f--navigation-contacts--profil-joueur)
9. [CHANTIER G — Navigation tournoi → profil joueur](#9-chantier-g--navigation-tournoi--profil-joueur)
10. [CHANTIER H — Détail tournoi : ordre des onglets](#10-chantier-h--détail-tournoi--ordre-des-onglets)
11. [CHANTIER I — Tournoi : club partenaire et adresse](#11-chantier-i--tournoi--club-partenaire-et-adresse)
12. [CHANTIER J — Détail tournoi : bouton Démarrer conditionnel](#12-chantier-j--détail-tournoi--bouton-démarrer-conditionnel)
13. [CHANTIER K — Suppression de compte](#13-chantier-k--suppression-de-compte)
14. [CHANTIER L — Bloquer un utilisateur](#14-chantier-l--bloquer-un-utilisateur)
15. [CHANTIER M — Actions sur profil visité (bloquer/ami)](#15-chantier-m--actions-sur-profil-visité-bloqueami)
16. [CHANTIER N — Page À propos / Patch notes](#16-chantier-n--page-à-propos--patch-notes)
17. [Ordre d'implémentation recommandé](#17-ordre-dimplémentation-recommandé)
18. [Checklist de validation](#18-checklist-de-validation)

---

## 1. Analyse de cohérence et factorisation

### Besoins interdépendants identifiés

| Groupe | Besoins liés | Factorisation |
|--------|-------------|---------------|
| **Profil visiteur** | Clic contact → profil, clic joueur tournoi → profil, boutons bloquer/ami sur profil visité | Un seul écran `ProfileScreen` paramétré avec `userId` optionnel + `isOwnProfile` flag |
| **Bloquer utilisateur** | Bloquer depuis demande d'ami, bloquer depuis profil visité | Un seul backend endpoint `POST /contacts/block`, un seul service method `blockUser()`, une seule modale de confirmation réutilisable |
| **Tournoi ↔ Club** | Club partenaire à la création, affichage club + adresse dans infos tournoi | Un seul champ `club_id` ajouté à l'entité `Tournament`, résolu en club name + address côté API |
| **Inscription flow** | Step 2 CONDITIONS → création user → écran tutoriel → home | Séquentiel : Step2 crée le user, redirige vers nouveau Step3 tutoriel, skip → home |

### Incohérences corrigées

1. **Step 2 actuel** crée le user ET affiche un tutoriel → le besoin demande de séparer en 2 écrans (CONDITIONS + Tutoriel).
2. **SubscriptionStep2** redirige actuellement vers `/home` après acceptation → sera redirigé vers un nouveau `/subscription/step3` (tutoriel).
3. **Le bouton « Démarrer le tournoi »** est déjà conditionné par `isCreator` dans `_AdminActions` → le besoin est déjà partiellement implémenté, il faut juste vérifier que `_AdminActions` ne s'affiche pas du tout si `!isCreator` (c'est le cas, ligne `if (isCreator)` existe).

---

## 2. Conventions et règles transverses

### Style et performance

- **Widgets** : pas de logique métier, uniquement présentation.
- **State** : Riverpod `StateNotifier` ou `AsyncNotifier` avec immutables.
- **Navigation** : GoRouter avec `context.push()` (pile), `context.go()` (remplacement).
- **Modales de confirmation** : factoriser en une seule fonction utilitaire `showConfirmDialog()`.
- **Backend** : toujours DTO + Service + Controller. Pas de logique dans les controllers.
- **Migrations** : un fichier SQL par chantier nécessitant un changement de schéma.
- **Portabilité** : pas de code platform-specific sauf via `kIsWeb` / `Platform`. Utiliser `url_launcher` (déjà en dépendance) pour les liens externes.

### Fonction utilitaire partagée à créer

Fichier : `lib/shared/widgets/confirm_dialog.dart`

```dart
import 'package:flutter/material.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  Color? confirmColor,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: confirmColor != null
              ? FilledButton.styleFrom(backgroundColor: confirmColor)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
```

Ce widget sera utilisé par : suppression de compte, blocage utilisateur, suppression d'amitié.

---

## 3. CHANTIER A — Refonte inscription Step 2 → CONDITIONS

### Contexte

- Fichier actuel : `lib/features/auth/presentation/subscription_step2_screen.dart`
- L'écran actuel mélange tutoriel de jeu + création du compte.

### Comportement cible

1. **Titre** : remplacer `TUTORIEL` par `CONDITIONS`.
2. **Bouton « Passer »** → renommé en `Refuser`. Au clic → retour à l'écran précédent (`context.go(AppRoutes.subscriptionStep1, extra: widget.payload)`).
3. **Contenu** : remplacer les 4 `_RuleCard` actuelles par les conditions d'utilisation suivantes :

| # | Icône | Titre | Description |
|---|-------|-------|-------------|
| 1 | `Icons.photo_camera_outlined` | Utilisation de vos données | L'application enregistre les photos de profil et messages que vous partagez afin de fournir les fonctionnalités sociales du service. |
| 2 | `Icons.gavel` | Contenus inappropriés | La diffusion de messages haineux, discriminatoires ou d'images à caractère inapproprié est strictement interdite. |
| 3 | `Icons.shield_outlined` | Modération et sanctions | Le non-respect de ces règles entraînera une modération pouvant aller jusqu'au bannissement du compte, voire au blocage de la signature physique de l'appareil. | `warning: true` |
| 4 | `Icons.emoji_events_outlined` | Engagement en tournoi | S'inscrire à un tournoi implique de jouer sur place. En cas d'absence, un malus est appliqué pouvant interdire temporairement ou définitivement l'inscription aux tournois. Et en plus, c'est la honte. | `warning: true` |

4. **Checkbox** : label → `J'ai lu et j'accepte les conditions d'utilisation.`
5. **Bouton principal** : label → `Commencer` (au lieu de `Acceder au dashboard`). Désactivé si `!_acceptedRules`.
6. **Au clic sur « Commencer »** : c'est ICI que `signUpWithEmail()` est appelé (inchangé, c'est déjà le cas).
7. **Après succès** : rediriger vers `/subscription/step3` (nouveau) au lieu de `/home`.

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/auth/presentation/subscription_step2_screen.dart` | Modifier contenu, labels, redirect |
| `lib/core/config/app_routes.dart` | Ajouter route `/subscription/step3` |

### Listener de redirection

Modifier le `ref.listen` existant :

```dart
ref.listen<AuthState>(authControllerProvider, (previous, next) {
  if (next.status == AuthStatus.authenticated) {
    context.go(AppRoutes.subscriptionStep3);
  }
});
```

---

## 4. CHANTIER B — Écran tutoriel post-inscription

### Contexte

Nouvel écran affiché uniquement après la création réussie du compte.

### Route

- Constante : `static const String subscriptionStep3 = '/subscription/step3';`
- Ajouter dans `publicRoutes`.

### Fichier à créer

`lib/features/auth/presentation/subscription_step3_screen.dart`

### Contenu (4 cartes + bouton skip)

| # | Icône | Titre | Description |
|---|-------|-------|-------------|
| 1 | `Icons.sports_bar` | Jouer en présentiel | Dart District est conçu pour jouer en présentiel. Rencontrez des fans de fléchettes autour d'une cible et d'une bière ! |
| 2 | `Icons.sports_esports` | Modes de jeu | Jouez au 301, 501, Cricket et plus encore avec vos amis ou vos rivaux. |
| 3 | `Icons.groups` | Clubs et tournois | Inscrivez-vous dans le club le plus proche et défendez votre titre contre d'autres clubs en participant à des tournois. |
| 4 | `Icons.qr_code_scanner` | Batailles de territoire | Flashez le QR code près des cibles dans les clubs pour lancer une bataille de territoire ! |

### Bouton

- Texte : `C'est parti !` (primaire, pleine largeur)
- Au clic : `context.go(AppRoutes.home)`

### Header

- Pas de bouton retour.
- Titre : `BIENVENUE` style Rajdhani 30pt bold.
- Un bouton `Passer` en haut à droite → `context.go(AppRoutes.home)`.

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/auth/presentation/subscription_step3_screen.dart` | Créer |
| `lib/core/config/app_routes.dart` | Ajouter `subscriptionStep3`, route, et dans `publicRoutes` |

---

## 5. CHANTIER C — Bouton Rafraîchir tournois

### Fichier

`lib/features/tournaments/presentation/tournaments_list_screen.dart`

### Action

Supprimer le bloc entier :

```dart
Center(
  child: OutlinedButton.icon(
    onPressed: _refresh,
    icon: const Icon(Icons.refresh_rounded),
    label: const Text('Rafraichir'),
  ),
),
```

Le pull-to-refresh via `RefreshIndicator` dans `_TournamentTab.onRefresh` est déjà en place.

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/tournaments/presentation/tournaments_list_screen.dart` | Supprimer le OutlinedButton |

---

## 6. CHANTIER D — Tuile contact : icône message

### Fichier

`lib/features/contacts/presentation/contacts_screen.dart` — widget `_FriendTile`

### Action

Remplacer le `ElevatedButton.icon` (Chat) par un simple `IconButton` :

```dart
// AVANT
ElevatedButton.icon(
  onPressed: onOpenChat,
  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
  label: const Text('Chat'),
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.background,
  ),
),

// APRÈS
IconButton(
  onPressed: onOpenChat,
  icon: const Icon(
    Icons.chat_bubble_outline_rounded,
    color: AppColors.primary,
    size: 22,
  ),
  tooltip: 'Message',
),
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/contacts/presentation/contacts_screen.dart` | Modifier `_FriendTile` |

---

## 7. CHANTIER E — Profil visiteur (vue publique)

### Contexte

Le `ProfileScreen` actuel est conçu uniquement pour le profil de l'utilisateur connecté. Il doit pouvoir afficher le profil d'un autre joueur en lecture seule.

### Paramètres

Modifier `ProfileScreen` pour accepter un `userId` optionnel :

```dart
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.userId});
  final String? userId;
  // ...
}
```

### Comportement conditionnel

```dart
final bool isOwnProfile = widget.userId == null ||
    widget.userId == ref.read(currentUserProvider)?.id;
```

- **Si `isOwnProfile`** : comportement actuel inchangé (QR code, settings, avatar éditable).
- **Si `!isOwnProfile`** :
  - Masquer le bouton QR code.
  - Masquer le bouton Réglages.
  - L'avatar n'est PAS cliquable (pas de `_changeAvatar`).
  - Charger les données via `GET /users/:userId` au lieu de `GET /users/me`.
  - Afficher les boutons Bloquer / Ami en haut à droite (voir CHANTIER M).

### Route

Modifier la route `/profile` existante :

```dart
GoRoute(
  path: AppRoutes.profile,
  parentNavigatorKey: _rootNavigatorKey,
  pageBuilder: (_, state) {
    final userId = state.extra as String?;
    return NoTransitionPage(
      key: state.pageKey,
      child: ProfileScreen(userId: userId),
    );
  },
),
```

### Backend

Le endpoint `GET /users/:id` existe déjà dans `users.controller.ts` et retourne les données publiques. Ajouter les stats publiques :

Fichier : `backend/src/modules/users/users.service.ts` — méthode `findById()`

Si `findById()` ne retourne pas déjà les stats et les badges, ajouter les relations :

```typescript
async findById(id: string) {
  return this.userRepo.findOne({
    where: { id },
    relations: ['player_stats', 'club_memberships', 'club_memberships.club'],
  });
}
```

### Flutter — Service

Ajouter dans `ProfileService` :

```dart
Future<UserModel> fetchUserById(String userId) async {
  final response = await _api.get<Map<String, dynamic>>('/users/$userId');
  final data = response.data ?? {};
  final inner = data['data'] is Map<String, dynamic>
      ? data['data'] as Map<String, dynamic>
      : data;
  return UserModel.fromApi(inner);
}
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/profile/presentation/profile_screen.dart` | Ajouter `userId` param, conditionner QR/settings/avatar |
| `lib/features/profile/data/profile_service.dart` | Ajouter `fetchUserById()` |
| `lib/core/config/app_routes.dart` | Passer `state.extra` comme `userId` |
| `backend/src/modules/users/users.service.ts` | Enrichir `findById()` avec relations |

---

## 8. CHANTIER F — Navigation contacts → profil joueur

### Action

Dans `contacts_screen.dart`, rendre le nom du joueur et/ou la tuile ami cliquable pour naviguer vers le profil :

Dans `_FriendTile`, entourer la partie gauche (avatar + nom) d'un `GestureDetector` ou rendre le `ListTile` tappable :

```dart
GestureDetector(
  onTap: () => context.push(AppRoutes.profile, extra: friend.id),
  child: Row(
    children: [
      _AvatarLetter(name: friend.username),
      const SizedBox(width: 10),
      Expanded(
        child: Text(friend.username, /* ... */),
      ),
    ],
  ),
),
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/contacts/presentation/contacts_screen.dart` | `_FriendTile` : wrap nom+avatar dans GestureDetector |

---

## 9. CHANTIER G — Navigation tournoi → profil joueur

### Action

Dans `tournament_detail_screen.dart`, dans `_PlayersTab`, ajouter un `onTap` au `ListTile` de chaque joueur :

```dart
ListTile(
  onTap: () => context.push(AppRoutes.profile, extra: player.userId),
  // ... reste inchangé
)
```

Vérifier que `TournamentPlayerModel` expose un champ `userId`. S'il manque, l'ajouter.

### Fichier : `lib/features/tournaments/models/tournament_model.dart`

Vérifier la classe `TournamentPlayerModel`. Elle doit avoir :

```dart
final String userId;
```

Si ce champ s'appelle différemment (ex: `id`), utiliser le bon champ.

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/tournaments/presentation/tournament_detail_screen.dart` | Ajouter `onTap` au ListTile joueur |
| `lib/features/tournaments/models/tournament_model.dart` | Vérifier/ajouter `userId` |

---

## 10. CHANTIER H — Détail tournoi : ordre des onglets

### Fichier

`lib/features/tournaments/presentation/tournament_detail_screen.dart`

### Action

Inverser l'ordre des deux premiers onglets dans le `TabBar` et le `TabBarView` :

```dart
// AVANT
tabs: [
  Tab(text: 'Joueurs'),
  Tab(text: 'Infos'),
  Tab(text: 'Poules'),
  Tab(text: 'Bracket'),
],
children: [
  _PlayersTab(...),
  _InfoTab(...),
  _PoolsTab(...),
  _BracketTab(...),
],

// APRÈS
tabs: [
  Tab(text: 'Infos'),
  Tab(text: 'Joueurs'),
  Tab(text: 'Poules'),
  Tab(text: 'Bracket'),
],
children: [
  _InfoTab(...),
  _PlayersTab(...),
  _PoolsTab(...),
  _BracketTab(...),
],
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/features/tournaments/presentation/tournament_detail_screen.dart` | Réordonner tabs |

---

## 11. CHANTIER I — Tournoi : club partenaire et adresse

### Backend — Schéma

Créer une migration SQL `backend/sql/014_tournament_club.sql` :

```sql
ALTER TABLE tournaments ADD COLUMN IF NOT EXISTS club_id UUID REFERENCES clubs(id) ON DELETE SET NULL;
```

### Backend — Entité

Fichier : `backend/src/modules/tournaments/entities/tournament.entity.ts`

Ajouter :

```typescript
@Column({ type: 'uuid', nullable: true })
club_id: string | null;

@ManyToOne(() => Club, { onDelete: 'SET NULL', eager: true })
@JoinColumn({ name: 'club_id' })
club: Club;
```

Importer `Club` depuis `../../clubs/entities/club.entity.ts` (vérifier le chemin exact).

### Backend — DTO

Fichier : `backend/src/modules/tournaments/dto/create-tournament.dto.ts`

Ajouter :

```typescript
@IsOptional()
@IsString()
club_id?: string;
```

### Backend — Service

Dans `tournaments.service.ts`, lors du `create()`, ajouter `club_id: dto.club_id ?? null`.
Dans les requêtes `find`, ajouter la relation `club` si elle n'est pas eager.

### Flutter — Création tournoi

Fichier : `lib/features/tournaments/presentation/tournament_create_screen.dart`

Ajouter un champ de sélection de club :
- Utiliser un `TextField` avec recherche (ou autocomplete) qui appelle `GET /clubs?search=...`.
- Stocker `_selectedClubId` et `_selectedClubName`.
- Au submit, passer `'club_id': _selectedClubId` dans le payload.

### Flutter — Modèle tournoi

Fichier : `lib/features/tournaments/models/tournament_model.dart`

Ajouter :

```dart
final String? clubId;
final String? clubName;
final String? clubAddress;
```

Et parser depuis `json['club']` :

```dart
final club = json['club'] as Map<String, dynamic>?;
// ...
clubId: club?['id']?.toString(),
clubName: club?['name']?.toString(),
clubAddress: club?['address']?.toString(),
```

### Flutter — Détail tournoi InfoTab

Fichier : `lib/features/tournaments/presentation/tournament_detail_screen.dart` — `_InfoTab`

Ajouter après les `_InfoRow` existants :

```dart
if (tournament.clubName != null)
  GestureDetector(
    onTap: () => context.push('/club/${tournament.clubId}'),
    child: _InfoRow(
      label: 'Club partenaire',
      value: tournament.clubName!,
      // Indiquer visuellement que c'est cliquable (couleur primary, underline)
    ),
  ),
if (tournament.venueAddress != null && tournament.venueAddress!.isNotEmpty)
  GestureDetector(
    onTap: () => _launchMapsNavigation(tournament.venueAddress!),
    child: _InfoRow(
      label: 'Adresse',
      value: tournament.venueAddress!,
    ),
  ),
```

Fonction `_launchMapsNavigation` :

```dart
import 'package:url_launcher/url_launcher.dart';

Future<void> _launchMapsNavigation(String address) async {
  final encoded = Uri.encodeComponent(address);
  final uri = Uri.parse('geo:0,0?q=$encoded');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    // Fallback Google Maps web
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded'));
  }
}
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `backend/sql/014_tournament_club.sql` | Créer migration |
| `backend/src/modules/tournaments/entities/tournament.entity.ts` | Ajouter `club_id`, relation `club` |
| `backend/src/modules/tournaments/dto/create-tournament.dto.ts` | Ajouter `club_id` |
| `backend/src/modules/tournaments/tournaments.service.ts` | Passer `club_id` au create, charger relation |
| `lib/features/tournaments/models/tournament_model.dart` | Ajouter `clubId`, `clubName`, `clubAddress` |
| `lib/features/tournaments/presentation/tournament_create_screen.dart` | Champ de sélection club |
| `lib/features/tournaments/presentation/tournament_detail_screen.dart` | Afficher club + adresse cliquables |

---

## 12. CHANTIER J — Détail tournoi : bouton Démarrer conditionnel

### État actuel

Le code dans `tournament_detail_screen.dart` a déjà :

```dart
if (isCreator) _AdminActions(...)
```

Donc le bouton « Démarrer le tournoi » est déjà masqué pour les non-créateurs. **Ce besoin est déjà implémenté.**

### Action

Valider uniquement que `_AdminActions` est bien conditionné par `isCreator`. C'est le cas (ligne existante). **Aucune modification nécessaire.**

---

## 13. CHANTIER K — Suppression de compte

### Backend — Service

Fichier : `backend/src/modules/users/users.service.ts`

Modifier ou créer la méthode `remove()` :

```typescript
async remove(userId: string) {
  const nextIndex = await this.userRepo
    .createQueryBuilder('user')
    .where("user.username LIKE 'deleted#%'")
    .getCount();

  const deletedUsername = `deleted#${String(nextIndex + 1).padStart(4, '0')}`;

  // Supprimer les amitiés
  await this.friendshipRepo.delete([
    { user_id: userId },
    { friend_id: userId },
  ]);

  // Supprimer les friend requests
  await this.friendRequestRepo.delete([
    { sender_id: userId },
    { receiver_id: userId },
  ]);

  // Anonymiser
  await this.userRepo.update(userId, {
    username: deletedUsername,
    email: null,
    avatar_url: null,
    password_hash: null,
  });

  // Révoquer tous les tokens
  await this.refreshTokenRepo.update(
    { user: { id: userId } },
    { revoked: true },
  );
}
```

Le endpoint `DELETE /users/me` existe déjà dans le controller.

Il faut injecter les repositories `Friendship` et `FriendRequest` dans `UsersService` (ou appeler le ContactsService).

### Flutter — Settings

Fichier : `lib/features/profile/presentation/settings_screen.dart`

Ajouter un bouton « Supprimer mon compte » avec modale de confirmation :

```dart
const SizedBox(height: 16),
ElevatedButton.icon(
  onPressed: _isDeletingAccount ? null : _confirmAndDeleteAccount,
  icon: const Icon(Icons.delete_forever),
  label: Text(_isDeletingAccount ? 'Suppression...' : 'Supprimer mon compte'),
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),
),
```

La méthode `_confirmAndDeleteAccount` :

```dart
Future<void> _confirmAndDeleteAccount() async {
  final confirmed = await showConfirmDialog(
    context: context,
    title: 'Supprimer votre compte',
    message: 'Cette action est irréversible. Votre compte sera anonymisé et vos amitiés supprimées.',
    confirmLabel: 'Supprimer',
    confirmColor: AppColors.error,
  );
  if (!confirmed || !mounted) return;

  setState(() => _isDeletingAccount = true);
  try {
    final api = ref.read(apiClientProvider);
    await api.delete<Map<String, dynamic>>('/users/me');
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go(AppRoutes.notLogged);
  } catch (_) {
    if (mounted) {
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer le compte.')),
      );
    }
  }
}
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `backend/src/modules/users/users.service.ts` | Enrichir `remove()` avec anonymisation + nettoyage amitiés |
| `backend/src/modules/users/users.module.ts` | Injecter repositories contacts si nécessaire |
| `lib/features/profile/presentation/settings_screen.dart` | Ajouter bouton + modale |
| `lib/shared/widgets/confirm_dialog.dart` | Créer (partagé) |

---

## 14. CHANTIER L — Bloquer un utilisateur

### Backend — Schéma

Migration SQL `backend/sql/015_user_blocks.sql` :

```sql
CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE INDEX idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks(blocked_id);
```

### Backend — Entité

Créer `backend/src/modules/contacts/entities/user-block.entity.ts` :

```typescript
@Entity('user_blocks')
export class UserBlock {
  @PrimaryGeneratedColumn('uuid') id: string;
  @Column('uuid') blocker_id: string;
  @Column('uuid') blocked_id: string;
  @CreateDateColumn({ type: 'timestamptz' }) created_at: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocker_id' }) blocker: User;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'blocked_id' }) blocked: User;
}
```

### Backend — Service & Controller

Ajouter dans `contacts.service.ts` :

```typescript
async blockUser(blockerId: string, blockedId: string) {
  // Supprimer l'amitié si elle existe
  await this.friendshipRepo.delete([
    { user_id: blockerId, friend_id: blockedId },
    { user_id: blockedId, friend_id: blockerId },
  ]);
  // Rejeter les demandes en cours
  await this.friendRequestRepo.update(
    { sender_id: blockedId, receiver_id: blockerId, status: 'PENDING' },
    { status: 'REJECTED' },
  );
  // Créer le blocage
  await this.userBlockRepo.save(
    this.userBlockRepo.create({ blocker_id: blockerId, blocked_id: blockedId }),
  );
}

async unblockUser(blockerId: string, blockedId: string) {
  await this.userBlockRepo.delete({ blocker_id: blockerId, blocked_id: blockedId });
}

async isBlocked(blockerId: string, blockedId: string): Promise<boolean> {
  return !!(await this.userBlockRepo.findOne({
    where: { blocker_id: blockerId, blocked_id: blockedId },
  }));
}
```

Ajouter dans `contacts.controller.ts` :

```typescript
@Post('block/:userId')
blockUser(@Req() req, @Param('userId', ParseUUIDPipe) userId: string) {
  return this.contactsService.blockUser(req.user.id, userId);
}

@Delete('block/:userId')
unblockUser(@Req() req, @Param('userId', ParseUUIDPipe) userId: string) {
  return this.contactsService.unblockUser(req.user.id, userId);
}
```

**Important** : le `sendFriendRequest()` doit vérifier que ni l'un ni l'autre n'est bloqué avant d'envoyer.

### Flutter — Bloquer depuis demande d'ami

Dans `contacts_screen.dart`, ajouter un bouton « Bloquer » sur `_IncomingRequestTile` :

```dart
IconButton(
  onPressed: () async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Bloquer ${request.user.username} ?',
      message: 'Cet utilisateur ne pourra plus vous contacter.',
      confirmLabel: 'Bloquer',
      confirmColor: AppColors.error,
    );
    if (confirmed) onBlock();
  },
  icon: const Icon(Icons.block, color: AppColors.error, size: 20),
  tooltip: 'Bloquer',
),
```

Ajouter `onBlock` callback dans le widget et le connecter au controller.

### Flutter — ContactsController

Ajouter dans `contacts_controller.dart` :

```dart
Future<void> blockUser(String userId) async {
  await _repository.blockUser(userId);
  // Retirer de la liste d'amis et des demandes localement
  state = state.copyWith(
    friends: state.friends.where((f) => f.id != userId).toList(),
    incomingRequests: state.incomingRequests.where((r) => r.user.id != userId).toList(),
  );
}
```

### Flutter — ContactsRepository

Ajouter :

```dart
Future<void> blockUser(String userId) async {
  await _api.post<Map<String, dynamic>>('/contacts/block/$userId');
}
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `backend/sql/015_user_blocks.sql` | Créer |
| `backend/src/modules/contacts/entities/user-block.entity.ts` | Créer |
| `backend/src/modules/contacts/contacts.service.ts` | Ajouter `blockUser()`, `unblockUser()`, `isBlocked()` |
| `backend/src/modules/contacts/contacts.controller.ts` | Ajouter routes block/unblock |
| `backend/src/modules/contacts/contacts.module.ts` | Enregistrer `UserBlock` entity |
| `lib/features/contacts/controller/contacts_controller.dart` | Ajouter `blockUser()` |
| `lib/features/contacts/data/contacts_repository.dart` | Ajouter `blockUser()` |
| `lib/features/contacts/presentation/contacts_screen.dart` | Bouton bloquer sur `_IncomingRequestTile` |

---

## 15. CHANTIER M — Actions sur profil visité (bloquer/ami)

### Dépendances

- CHANTIER E (profil visiteur)
- CHANTIER L (blocage backend)

### Comportement

Quand `!isOwnProfile`, afficher en haut à droite (à la place de QR + Settings) deux boutons :

1. **Bouton Ami** :
   - Si PAS ami → icône `Icons.person_add` (couleur `primary`), au tap → `POST /contacts/requests` avec modale de confirmation.
   - Si DÉJÀ ami → icône `Icons.person_remove` (couleur `error`, style barré), au tap → modale de confirmation → `DELETE /contacts/friends/:userId`.

2. **Bouton Bloquer** (si PAS ami) :
   - Icône `Icons.block` (couleur `error`).
   - Au tap → modale de confirmation → `POST /contacts/block/:userId` puis `context.pop()`.

### Données nécessaires

Pour savoir si le user visité est ami ou non, appeler :
- `GET /contacts/friends` → vérifier si `userId` est dans la liste.
- Ou : ajouter un endpoint `GET /contacts/friendship-status/:userId` retournant `{ is_friend, is_blocked, has_pending_request }`.

**Recommandation** : ajouter `GET /contacts/status/:userId` côté backend.

Backend `contacts.controller.ts` :

```typescript
@Get('status/:userId')
friendshipStatus(@Req() req, @Param('userId', ParseUUIDPipe) userId: string) {
  return this.contactsService.getFriendshipStatus(req.user.id, userId);
}
```

Backend `contacts.service.ts` :

```typescript
async getFriendshipStatus(userId: string, targetId: string) {
  const isFriend = !!(await this.friendshipRepo.findOne({
    where: [
      { user_id: userId, friend_id: targetId },
      { user_id: targetId, friend_id: userId },
    ],
  }));
  const isBlocked = await this.isBlocked(userId, targetId);
  const pendingRequest = await this.friendRequestRepo.findOne({
    where: { sender_id: userId, receiver_id: targetId, status: 'PENDING' },
  });
  return {
    is_friend: isFriend,
    is_blocked: isBlocked,
    has_pending_request: !!pendingRequest,
  };
}
```

### Flutter

Ajouter dans `ProfileService` ou un nouveau provider :

```dart
Future<Map<String, bool>> getFriendshipStatus(String userId) async {
  final response = await _api.get<Map<String, dynamic>>('/contacts/status/$userId');
  final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
  return {
    'is_friend': data['is_friend'] as bool? ?? false,
    'is_blocked': data['is_blocked'] as bool? ?? false,
    'has_pending_request': data['has_pending_request'] as bool? ?? false,
  };
}
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `backend/src/modules/contacts/contacts.controller.ts` | Ajouter `GET /contacts/status/:userId` |
| `backend/src/modules/contacts/contacts.service.ts` | Ajouter `getFriendshipStatus()` |
| `lib/features/profile/data/profile_service.dart` | Ajouter `getFriendshipStatus()` |
| `lib/features/profile/presentation/profile_screen.dart` | Boutons ami/bloquer conditionnels |

---

## 16. CHANTIER N — Page À propos / Patch notes

### Approche simple et maintenable

Les patch notes sont stockées dans un fichier Dart statique (pas de call API, pas de fichier externe) pour maximiser la portabilité et la simplicité de mise à jour.

### Fichier de données

Créer `lib/core/config/patch_notes.dart` :

```dart
class PatchNote {
  const PatchNote({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.highlights,
    this.fixes = const [],
  });

  final String version;
  final int buildNumber;
  final String date;
  final List<String> highlights;
  final List<String> fixes;
}

/// Maintenir cette liste à jour à chaque release.
/// Ajouter les nouvelles entrées EN HAUT de la liste.
const List<PatchNote> patchNotes = [
  PatchNote(
    version: '1.0.1',
    buildNumber: 2,
    date: '2026-04-02',
    highlights: [
      'Conditions d\'utilisation à l\'inscription',
      'Profil public des joueurs',
      'Club partenaire sur les tournois',
      'Patch notes intégrées',
    ],
    fixes: [
      'Correction upload photo de profil sur Android',
      'Amélioration sécurité du repository',
    ],
  ),
];
```

### Écran

Créer `lib/features/profile/presentation/about_screen.dart` :

Un `Scaffold` avec :
- AppBar titre « À propos ».
- Version de l'app (via `package_info_plus`, déjà en dépendance).
- `ListView` des `PatchNote` triées par date décroissante.

Chaque entrée affiche :
- `Version X.Y.Z (build N) — date`
- Nouveautés en puces vertes
- Correctifs en puces oranges

### Route

Ajouter `static const String about = '/profile/about';` dans `AppRoutes`.
Ajouter la `GoRoute` correspondante.

### Accés depuis Settings

Fichier : `lib/features/profile/presentation/settings_screen.dart`

Ajouter un bouton avant « Déconnexion » :

```dart
OutlinedButton.icon(
  onPressed: () => context.push(AppRoutes.about),
  icon: const Icon(Icons.info_outline),
  label: const Text('À propos'),
),
```

### Règle IA à ajouter

Fichier : `ai_project_guidelines.md`

Ajouter à la fin de la section « 10. Instructions pour les IA » :

```markdown
### Patch Notes
- À chaque merge dans `master` qui modifie le comportement utilisateur, ajouter une entrée dans `lib/core/config/patch_notes.dart`.
- Incrémenter `version` dans `pubspec.yaml` et ajouter l'entrée correspondante dans `patchNotes` avec la date du jour.
- Les nouveautés vont dans `highlights`, les bugs corrigés dans `fixes`.
```

### Fichiers impactés

| Fichier | Action |
|---------|--------|
| `lib/core/config/patch_notes.dart` | Créer |
| `lib/features/profile/presentation/about_screen.dart` | Créer |
| `lib/core/config/app_routes.dart` | Ajouter route `/profile/about` |
| `lib/features/profile/presentation/settings_screen.dart` | Ajouter bouton « À propos » |
| `ai_project_guidelines.md` | Ajouter règle patch notes |

---

## 17. Ordre d'implémentation recommandé

L'ordre tient compte des dépendances et minimise les conflits de merge.

| Phase | Chantiers | Raison |
|-------|-----------|--------|
| **1 — Fondations** | Widget `confirm_dialog.dart`, `patch_notes.dart` | Utilisés par tous les chantiers suivants |
| **2 — Backend pur** | L (blocage user_blocks), K (delete account), I (tournament club_id), M (friendship status endpoint) | Migrations et endpoints indépendants |
| **3 — UI simple** | C (suppr bouton refresh), D (icône message contact), H (ordre onglets tournoi) | Modifications isolées, aucune dépendance |
| **4 — Inscription** | A (Step 2 conditions), B (Step 3 tutoriel) | Séquentiels entre eux |
| **5 — Profil visiteur** | E (profil paramétré), F (nav contacts→profil), G (nav tournoi→profil), M (boutons ami/bloquer) | E doit être fait avant F, G, M |
| **6 — Tournoi enrichi** | I (club partenaire UI), J (démarrer conditionnel — déjà fait, juste vérifier) | I dépend du backend phase 2 |
| **7 — Finitions** | K (UI delete account), L (UI bloquer depuis contacts), N (about + patch notes) | Indépendants, finitions |

---

## 18. Checklist de validation

### Par chantier

- [ ] **A** — Step 2 : titre CONDITIONS, bouton Refuser, 4 conditions affichées, checkbox obligatoire, bouton Commencer, inscription au clic
- [ ] **B** — Step 3 : écran tutoriel, 4 cartes, bouton skip, bouton principal → home
- [ ] **C** — Bouton Rafraîchir supprimé de la liste des tournois
- [ ] **D** — Bouton Chat remplacé par icône verte dans la tuile ami
- [ ] **E** — ProfileScreen accepte un `userId`, masque QR/settings/avatar-upload si vue publique
- [ ] **F** — Clic sur un ami dans contacts → redirige vers profil public
- [ ] **G** — Clic sur un joueur dans le détail tournoi → redirige vers profil public
- [ ] **H** — Onglet Infos en premier dans le détail tournoi
- [ ] **I** — Champ club dans création tournoi, club affiché dans infos tournoi, clic → page club, clic adresse → navigation GPS
- [ ] **J** — Bouton Démarrer masqué pour non-créateurs (vérifier uniquement, déjà implémenté)
- [ ] **K** — Bouton Supprimer mon compte dans settings, modale, anonymisation backend
- [ ] **L** — Blocage depuis demande d'ami, endpoint backend, table user_blocks, vérification au sendRequest
- [ ] **M** — Boutons ami/bloquer sur profil visité, endpoint friendship status
- [ ] **N** — Page À propos, patch notes statiques, bouton dans settings, règle IA ajoutée

### Transverse

- [ ] Fonction `showConfirmDialog()` créée et utilisée partout
- [ ] Aucune régression sur le flow de connexion existant (email, Google SSO, guest)
- [ ] Toutes les routes protégées restent protégées
- [ ] `url_launcher` utilisé pour la navigation GPS (déjà en dépendance)
- [ ] Tests manuels sur Android et Web
- [ ] Migrations SQL numérotées séquentiellement (014, 015)
- [ ] `patch_notes.dart` maintenu à jour

---

> **Fin du document de spécification.**
> Ce fichier est la source d'autorité pour l'implémentation de tous les besoins V2.
