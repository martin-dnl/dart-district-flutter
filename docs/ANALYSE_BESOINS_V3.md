# 📋 Analyse Détaillée des Besoins – Dart District V3

> Document d'analyse rédigé après audit complet du code Flutter + Backend existant.
> Chaque point est vérifié par rapport au code source actuel, avec préconisations techniques et prérequis identifiés.

---

## 📑 Table des matières

### Correctifs
1. [C1 – Correction upload avatar depuis la page Profil](#c1--correction-upload-avatar-depuis-la-page-profil)
2. [C2 – Refonte bouton "Clubs à proximité" + Pull-to-refresh](#c2--refonte-bouton-clubs-à-proximité--pull-to-refresh)
3. [C3 – Bouton "Rejoindre le club" sur la page détail club](#c3--bouton-rejoindre-le-club-sur-la-page-détail-club)
4. [C4 – Bouton "Quitter le club" sur la page détail club](#c4--bouton-quitter-le-club-sur-la-page-détail-club)
5. [C5 – Chasseur : correction gestion du tour](#c5--chasseur--correction-gestion-du-tour)
6. [C6 – X01 : bust avant la 3ème fléchette (DARTBOARD / TEMPO)](#c6--x01--bust-avant-la-3ème-fléchette-dartboard--tempo)
7. [C7 – Afficher le total cumulé en mode DARTBOARD](#c7--afficher-le-total-cumulé-en-mode-dartboard)
8. [C8 – Vérification des conditions de victoire d'un leg en X01](#c8--vérification-des-conditions-de-victoire-dun-leg-en-x01)
9. [C9 – Stockage local du mode de saisie et du token de connexion](#c9--stockage-local-du-mode-de-saisie-et-du-token-de-connexion)

### Nouvelles fonctionnalités
10. [F1 – Contrôle territorial par un club](#f1--contrôle-territorial-par-un-club)
11. [F2 – Déclenchement du changement de contrôle territorial](#f2--déclenchement-du-changement-de-contrôle-territorial)
12. [F3 – Tuile "Territoires contrôlés" = uniquement ceux du club du joueur](#f3--tuile-territoires-contrôlés--uniquement-ceux-du-club-du-joueur)
13. [F4 – Animation ELO + Points Club en fin de partie classée](#f4--animation-elo--points-club-en-fin-de-partie-classée)

---

## Correctifs

---

### C1 – Correction upload avatar depuis la page Profil

**Besoin** : Corriger l'erreur qui empêche de charger une image avatar depuis la page de profil.

**État actuel (code source)** :
- `ProfileScreen` (profile_screen.dart) : L'avatar est tappable avec une icône caméra en overlay. `onTap: _changeAvatar` ouvre une modale Camera/Galerie.
- Le mécanisme d'upload utilise `ImagePicker.pickImage()` (quality 88, maxWidth 1200) puis appelle `ProfileService.uploadAvatar(File)` via multipart POST.
- En cas d'erreur, un snackbar affiche `error.response?.data['message']` ou un message par défaut.
- `UserModel` possède un champ `avatarUrl` (nullable).
- **Problème identifié** : L'endpoint backend `POST /users/me/avatar` avec support `multipart/form-data` doit être vérifié. Causes probables :
  - L'endpoint n'accepte pas correctement le fichier multipart (configuration Multer manquante ou incorrecte).
  - Le Content-Type envoyé par Dio n'est pas `multipart/form-data` (vérifier que `FormData` avec `MultipartFile` est bien utilisé).
  - Le fichier est trop volumineux (pas de compression avant envoi, ou limite serveur trop basse).
  - Erreur de permissions (manque de permission camera/gallery sur certains OS).

**Analyse & Préconisations** :

1. **Diagnostic Backend** :
   - Vérifier que l'endpoint `POST /users/me/avatar` existe et utilise `@UseInterceptors(FileInterceptor('avatar'))` ou équivalent NestJS.
   - Vérifier la configuration Multer : limite de taille (recommandé : 5 Mo max), formats acceptés (jpg, png, webp).
   - Vérifier que le répertoire `uploads/avatars/` existe et que le processus Node a les droits d'écriture.
   - Log le body de la requête côté backend pour identifier l'erreur exacte.

2. **Diagnostic Flutter** :
   - Vérifier que l'upload utilise `FormData.fromMap({'avatar': await MultipartFile.fromFile(file.path, filename: ...)})`.
   - Ajouter un header `Content-Type: multipart/form-data` explicite si absent.
   - Vérifier les permissions Android (`READ_MEDIA_IMAGES` pour API 33+, `READ_EXTERNAL_STORAGE` pour les versions antérieures) et iOS (`NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription`).
   - S'assurer que `image_picker` utilise `pickImage` (pas une méthode dépréciée).

3. **Améliorations recommandées** :
   - Ajouter un crop carré avant l'upload via `image_cropper` (ratio 1:1, max 400×400px).
   - Compresser avant envoi : quality 80%, format JPEG.
   - Limiter la taille du fichier côté client à 5 Mo (afficher un message d'erreur sinon).
   - Afficher un indicateur de chargement (spinner ou progress bar) pendant l'upload.
   - En cas de succès, forcer le rafraîchissement du `currentUserProvider` pour mettre à jour l'avatar partout (header home, profil, etc.).

**Prérequis** :
- Backend : Endpoint `POST /users/me/avatar` fonctionnel avec Multer + Sharp (redimensionnement WebP).
- Flutter : Packages `image_picker` (existant), `image_cropper` (à vérifier).
- Permissions : Vérifier `AndroidManifest.xml` et `Info.plist`.

**Fichiers impactés** :
- `lib/features/profile/presentation/profile_screen.dart` – Logique d'upload (`_changeAvatar`).
- `lib/features/profile/controller/profile_controller.dart` – Appel service.
- Backend : Controller Users (`upload avatar`), service storage.

**Critères de validation** :
- [ ] Upload depuis la galerie fonctionne (Android + iOS).
- [ ] Upload depuis la caméra fonctionne (Android + iOS).
- [ ] L'avatar s'affiche immédiatement après upload (profil + header home).
- [ ] Erreur explicite si fichier trop volumineux ou format non supporté.
- [ ] L'avatar persiste après fermeture/réouverture de l'app.

---

### C2 – Refonte bouton "Clubs à proximité" + Pull-to-refresh

**Besoin** : Sur la page liste de clubs, remplacer le bouton texte "Clubs à proximité" par un bouton icône à droite du champ de recherche (même style que le bouton de recherche par ville sur `map_screen`). Ajouter le rafraîchissement par scroll vers le haut (pull-to-refresh).

**État actuel (code source)** :
- `ClubScreen` (club_screen.dart) : Le bouton est un `OutlinedButton.icon` avec label "Clubs à proximité" + icône `Icons.my_location_rounded`. Situé sous le champ de recherche.
- Le champ de recherche est un `TextField` avec `onChanged` → `searchByText(value)`.
- Pas de `RefreshIndicator` actuellement sur la page.
- Sur `map_screen`, le champ de recherche de ville utilise un `IconButton` à droite dans un `Row` (style compact, icône seule sans label).

**Analyse & Préconisations** :

1. **Refonte du layout de recherche** :
   - Placer le `TextField` et le bouton de géolocalisation dans un `Row`.
   - Le `TextField` est dans un `Expanded` pour occuper tout l'espace disponible.
   - Le bouton de géolocalisation est un `IconButton` (ou `Container` décoré style glass) à droite, avec l'icône `Icons.my_location_rounded`.
   - Style cohérent avec `map_screen` : même border radius, mêmes couleurs, même taille d'icône.
   - En cours de géolocalisation : remplacer l'icône par un `SizedBox(16×16)` + `CircularProgressIndicator(strokeWidth: 2)`.

2. **Layout cible** :
   ```
   ┌───────────────────────────────┬──────┐
   │  🔍 Rechercher un club...     │  📍  │
   └───────────────────────────────┴──────┘
   ```

3. **Pull-to-refresh** :
   - Wrapper la `ListView` / `CustomScrollView` existante dans un `RefreshIndicator`.
   - `onRefresh` : appeler le provider de recherche/liste de clubs pour recharger les données.
   - Si l'utilisateur a une recherche active, rafraîchir avec les mêmes critères.
   - Si l'utilisateur a activé "à proximité", relancer la géolocalisation + recherche.
   - Si aucun filtre, recharger la liste par défaut.

**Fichiers impactés** :
- `lib/features/club/presentation/club_screen.dart` – Refonte du widget de recherche + ajout `RefreshIndicator`.

**Critères de validation** :
- [ ] Le bouton "Clubs à proximité" est remplacé par une icône compacte à droite du champ de recherche.
- [ ] Le style est cohérent avec le champ de recherche de ville sur la carte.
- [ ] En cours de géolocalisation, un spinner remplace l'icône.
- [ ] Le pull-to-refresh fonctionne et recharge la liste visible.
- [ ] Le scroll vers le haut déclenche bien l'indicateur de rafraîchissement.

---

### C3 – Bouton "Rejoindre le club" sur la page détail club

**Besoin** : Sur la page de détail d'un club, ajouter un bouton "Rejoindre" qui permet à l'utilisateur d'adhérer au club. Ce bouton est visible uniquement si l'utilisateur n'a pas de club actuellement.

**État actuel (code source)** :
- `ClubDetailScreen` (club_detail_screen.dart) : Affiche les infos du club (nom, adresse, horaires, membres, territoires, tournois).
- `ClubModel` contient les membres du club (`List<ClubMember>`).
- `UserModel` possède un identifiant de club (`clubId` nullable) qui indique le club actuel de l'utilisateur.
- L'AppBar actuel est simple avec un titre "Club" et un bouton retour.
- **Pas de bouton "Rejoindre" actuellement implémenté sur cette page.**

**Analyse & Préconisations** :

1. **Condition d'affichage** :
   - L'utilisateur est authentifié (pas un guest).
   - `currentUser.clubId == null` (l'utilisateur n'est membre d'aucun club).
   - Le club n'est pas complet (optionnel : si une limite de membres est définie).

2. **Positionnement du bouton** :
   - Bouton plein (`ElevatedButton`) en bas de la page, idéalement dans un `bottomNavigationBar` ou en `SliverToBoxAdapter` en bas du contenu.
   - Style : `AppColors.primary`, texte "Rejoindre ce club", icône `Icons.group_add`.
   - Alternative : bouton fixé en bas de l'écran (floating bottom bar) pour être toujours visible même avec du scroll.

3. **Logique d'adhésion** :
   - Appel API `POST /clubs/{clubId}/join` (ou `POST /clubs/{clubId}/members`).
   - Le backend crée une entrée dans `club_members` avec `role = 'player'`, `is_active = true`.
   - Le backend met à jour le `member_count` du club.
   - En cas de succès : rafraîchir `currentUserProvider` (le `clubId` de l'utilisateur est mis à jour), afficher un snackbar de confirmation, rafraîchir la page du club.
   - En cas d'erreur : afficher le message d'erreur backend.

4. **Améliorations recommandées** :
   - Ajouter une modale de confirmation : "Voulez-vous rejoindre le club {clubName} ?" avec boutons "Annuler" / "Confirmer".
   - Spinner sur le bouton pendant l'appel API.
   - Après adhésion, le bouton "Rejoindre" disparaît et le bouton "Quitter" (C4) peut apparaître.

**Prérequis** :
- Backend : Endpoint `POST /clubs/{id}/join` ou équivalent (vérifier s'il existe déjà).
- Vérifier que le backend empêche un utilisateur d'être dans deux clubs simultanément.

**Fichiers impactés** :
- `lib/features/club/presentation/club_detail_screen.dart` – Ajout bouton + logique conditionnelle.
- `lib/features/club/controller/club_controller.dart` – Méthode `joinClub(clubId)`.
- Backend : Endpoint d'adhésion.

**Critères de validation** :
- [ ] Le bouton "Rejoindre" est visible uniquement si l'utilisateur n'a pas de club.
- [ ] Le bouton n'est pas visible pour les comptes invités.
- [ ] L'adhésion crée bien une entrée dans `club_members`.
- [ ] Le `clubId` de l'utilisateur est mis à jour localement après l'adhésion.
- [ ] Le bouton disparaît après une adhésion réussie.
- [ ] Modale de confirmation avant l'action.

---

### C4 – Bouton "Quitter le club" sur la page détail club

**Besoin** : Ajouter un bouton icône pour quitter le club en haut à droite de la page de détail du club. Visible uniquement si l'utilisateur est membre de ce club. À l'appui, une modale de confirmation apparaît.

**État actuel (code source)** :
- `ClubDetailScreen` – L'AppBar a un titre "Club" et un bouton retour. Pas d'actions dans l'AppBar.
- Il n'y a actuellement **aucune fonctionnalité de départ** de club.

**Analyse & Préconisations** :

1. **Condition d'affichage** :
   - L'utilisateur est authentifié.
   - `currentUser.clubId == club.id` (l'utilisateur est membre de ce club précis).
   - **Restriction président** : Si l'utilisateur est président du club, le bouton doit être masqué ou désactivé avec un tooltip explicatif ("Transférez la présidence avant de quitter le club" ou "Dissolvez le club pour le quitter"). Un président ne peut pas quitter sans transférer la présidence.

2. **Positionnement** :
   - `AppBar.actions` : `IconButton` avec icône `Icons.logout` ou `Icons.exit_to_app`.
   - Couleur de l'icône : `Colors.redAccent` pour signaler une action destructive.

3. **Modale de confirmation** :
   - Titre : "Quitter le club"
   - Message : "Êtes-vous sûr de vouloir quitter {clubName} ? Vous perdrez votre rôle et vos contributions territoriales ne seront plus comptabilisées pour ce club."
   - Boutons : "Annuler" (neutre) / "Quitter" (`Colors.red`).

4. **Logique de départ** :
   - Appel API `DELETE /clubs/{clubId}/members/me` ou `POST /clubs/{clubId}/leave`.
   - Le backend supprime l'entrée `club_members` (ou passe `is_active = false`).
   - Le backend met à jour `member_count`.
   - Le backend recalcule les points territoriaux du club (les points de l'ancien membre restent-ils ? **Recommandation** : oui, les points acquis restent attribués au club, seuls les futurs points ne compteront plus).
   - Côté Flutter : rafraîchir `currentUserProvider` (`clubId → null`), afficher snackbar de confirmation, rafraîchir les données du club.

5. **Cas limites** :
   - **Dernier membre** : Si l'utilisateur est le dernier membre, proposer de dissoudre le club.
   - **Président** : Bloquer le départ ou proposer le transfert de présidence.
   - **En cours de tournoi** : Si le club est inscrit à un tournoi actif, avertir l'utilisateur.

**Prérequis** :
- Backend : Endpoint `POST /clubs/{id}/leave` ou `DELETE /clubs/{id}/members/me`.
- Logique backend de vérification du rôle président.

**Fichiers impactés** :
- `lib/features/club/presentation/club_detail_screen.dart` – Ajout action AppBar + modale.
- `lib/features/club/controller/club_controller.dart` – Méthode `leaveClub(clubId)`.
- Backend : Endpoint de départ + logique de validation.

**Critères de validation** :
- [ ] Le bouton "Quitter" est visible uniquement si l'utilisateur est membre de ce club.
- [ ] Le bouton n'apparaît pas pour les présidents (ou est désactivé avec tooltip).
- [ ] La modale de confirmation s'affiche à l'appui.
- [ ] Après départ, le `clubId` de l'utilisateur est `null`.
- [ ] Le bouton disparaît après le départ.
- [ ] L'ancien bouton "Rejoindre" (C3) réapparaît.

---

### C5 – Chasseur : correction gestion du tour

**Besoin** : Dans le mode de jeu Chasseur, le tour doit se terminer uniquement lorsqu'un joueur a tiré ses trois fléchettes **OU** quand il a éliminé le dernier adversaire. Le tour ne doit **pas** passer au joueur suivant lorsque le joueur devient chasseur.

**État actuel (code source)** :
- `ChasseurMatchController` (chasseur_match_controller.dart) :
  - `registerDart()` enregistre chaque fléchette une par une.
  - Après chaque fléchette, le contrôleur vérifie s'il ne reste qu'un seul joueur actif → fin de partie.
  - Un joueur devient chasseur quand `lives >= 4` (propriété `isHunter`).
  - Après 3 fléchettes : création d'un `ChasseurRoundEntry` et avancement au joueur suivant via `_nextActivePlayer()`.
  - **Bug potentiel** : Si le changement de statut chasseur provoque un passage de tour prématuré (par exemple, si la logique de transition de tour est liée au changement d'état du joueur plutôt qu'au nombre de fléchettes tirées).

**Analyse & Préconisations** :

1. **Règle métier à garantir** :
   - Le tour d'un joueur dure **exactement 3 fléchettes**, sauf si :
     - Le joueur élimine le **dernier** adversaire (victoire → fin de partie).
   - Le fait de devenir chasseur (atteindre 4 vies) ne doit **EN AUCUN CAS** déclencher un changement de tour.
   - Le fait qu'un adversaire soit éliminé (mais pas le dernier) ne doit **EN AUCUN CAS** déclencher un changement de tour.

2. **Correction à apporter** :
   - Vérifier que `registerDart()` ne fait avancer le tour (`_nextActivePlayer()`) qu'après `_currentTurnDarts.length == 3`.
   - Vérifier qu'un changement de `isHunter` (passage de `false` à `true`) ne déclenche pas un `_advanceTurn()`.
   - La seule exception à la règle des 3 fléchettes est la condition de victoire : `activePlayers.length == 1` → fin de match immédiate (pas d'avancement de tour, fin de partie).
   - Ajouter un guard explicite :
     ```dart
     // Fin du tour = 3 fléchettes tirées OU victoire (dernier adversaire éliminé)
     if (_currentTurnDarts.length >= 3 || activePlayers.length == 1) {
       if (activePlayers.length == 1) {
         _endMatch(winner: activePlayers.first);
       } else {
         _advanceTurn();
       }
     }
     ```

3. **Tests requis** :
   - Scénario : Joueur atteint 4 vies (devient chasseur) sur la 1ère fléchette → il doit pouvoir tirer ses 2 fléchettes restantes.
   - Scénario : Joueur élimine un adversaire (mais pas le dernier) sur la 2ème fléchette → il doit pouvoir tirer sa 3ème fléchette.
   - Scénario : Joueur élimine le dernier adversaire sur la 1ère fléchette → fin de partie immédiate.

**Fichiers impactés** :
- `lib/features/match/controller/chasseur_match_controller.dart` – Logique `registerDart()` + avancement de tour.
- `lib/features/match/models/chasseur_match_state.dart` – Vérifier que l'état ne trigger pas de side-effect.

**Critères de validation** :
- [ ] Un joueur qui devient chasseur peut toujours tirer ses fléchettes restantes dans le tour.
- [ ] Un joueur qui élimine un adversaire (pas le dernier) peut tirer ses fléchettes restantes.
- [ ] La partie se termine immédiatement si le dernier adversaire est éliminé.
- [ ] Le compteur de fléchettes se remet à 0 au début de chaque tour.

---

### C6 – X01 : bust avant la 3ème fléchette (DARTBOARD / TEMPO)

**Besoin** : En X01, un joueur peut bust avant la 3ème fléchette. Lorsque le total des fléchettes saisies dépasse (ou égale) le score à réaliser, permettre d'appuyer sur le bouton "Valider" (concerne les modes de saisie DARTBOARD et TEMPO).

**État actuel (code source)** :
- `MatchController` (match_controller.dart) : La logique de bust est correcte côté contrôleur — si `currentScore - submittedScore < 0`, c'est un bust (round annulé, score restauré, passage au joueur suivant).
- **Problème identifié** : Dans les modes DARTBOARD et TEMPO, le bouton "Valider" n'est activé que lorsque `_darts.length == 3`. Cela empêche de valider un bust (quand le joueur a par exemple jeté 2 fléchettes dont le total dépasse son score restant).
- En mode MANUAL : Le joueur saisit un score total → pas de problème, il peut valider un bust à tout moment.

**Analyse & Préconisations** :

1. **Logique actuelle à modifier** :
   - **DARTBOARD** (`dartboard_input.dart`) : Le bouton "Valider" est activé quand `_darts.length == 3`. Il doit **aussi** être activé quand le total cumulé des fléchettes >= score restant du joueur.
   - **TEMPO** (`tempo_zone_input.dart`) : Même logique — le bouton "Valider" doit être activé quand `_darts.length == 3` **OU** quand `_total >= remainingScore`.

2. **Condition d'activation du bouton "Valider"** :
   ```dart
   bool get canValidate =>
     _darts.length == 3 ||
     (_darts.isNotEmpty && _currentTotal >= remainingScore);
   ```
   - `remainingScore` doit être passé au widget d'input (actuellement ces widgets ne connaissent pas le score restant du joueur).
   - **Modification nécessaire** : Ajouter un paramètre `int remainingScore` aux widgets `DartboardInput` et `TempoZoneInput`, transmis depuis `MatchLiveScreen`.

3. **Comportement attendu** :
   - Le joueur tire sa 1ère fléchette (ex: T20 = 60 points) mais son score restant est 50.
   - Le total cumulé (60) >= score restant (50) → bust détecté.
   - Le bouton "Valider" s'active immédiatement (ne pas attendre les 2 fléchettes manquantes).
   - Le joueur peut valider → le contrôleur traite le bust normalement.
   - **Alternative UX** : Afficher un indicateur visuel "BUST" dès que le total dépasse le score restant, avec le bouton "Valider" en rouge pour confirmer.

4. **Cas du checkout** :
   - Si le total cumulé **égale** exactement le score restant, ce n'est pas forcément un bust — c'est un checkout potentiel.
   - Il faut différencier :
     - `total == remainingScore` ET conditions de finish respectées → checkout, permettre de valider.
     - `total == remainingScore` ET conditions de finish NON respectées (ex: single out alors qu'on est en double out) → bust.
     - `total > remainingScore` → bust.
   - Dans tous les cas, le bouton "Valider" doit être activé dès que `total >= remainingScore`.

5. **Fléchettes non tirées** :
   - Si le joueur valide après 1 ou 2 fléchettes (bust), les fléchettes manquantes peuvent être enregistrées comme `{zone: 0, multiplier: 0, score: 0}` ou simplement omettre les fléchettes non tirées dans l'enregistrement.
   - **Recommandation** : Ne pas ajouter de fléchettes fantômes. Envoyer uniquement les fléchettes effectivement tirées. Le backend doit accepter 1 à 3 fléchettes par tour.

**Fichiers impactés** :
- `lib/features/match/widgets/dartboard_input.dart` – Condition d'activation du bouton "Valider" + paramètre `remainingScore`.
- `lib/features/match/widgets/tempo_zone_input.dart` – Idem.
- `lib/features/match/presentation/match_live_screen.dart` – Passer `remainingScore` aux widgets d'input.

**Critères de validation** :
- [ ] En mode DARTBOARD : le bouton "Valider" s'active dès que le total cumulé >= score restant, même avec 1 ou 2 fléchettes.
- [ ] En mode TEMPO : même comportement.
- [ ] Un bust est correctement détecté et le score est restauré.
- [ ] Un checkout valide (total == score restant + conditions de finish respectées) est bien traité comme une victoire de leg.
- [ ] Le backend accepte un tour avec moins de 3 fléchettes.

---

### C7 – Afficher le total cumulé en mode DARTBOARD

**Besoin** : Afficher dans le mode de saisie DARTBOARD le total cumulé des fléchettes saisies, exactement comme le mode de saisie TEMPO.

**État actuel (code source)** :
- **TEMPO** (`tempo_zone_input.dart`) : Le total cumulé est calculé via un getter `_total` qui somme tous les scores des fléchettes. Il est affiché visuellement pendant la saisie.
- **DARTBOARD** (`dartboard_input.dart`) : Le total cumulé n'est **PAS** affiché pendant la saisie. Le joueur ne voit le total qu'après validation.

**Analyse & Préconisations** :

1. **Modification à apporter** :
   - Ajouter un getter `int get _total => _darts.fold(0, (sum, d) => sum + d.score)` dans `DartboardInput` (identique à TEMPO).
   - Afficher ce total dans un widget dédié, positionné de manière lisible sans gêner l'interaction avec le dartboard.

2. **Positionnement recommandé** :
   - **Option A** : En haut du dartboard, centré, dans un conteneur semi-transparent (glass effect). Afficher le total en grand (Rajdhani 28-32px, bold, couleur `AppColors.primary`).
   - **Option B** : En overlay au centre du dartboard, mais cela peut gêner la saisie.
   - **Recommandation : Option A** – au-dessus du dartboard, visible mais non intrusif.

3. **Détails d'affichage** :
   - Format : `Total : {_total}` ou simplement `{_total}` en gros si le contexte est clair.
   - Afficher également le détail des fléchettes déjà tirées : ex. `T20 + S18 + ... = 78`.
   - Animation : Le total peut s'incrémenter avec une animation de compteur (`AnimatedSwitcher` ou `TweenAnimationBuilder`).

4. **Cohérence avec TEMPO** :
   - S'assurer que le format d'affichage est identique entre DARTBOARD et TEMPO pour éviter toute confusion.
   - Utiliser le même widget ou un widget partagé pour l'affichage du total.

**Fichiers impactés** :
- `lib/features/match/widgets/dartboard_input.dart` – Ajout du getter `_total` et widget d'affichage.

**Critères de validation** :
- [ ] Le total cumulé est affiché en temps réel pendant la saisie en mode DARTBOARD.
- [ ] L'affichage est cohérent avec le mode TEMPO.
- [ ] L'affichage ne gêne pas l'interaction avec le dartboard.
- [ ] Le total se remet à 0 au début de chaque nouveau tour.

---

### C8 – Vérification des conditions de victoire d'un leg en X01

**Besoin** : Vérifier et corriger les conditions de victoire d'un leg en X01. Rappel des règles :
- **Single Out** : La dernière fléchette peut être dans n'importe quelle zone, il suffit que le score descende à exactement 0.
- **Double Out** : La dernière fléchette doit obligatoirement être dans une zone de double (D1-D20 ou D25/Bull) pour que le score descende à 0.

**État actuel (code source)** :
- `MatchController` (match_controller.dart) :
  - Le checkout est détecté quand `newScore == 0`.
  - En mode `doubleOut`, le contrôleur vérifie que la dernière fléchette est un double.
  - Si `newScore == 0` mais la condition de finish n'est pas respectée → bust.
  - **Bug identifié dans l'analyse V2** : La logique de progression de leg utilise `if (legsWon + 1 >= legsPerSet)` ce qui traite `legsPerSet` comme "nombre de legs à gagner" au lieu de "nombre total de legs dans le set" (Best-Of). **Devrait être** `if (legsWon + 1 >= (legsPerSet / 2).ceil())` pour un vrai Best-Of.

**Analyse & Préconisations** :

1. **Vérification de la logique de checkout** :
   - **Single Out** : `newScore == 0` → victoire du leg. Pas de contrainte sur la fléchette.
   - **Double Out** : `newScore == 0 AND lastDart.multiplier == 2` → victoire du leg.
   - **Master Out** : `newScore == 0 AND (lastDart.multiplier == 2 || lastDart.multiplier == 3)` → victoire du leg.

2. **Vérification des cas de bust** :
   - `newScore < 0` → bust (toujours).
   - `newScore == 0` ET finish non respecté → bust (ex: finir sur un simple en Double Out).
   - `newScore == 1` en Double Out → bust (impossible de finir car le plus petit double est D1 = 2).

3. **Correction de la logique Best-Of legs** :
   - Actuellement : `legsWon + 1 >= legsPerSet` → Un set "Best of 5 legs" se termine après 5 legs gagnés au lieu de 3.
   - Correction : `legsWon + 1 >= (legsPerSet / 2).ceil()` → Un set "Best of 5 legs" se termine après 3 legs gagnés.
   - Même correction pour les sets : `setsWon + 1 >= (totalSets / 2).ceil()`.

4. **Cas spécifiques importants** :
   - **Score restant = 1 en Double Out** : Le joueur ne peut plus finir (D1 = 2 minimum). Son tour est automatiquement un bust dès qu'il a ce score ? Non, le score 1 est simplement "stuck" — le joueur doit jouer normalement et buster. Le backend ne doit pas forcer le bust.
   - **Bull (D25 = 50)** : Confirmer que le bull compte comme un double (multiplicateur 2 × 25). Doit valider un checkout en Double Out.
   - **Outer bull (S25 = 25)** : Ce n'est PAS un double. Ne valide pas un checkout en Double Out.

5. **Vérification par mode de saisie** :
   - **MANUAL** : L'utilisateur saisit un score total. Si `total == remainingScore`, demander si c'est un checkout (et en Double Out, demander le nombre de doubles tentés). La zone exacte de la dernière fléchette n'est pas connue → faire confiance à l'utilisateur via la modale de doubles tentés/réussis.
   - **DARTBOARD / TEMPO** : Chaque fléchette est connue individuellement avec zone et multiplicateur → vérification automatique possible de la dernière fléchette.

**Fichiers impactés** :
- `lib/features/match/controller/match_controller.dart` – Logique de checkout, bust, progression leg/set.
- Backend : Vérification des conditions de victoire si le scoring est aussi vérifié côté serveur.

**Critères de validation** :
- [ ] Single Out : checkout validé avec n'importe quelle fléchette (single, double, triple).
- [ ] Double Out : checkout validé uniquement si la dernière fléchette est un double (D1-D20 ou Bull).
- [ ] Double Out : bust si le score atteint 0 avec un single ou triple.
- [ ] Double Out : bust si le score atteint 1 (impossible de finir).
- [ ] Best-Of legs : un set "Best of 5" se termine à 3 legs gagnés, pas 5.
- [ ] Best-Of sets : même logique pour les sets.
- [ ] Le Bull (D25) est accepté comme double pour un checkout Double Out.

---

### C9 – Stockage local du mode de saisie et du token de connexion

**Besoin** : Stocker en local sur le téléphone la configuration du mode de saisie pour pouvoir changer de mode même sans connexion. Prévoir une resynchronisation lors de la récupération de la connexion. Stocker également le token de connexion en local pour pouvoir accéder à l'app hors connexion. Le token est checké en mode en ligne, donc pas de risque de sécurité.

**État actuel (code source)** :
- **Mode de saisie** : Chargé depuis l'API `GET /users/me/settings?key=GAME_OPTION.SCORE_MODE` et persisté via `PATCH /users/me/settings`. **NON** stocké dans Hive/local storage.
- **Token** : Stocké dans `FlutterSecureStorage` (chiffré, Keychain iOS / Keystore Android) via `TokenStorage`. Clés : `ACCESS_TOKEN`, `REFRESH_TOKEN`.
- `LocalStorage` : Classe Hive existante avec `put<T>()` et `get<T>()`. Peu utilisée actuellement.
- La restauration de session (`AuthController.restoreSession()`) lit les tokens depuis `FlutterSecureStorage` et valide via `GET /users/me`. Si la validation échoue (pas de réseau ou token expiré) → `status = unauthenticated`.

**Analyse & Préconisations** :

1. **Stockage local du mode de saisie** :
   - Utiliser `LocalStorage` (Hive) pour stocker le mode de saisie :
     ```dart
     await LocalStorage.put('settings', 'score_mode', 'DARTBOARD');
     final mode = await LocalStorage.get<String>('settings', 'score_mode');
     ```
   - **Stratégie de lecture** : Lire d'abord le local, puis tenter de synchroniser avec l'API. Si l'API est accessible, comparer et mettre à jour le local. Sinon, utiliser la valeur locale.
   - **Stratégie d'écriture** : Écrire d'abord en local (immédiat), puis tenter l'écriture API en background. Si l'API échoue (hors ligne), marquer comme "pending sync".
   - **Resynchronisation** : Lors du retour en ligne, pousser les changements locaux vers l'API. La valeur locale fait foi (dernière écriture gagne).

2. **Accès hors connexion avec token** :
   - Le token est **déjà** stocké dans `FlutterSecureStorage` (chiffré).
   - **Modification nécessaire** : Modifier `AuthController.restoreSession()` pour ne pas forcer `unauthenticated` si la validation réseau échoue.
   - Logique proposée :
     ```dart
     Future<void> restoreSession() async {
       final accessToken = await _tokenStorage.readAccessToken();
       if (accessToken == null) {
         state = AuthState.unauthenticated();
         return;
       }
       try {
         // Tenter la validation en ligne
         final user = await _apiClient.get('/users/me');
         state = AuthState.authenticated(user);
       } on DioException catch (e) {
         if (e.type == DioExceptionType.connectionError ||
             e.type == DioExceptionType.connectionTimeout) {
           // Hors ligne → utiliser les données locales
           final cachedUser = await LocalStorage.get<Map>('auth', 'cached_user');
           if (cachedUser != null) {
             state = AuthState.authenticated(UserModel.fromJson(cachedUser), isOffline: true);
           } else {
             state = AuthState.unauthenticated();
           }
         } else if (e.response?.statusCode == 401) {
           // Token invalide → déconnexion
           await _tokenStorage.clearTokens();
           state = AuthState.unauthenticated();
         }
       }
     }
     ```
   - **Cacher le profil utilisateur** : Lors de chaque authentification réussie en ligne, sauvegarder le `UserModel` en local :
     ```dart
     await LocalStorage.put('auth', 'cached_user', user.toJson());
     ```

3. **Considérations de sécurité** :
   - Le token est dans `FlutterSecureStorage` (chiffré par le hardware) → **sûr**.
   - En mode hors ligne, l'app montre les données cachées mais ne peut pas faire d'opérations serveur → **pas de risque d'actions non autorisées**.
   - Au retour en ligne, le token est revalidé. Si expiré, le `refresh_token` est utilisé. Si le refresh échoue → déconnexion. → **sûr**.
   - **Recommandation** : Ajouter un flag visuel "Mode hors ligne" dans l'app (banner ou icône) pour que l'utilisateur sache qu'il n'est pas synchronisé.
   - **Recommandation** : Limiter les fonctionnalités en hors ligne (pas de création de partie en ligne, pas de chat, pas de modifications de profil). Seules les parties locales et la consultation des données cachées sont possibles.

4. **Resynchronisation** :
   - Utiliser un `ConnectivityResult` listener (package `connectivity_plus`) pour détecter le retour en ligne.
   - Au retour en ligne :
     1. Revalider le token (refresh si nécessaire).
     2. Synchroniser le mode de saisie local → API.
     3. Synchroniser les éventuelles parties locales terminées (si offline_queue est activé).
   - Afficher un snackbar "Connexion rétablie, synchronisation en cours...".

**Fichiers impactés** :
- `lib/core/database/local_storage.dart` – Potentiellement ajout de helpers pour les settings.
- `lib/features/auth/controller/auth_controller.dart` – Gestion du mode hors ligne dans `restoreSession()`.
- `lib/features/match/presentation/match_live_screen.dart` – Lecture/écriture du mode de saisie en local.
- Nouveau : Service de synchronisation ou listener de connectivité.

**Prérequis** :
- Package `connectivity_plus` (vérifier s'il est déjà dans pubspec.yaml).
- S'assurer que `LocalStorage` (Hive) est initialisé au démarrage de l'app.

**Critères de validation** :
- [ ] Le mode de saisie est persisté localement (Hive).
- [ ] Changer de mode de saisie fonctionne sans connexion.
- [ ] Au retour en ligne, le mode local est synchronisé avec l'API.
- [ ] L'app démarre en mode hors ligne si le réseau est indisponible mais un token valide est stocké.
- [ ] Les données utilisateur cachées sont affichées en hors ligne.
- [ ] Un indicateur visuel signale le mode hors ligne.
- [ ] Les fonctionnalités nécessitant le réseau sont désactivées en hors ligne.
- [ ] Le token est revalidé au retour en ligne.

---

## Nouvelles fonctionnalités

---

### F1 – Contrôle territorial par un club

**Besoin** : Un territoire est contrôlé par un club. Le territoire passe sous le contrôle d'un club quand celui-ci est le club avec le plus de points sur ce territoire (par rapport aux autres clubs) ET qu'il a au minimum 200 points.

**État actuel (code source)** :
- Table `territories` : Possède déjà un champ `owner_club_id UUID REFERENCES clubs(id)` (migration 001_schema.sql).
- Table `club_territory_points` : Existe déjà (migration 021). Stocke `(club_id, code_iris, points)` avec contrainte `UNIQUE (club_id, code_iris)`.
- `TerritoryModel` Flutter : Possède `ownerClubId` et `ownerClubName`.
- Le champ `territories.status` existe avec les valeurs : `available`, `locked`, `alert`, `conquered`, `conflict`.

**Analyse & Préconisations** :

1. **Règle métier complète** :
   - Un territoire est **contrôlé** par le club qui a le **plus de points** sur ce territoire, à condition que ce club ait **au minimum 200 points**.
   - Si aucun club n'a 200 points → le territoire n'est contrôlé par personne (`owner_club_id = NULL`, `status = 'available'`).
   - Si un seul club a ≥ 200 points → il contrôle le territoire (`owner_club_id = club_id`, `status = 'conquered'`).
   - Si plusieurs clubs ont ≥ 200 points → le club avec le plus de points contrôle le territoire. En cas d'égalité stricte → `status = 'conflict'`, pas de changement de propriétaire (le propriétaire actuel conserve le contrôle, ou si aucun propriétaire → reste neutre).
   - **Seuil de 200 points** : Ce seuil empêche la prise de contrôle avec un faible investissement. Il doit être configurable côté backend (variable d'environnement ou table de configuration).

2. **Statuts de territoire ajustés** :
   - `available` : Aucun club n'a ≥ 200 points.
   - `conquered` : Un club contrôle le territoire (leader avec ≥ 200 points).
   - `conflict` : Deux clubs ou plus sont à égalité stricte au dessus de 200 points.
   - `alert` : Le club propriétaire est premier mais un autre club se rapproche (écart < 50 points). **Suggestion d'amélioration** : Ce statut d'alerte ajoute de la tension et du gameplay.
   - `locked` : Le club propriétaire a une avance confortable (écart > 100 points). **Suggestion**.

3. **Algorithme de calcul du contrôle** :
   ```sql
   -- Déterminer le club leader sur un territoire donné
   WITH ranked AS (
     SELECT club_id, points,
            ROW_NUMBER() OVER (ORDER BY points DESC) as rn,
            LAG(points) OVER (ORDER BY points DESC) as prev_points
     FROM club_territory_points
     WHERE code_iris = :territory_code
       AND points >= 200
   )
   SELECT * FROM ranked WHERE rn = 1;
   
   -- Si aucun résultat → available
   -- Si un résultat et (prev_points IS NULL OR points > prev_points) → conquered
   -- Si un résultat et points = prev_points → conflict
   ```

4. **Migration backend** :
   - Le schéma est déjà en place (`club_territory_points` + `territories.owner_club_id`).
   - Ajouter un seuil configurable : `INSERT INTO app_config (key, value) VALUES ('territory_control_min_points', '200')` ou via variable d'environnement.
   - Potentiellement ajouter des colonnes utiles :
     - `territories.owner_club_points INTEGER` : Points du club propriétaire (pour affichage rapide).
     - `territories.second_club_points INTEGER` : Points du 2ème club (pour calculer l'écart et le statut alert/locked).

5. **Impact sur l'affichage carte** :
   - La carte doit colorer les territoires selon le club qui les contrôle.
   - Si le club de l'utilisateur contrôle le territoire → couleur `AppColors.primary`.
   - Si un autre club contrôle → couleur neutre ou couleur du club adverse.
   - Territoires `available` → couleur grise/neutre.
   - Territoires `conflict` → couleur spéciale (orange ?).
   - Territoires `alert` → couleur d'avertissement.

**Fichiers impactés** :
- Backend : Service de calcul du contrôle territorial, triggered après chaque partie.
- `lib/features/map/models/territory_model.dart` – Potentiellement ajouter `ownerClubPoints`, `isAlert`.
- `lib/features/map/presentation/map_screen.dart` – Mise à jour des couleurs selon statut.
- Backend SQL : Potentielle migration pour colonnes additionnelles.

**Critères de validation** :
- [ ] Un territoire sans club ayant ≥ 200 points reste `available`.
- [ ] Un territoire est `conquered` quand un club a ≥ 200 points et est leader.
- [ ] En cas d'égalité à ≥ 200 points, le territoire passe en `conflict`.
- [ ] Le propriétaire actuel est le club avec le plus de points ≥ 200.
- [ ] Le seuil de 200 points est configurable.
- [ ] La carte affiche correctement le statut de chaque territoire.

---

### F2 – Déclenchement du changement de contrôle territorial

**Besoin** : Le check et le changement de contrôle de territoire par un club se fait à la fin d'une partie taguée "territoriale" et se fait uniquement sur le territoire concerné.

**État actuel (code source)** :
- Table `matches` : Possède `territory_code_iris VARCHAR(9)` et `territory_club_id UUID` (migration 021).
- `MatchModel` : Possède `isTerritorial` (bool) et potentiellement `territoryCodeIris`.
- Le système de "partie territoriale" existe : le joueur peut taguer une partie comme territoriale lors de la configuration.

**Analyse & Préconisations** :

1. **Workflow de fin de partie territoriale** :
   ```
   Partie terminée (status = 'finished')
        │
        ├── is_territorial == true ?
        │   ├── NON → Pas d'impact territorial. Fin.
        │   └── OUI ──┐
        │              ▼
        │   Récupérer territory_code_iris de la partie
        │              │
        │              ▼
        │   Attribuer les points de club au(x) club(s) des joueurs
        │   (voir règle d'attribution ci-dessous)
        │              │
        │              ▼
        │   Recalculer le contrôle UNIQUEMENT sur ce territory_code_iris
        │   (algorithme F1)
        │              │
        │              ▼
        │   Mettre à jour territories.owner_club_id, territories.status
        │              │
        │              ▼
        │   Notifier les clubs concernés (WebSocket)
        │              │
        │              ▼
        │   Émettre notification push si changement de propriétaire
        └──────────────┘
   ```

2. **Règle d'attribution des points de club** :
   - **Partie classée (is_ranked) + territoriale** :
     - Le **gagnant** rapporte des points à son club sur le territoire.
     - Points attribués : À définir. **Suggestion** :
       - Victoire : +10 points pour le club du gagnant.
       - Défaite : +0 points (ou +2-3 points pour encourager la participation ?).
     - Les points sont cumulatifs et ne sont jamais soustraits (un club ne perd pas de points sur un territoire).
   - **Un joueur sans club** : Ses points ne sont attribués à aucun club. Pas d'impact territorial.
   - **Deux joueurs du même club** : La partie est toujours territoriale mais les points vont au même club. Pas de conflit.

3. **Backend – logique de fin de partie** :
   - Ajouter un hook/événement après `match.status = 'finished'` dans le service Match.
   - Ce hook appelle `TerritoryService.evaluateControl(territory_code_iris)`.
   - Le service :
     1. Récupère tous les `club_territory_points` pour ce `code_iris`.
     2. Applique l'algorithme F1 (seuil 200 points, leader, égalité).
     3. Met à jour `territories` (owner_club_id, status, conquered_at).
     4. Si changement de propriétaire : émet un événement WebSocket `territory:control_changed`.
     5. Crée une notification pour le club qui gagne/perd le contrôle.

4. **Optimisation** :
   - Le recalcul est ciblé sur un seul territoire → requête rapide.
   - Pas besoin de recalculer tous les territoires à chaque partie.
   - Un cron/batch peut être ajouté ultérieurement pour recalculer tous les territoires (intégrité).

5. **Améliorations suggérées** :
   - **Historique de contrôle** : Nouvelle table `territory_control_history (territory_code_iris, club_id, gained_at, lost_at)` pour tracer l'historique des prises de contrôle.
   - **Notifications push** : "Votre club a pris le contrôle du territoire {name} !" ou "Votre club a perdu le contrôle de {name}".
   - **Événement temps réel** : Émettre via WebSocket pour mettre à jour la carte en direct pour tous les joueurs qui la consultent.

**Prérequis** :
- F1 doit être implémenté (algorithme de calcul du contrôle).
- Le champ `territory_code_iris` sur `matches` doit être renseigné lors de la création d'une partie territoriale.
- Le `club_id` du joueur doit être stocké dans `match_players.club_id` pour savoir quel club reçoit les points.

**Fichiers impactés** :
- Backend : Service Match (hook fin de partie), Service Territory (calcul contrôle).
- Backend SQL : Potentielle table `territory_control_history`.
- Frontend : Aucun fichier directement, mais les mises à jour WebSocket doivent être capturées par le `MapController`.

**Critères de validation** :
- [ ] En fin de partie territoriale, les points sont attribués au club du gagnant.
- [ ] Le calcul de contrôle s'exécute uniquement sur le territoire de la partie.
- [ ] Si le club leader change, `owner_club_id` est mis à jour.
- [ ] Le statut du territoire est recalculé correctement.
- [ ] Les parties non-territoriales n'ont aucun impact sur les territoires.
- [ ] Les parties d'un joueur sans club n'attribuent pas de points.
- [ ] Notification envoyée en cas de changement de propriétaire.

---

### F3 – Tuile "Territoires contrôlés" = uniquement ceux du club du joueur

**Besoin** : Sur le menu (home), afficher dans la tuile "Territoires contrôlés" uniquement le nombre de territoires contrôlés par le club du joueur.

**État actuel (code source)** :
- `HomeScreen` (home_screen.dart) : Affiche `_MetricCard` avec `homeState.territoriesControlled`.
- `HomeController` (home_controller.dart) : Fournit `territoriesControlled` (source : API `/territories/map/data` ou endpoint dédié).
- **Ambiguïté actuelle** : La valeur affichée pourrait être le total de tous les territoires contrôlés (tous clubs confondus) ou déjà filtrée par club. À vérifier dans le backend.

**Analyse & Préconisations** :

1. **Règle métier** :
   - Si l'utilisateur est membre d'un club → afficher le nombre de territoires où `owner_club_id == user.clubId`.
   - Si l'utilisateur n'a pas de club → afficher "0" ou masquer la tuile (avec un message "Rejoignez un club pour conquérir des territoires").
   - Si l'utilisateur est guest → masquer la tuile.

2. **Endpoint backend** :
   - Option A : `GET /territories/count?owner_club_id={clubId}` → retourne `{ count: 12 }`.
   - Option B : `GET /clubs/{id}/territories/count` → retourne le nombre de territoires du club.
   - Option C : Utiliser un champ dans la réponse de `GET /clubs/{id}` → `{ ..., territoriesControlled: 12 }`.
   - **Recommandation : Option C** car l'info du club est déjà chargée au démarrage → pas d'appel supplémentaire.

3. **Modification Flutter** :
   - `HomeController` : Charger `territoriesControlled` depuis les données du club de l'utilisateur.
   - Si `user.clubId != null` : requête `/clubs/{clubId}` ou utiliser les données déjà en cache.
   - Sinon : `territoriesControlled = 0`.

4. **Cas limites** :
   - Utilisateur qui vient de quitter son club → le compteur passe à 0 immédiatement.
   - Utilisateur qui vient de rejoindre un club → le compteur affiche les territoires du nouveau club.
   - Mise à jour en temps réel : si un territoire change de propriétaire pendant que l'utilisateur est sur le home → mettre à jour via WebSocket (optionnel, un refresh manuel suffit dans un premier temps).

**Fichiers impactés** :
- `lib/features/home/controller/home_controller.dart` – Source du `territoriesControlled`.
- `lib/features/home/presentation/home_screen.dart` – Condition d'affichage si pas de club.
- Backend : Endpoint retournant le nombre de territoires du club.

**Critères de validation** :
- [ ] La tuile affiche le nombre de territoires contrôlés par le club du joueur.
- [ ] Si le joueur n'a pas de club, la tuile affiche 0 (ou message approprié).
- [ ] La valeur se met à jour après un changement de contrôle territorial.
- [ ] La valeur se met à jour si le joueur change de club.

---

### F4 – Animation ELO + Points Club en fin de partie classée

**Besoin** : Ajouter une animation en fin de partie classée (sur la modale de fin de partie) qui :
1. Affiche l'ELO gagné/perdu par l'utilisateur avec une animation qui incrémente/décrémente l'ELO actuel.
   - En vert (`AppColors.primary`) si gagné (incrémentation).
   - En rouge si perdu (décrémentation).
2. En dessous, affiche les points de club gagnés sur le territoire de la partie.
   - En couleur `AppColors.accent`.
   - S'incrémente systématiquement quand l'utilisateur gagne sur un territoire lors d'une partie classée territoriale.

**État actuel (code source)** :
- **Fin de match** : `match_live_screen.dart` affiche un `showDialog` simple "Match terminé - Consulter le rapport ?". Deux boutons : "Plus tard" / "Voir le rapport".
- **ELO** : Le delta ELO est calculé côté backend et stocké dans `elo_history (elo_before, elo_after, delta)`.
- **Points club territoire** : `club_territory_points` stocke les points. La valeur du delta n'est pas encore retournée par l'API en fin de partie.
- **Match Report** : `MatchReportScreen` affiche les stats détaillées, mais pas d'animation ELO.

**Analyse & Préconisations** :

1. **Données nécessaires du backend** :
   - À la fin d'une partie classée, le backend doit retourner (dans la réponse de fin de partie ou via un endpoint dédié) :
     ```json
     {
       "elo_before": 1250,
       "elo_after": 1275,
       "elo_delta": +25,
       "territory_points_gained": 10,
       "territory_code_iris": "750101234",
       "territory_name": "Bastille - 11e arr."
     }
     ```
   - **Endpoint** : `GET /matches/{id}/result-summary` ou inclure ces données dans la réponse WebSocket de fin de partie.

2. **Design de la modale de fin de partie** :
   ```
   ┌─────────────────────────────────────────┐
   │                                         │
   │            🏆 VICTOIRE !                 │
   │         (ou 😔 DÉFAITE)                 │
   │                                         │
   │    ──────────────────────────────        │
   │                                         │
   │         ELO                              │
   │      1250 → 1275                         │
   │         +25 ▲  (vert, animé)            │
   │                                         │
   │    ──────────────────────────────        │
   │                                         │
   │     Points Club – Bastille              │
   │           +10 ▲  (accent, animé)        │
   │                                         │
   │    ──────────────────────────────        │
   │                                         │
   │    [Voir le rapport]  [Fermer]          │
   │                                         │
   └─────────────────────────────────────────┘
   ```

3. **Animation ELO** :
   - **Compteur animé** : Utiliser `TweenAnimationBuilder<int>` ou un `AnimationController` + `IntTween`.
   - L'animation commence à `elo_before` et s'incrémente/décrémente jusqu'à `elo_after` sur ~1.5 secondes.
   - Easing : `Curves.easeOutCubic` pour un effet satisfaisant.
   - Couleur : `AppColors.primary` (vert) si `elo_delta > 0`, `Colors.red` si `elo_delta < 0`, `Colors.grey` si `elo_delta == 0`.
   - Afficher le delta en dessous/à côté : `+25` ou `-15` avec une icône flèche ▲/▼.
   - **Effet bonus** : Légère vibration haptique (HapticFeedback.mediumImpact) quand l'animation se termine.
   - **Effet visuel** : Shimmer ou glow effect sur le nombre final.

4. **Animation Points Club** :
   - Même style de compteur animé, mais avec `AppColors.accent`.
   - Affiché uniquement si la partie est **territoriale** (`is_territorial == true`).
   - Texte : "Points Club – {territory_name}" ou "Points Club • {territory_name}".
   - Animation : Compteur de 0 → `territory_points_gained` sur ~1 seconde.
   - Si le joueur n'a pas de club : ne pas afficher cette section.
   - Les points s'affichent uniquement pour le **gagnant** (ou pour tous les participants avec des valeurs différentes ?). **Recommandation** : afficher pour le gagnant ses points gagnés, pour le perdant afficher 0 avec un texte "Aucun point gagné".

5. **Séquençage des animations** :
   - Étape 1 (0-0.5s) : Affichage du titre "VICTOIRE !" ou "DÉFAITE" avec scale animation.
   - Étape 2 (0.5-2s) : Animation du compteur ELO.
   - Étape 3 (2-3s) : Animation du compteur Points Club (si applicable).
   - Étape 4 (3s+) : Boutons "Voir le rapport" et "Fermer" apparaissent en fade-in.

6. **Gestion des cas** :
   - **Partie classée non-territoriale** : Afficher seulement l'animation ELO, pas les points club.
   - **Partie amicale** : Pas d'animation ELO ni de points club. Modale simple comme actuellement.
   - **Partie classée territoriale, joueur sans club** : Afficher l'ELO mais pas les points club.
   - **Match nul** (si applicable) : `elo_delta` peut être 0 → afficher "ELO inchangé" en gris.

7. **Widget recommandé** :
   - Créer un widget réutilisable `AnimatedCounterText` :
     ```dart
     class AnimatedCounterText extends StatelessWidget {
       final int from;
       final int to;
       final Duration duration;
       final Color color;
       final TextStyle style;
       // ...
     }
     ```
   - Ce widget peut être réutilisé ailleurs dans l'app (stats, scores, etc.).

**Prérequis** :
- Backend : Endpoint retournant le delta ELO et les points territoire en fin de partie.
- La table `elo_history` doit être renseignée en fin de partie classée.
- La table `club_territory_points` doit être mise à jour en fin de partie territoriale.
- Les données doivent être disponibles **immédiatement** après la fin de partie (pas de délai batch).

**Fichiers impactés** :
- `lib/features/match/presentation/match_live_screen.dart` – Remplacement du `showDialog` simple par la modale animée.
- Nouveau widget : `lib/features/match/widgets/match_end_modal.dart` – Modale de fin de partie avec animations.
- Nouveau widget : `lib/shared/widgets/animated_counter_text.dart` – Compteur animé réutilisable.
- Backend : Endpoint ou enrichissement de la réponse de fin de partie.

**Critères de validation** :
- [ ] En fin de partie classée, la modale affiche l'animation d'ELO.
- [ ] L'ELO s'incrémente en vert (victoire) ou décrémente en rouge (défaite).
- [ ] L'animation est fluide et dure ~1.5 secondes.
- [ ] En fin de partie classée territoriale, les points club sont affichés en `AppColors.accent`.
- [ ] Les points club ne s'affichent pas si la partie n'est pas territoriale.
- [ ] Les points club ne s'affichent pas si le joueur n'a pas de club.
- [ ] Les boutons d'action apparaissent après les animations.
- [ ] Les parties amicales n'affichent pas d'animation ELO.
- [ ] Le delta ELO et les points territoire sont correctement récupérés du backend.

---

## Résumé des dépendances entre les tâches

```
C1  (Avatar)           → Indépendant
C2  (Bouton proximité) → Indépendant
C3  (Rejoindre club)   → Indépendant
C4  (Quitter club)     → Indépendant (mais lien UX avec C3)
C5  (Chasseur tour)    → Indépendant
C6  (X01 bust)         → Dépend partiellement de C7 (total cumulé)
C7  (Total DARTBOARD)  → Indépendant
C8  (Victoire X01)     → Indépendant (mais lié à C6 pour la cohérence)
C9  (Stockage local)   → Indépendant

F1  (Contrôle territ.) → Indépendant (backend principalement)
F2  (Trigger contrôle) → Dépend de F1
F3  (Tuile territoires)→ Dépend de F1/F2 (données)
F4  (Animation ELO)    → Dépend partiellement de F2 (points territoire)
```

## Ordre de réalisation suggéré

### Phase 1 – Correctifs critiques (gameplay)
1. **C5** – Chasseur tour (bug bloquant gameplay)
2. **C8** – Victoire X01 / Best-Of (bug logique)
3. **C6** – Bust avant 3ème fléchette (UX bloquante)
4. **C7** – Total cumulé DARTBOARD (UX quick win)

### Phase 2 – Correctifs UX/UI
5. **C1** – Avatar upload (bug visible)
6. **C2** – Bouton proximité + pull-to-refresh (UX)
7. **C3** – Rejoindre un club (fonctionnalité manquante)
8. **C4** – Quitter un club (fonctionnalité manquante)

### Phase 3 – Infrastructure offline
9. **C9** – Stockage local mode de saisie + token offline

### Phase 4 – Système territorial
10. **F1** – Contrôle territorial par un club (backend + modèle)
11. **F2** – Trigger changement de contrôle (backend)
12. **F3** – Tuile territoires contrôlés (frontend)
13. **F4** – Animation ELO + points club (frontend)

---

## Estimation de complexité

| Tâche | Complexité | Effort estimé | Frontend | Backend |
|-------|-----------|---------------|----------|---------|
| C1 | Moyenne | ★★☆ | ✅ | ✅ |
| C2 | Faible | ★☆☆ | ✅ | ❌ |
| C3 | Moyenne | ★★☆ | ✅ | ✅ |
| C4 | Moyenne | ★★☆ | ✅ | ✅ |
| C5 | Faible | ★☆☆ | ✅ | ❌ |
| C6 | Moyenne | ★★☆ | ✅ | ⚠️ |
| C7 | Faible | ★☆☆ | ✅ | ❌ |
| C8 | Moyenne | ★★☆ | ✅ | ⚠️ |
| C9 | Élevée | ★★★ | ✅ | ❌ |
| F1 | Élevée | ★★★ | ⚠️ | ✅ |
| F2 | Élevée | ★★★ | ❌ | ✅ |
| F3 | Faible | ★☆☆ | ✅ | ⚠️ |
| F4 | Élevée | ★★★ | ✅ | ✅ |
