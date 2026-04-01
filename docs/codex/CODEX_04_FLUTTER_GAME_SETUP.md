# 🏗️ CODEX PROMPT 04 – Flutter : Page Configuration de Partie (Game Setup)

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`).
Le fichier à modifier est `lib/features/play/presentation/game_setup_screen.dart`.
Le play controller est dans `lib/features/play/controller/play_controller.dart` (enums `GameMode`, `FinishType`, `GameConfig`).
Le match controller est dans `lib/features/match/controller/match_controller.dart`.
Le `GameStartOption` est actuellement défini en `enum { inviteFriend, scanQr, guest }`.

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Refonte de la grille "Options de jeu"

### 1.1 Passer de 3 à 4 options (grille 2x2)
Remplacer la `Row` de 3 `_OptionCard` par un `GridView.count` (crossAxisCount: 2) ou deux `Row` de 2 items :

| Inviter un ami | Scanner QR |
| Territoire | Vs Invité |

Modifier l'enum `GameStartOption` (dans `play_controller.dart` ou localement) :
```dart
enum GameStartOption { inviteFriend, scanQr, territory, guest }
```

Les icônes :
- **Inviter un ami** → `Icons.person_add` (inchangé)
- **Scanner QR** → `Icons.qr_code_scanner` (inchangé)
- **Territoire** → `Icons.flag_circle` (nouveau)
- **Vs Invité** → `Icons.person_outline` (inchangé)

### 1.2 Comportement du mode Territoire
Quand `GameStartOption.territory` est sélectionné :
1. Lancer le scan QR automatiquement (utiliser `mobile_scanner`, voir Tâche 3).
2. Le QR contient un UUID de club.
3. Après scan : appel `GET /clubs/:clubId` pour récupérer les membres.
4. Afficher une **bottom sheet** avec la liste des membres du club scanné (widget `MemberListTile` existant).
5. L'utilisateur sélectionne un adversaire dans la liste → stocké dans le state en tant que `selectedOpponent`.
6. Le match sera automatiquement marqué `is_territorial: true` côté API.

---

## Tâche 2 : Switch Ranked / Amical

### 2.1 Ajouter un toggle au-dessus des options de finish
Après la grille d'options de jeu (Tâche 1), ajouter :

```dart
bool _isRanked = true; // par défaut ranked
```

Widget : un `Row` avec deux `ChoiceChip` ou un `SegmentedButton` :
- **Classé** (sélectionné par défaut, couleur `AppColors.primary`)
- **Amical** (couleur `AppColors.surface`)

Label au-dessus : "Type de match" (même style que "Options de jeu" → 16px w600 textPrimary).

### 2.2 Impact
- Quand `_startOption == GameStartOption.guest` → forcer `_isRanked = false` (pas de match ranked contre un invité local).
- La valeur `_isRanked` sera transmise au `setupMatch()` et via API `createMatchInvitation()`.

Ajouter le paramètre `isRanked` à :
- `MatchController.setupMatch()`
- `MatchModel` → nouveau champ `bool isRanked`
- `MatchService.createMatchInvitation()` → envoyer `is_ranked: true/false`

---

## Tâche 3 : Scanner QR avec `mobile_scanner`

### 3.1 Remplacer le SnackBar actuel
L'option "Scanner QR" affiche actuellement un SnackBar inutile. Remplacer par un vrai scan :

1. Créer `lib/features/play/presentation/qr_scan_screen.dart` :
   - Plein écran, `parentNavigatorKey: _rootNavigatorKey`
   - Utilise `MobileScanner` widget du package `mobile_scanner`
   - Overlay : rectangle semi-transparent avec un trou carré au centre (260x260)
   - Texte au-dessus : "Scannez le QR code de votre adversaire" (ou "du club" si mode territoire)
   - Bouton torch en bas (toggle `controller.toggleTorch()`)
   - Bouton retour (AppBar ou IconButton)

2. Au scan :
   - Valider que le code scanné est un UUID v4 valide : `RegExp(r'^[0-9a-f]{8}-...`).
   - **Mode Scanner QR (normal)** : le UUID = user_id. Appel `GET /users/:id` pour récupérer le pseudo. Retourner le résultat via `context.pop(ContactModel(...))`.
   - **Mode Territoire** : le UUID = club_id. Appel `GET /clubs/:id` pour récupérer le club + ses membres. Afficher la bottom sheet des membres.

3. Ajouter la route :
   ```dart
   static const String qrScan = '/play/qr-scan';
   ```

### 3.2 Mettre à jour `pubspec.yaml`
Si `mobile_scanner` n'est pas déjà dans les dépendances, l'ajouter :
```yaml
mobile_scanner: ^7.0.0
```
Et vérifier que les permissions camera sont dans `AndroidManifest.xml` et `Info.plist`.

---

## Tâche 4 : "Qui commence ?" (Sélecteur de premier joueur)

### 4.1 Widget
Ajouter après le counter "Sets pour gagner" :

```dart
int _startingPlayerIndex = 0; // 0 = moi, 1 = adversaire
```

Label : "Qui commence ?" (16px w600).
Widget : `SegmentedButton<int>` avec 2 segments :
- `0` → "Moi" (affiché comme username de l'utilisateur courant)
- `1` → "Adversaire" (affiché comme le pseudo de l'adversaire sélectionné, ou "Adversaire" par défaut)

Passer `_startingPlayerIndex` à `setupMatch()` :
```dart
startingPlayerIndex: _startingPlayerIndex,
```

Le `MatchController.setupMatch()` accepte déjà `startingPlayerIndex` implicitement (il set `startingPlayerIndex: 0` par défaut). Il faut le rendre paramétrable.

---

## Tâche 5 : Bouton Démarrer — validation adversaire obligatoire

### 5.1 Logique de validation
Le bouton "Commencer la partie" doit être **désactivé** (grisé, `onPressed: null`) si :
- `_startOption == GameStartOption.inviteFriend` ET aucun ami sélectionné (`contactsState.selectedFriend == null`)
- `_startOption == GameStartOption.scanQr` ET aucun adversaire scanné
- `_startOption == GameStartOption.territory` ET aucun adversaire de club sélectionné

Seul `GameStartOption.guest` permet toujours de démarrer.

### 5.2 Affichage sous la grille
Quand un adversaire est sélectionné (par n'importe quel mode), afficher :
```dart
_SelectedFriendInfo(friendName: selectedOpponent?.username ?? '...')
```
Ce widget `_SelectedFriendInfo` existe déjà dans le fichier. Adapter pour fonctionner avec tous les modes (pas uniquement `inviteFriend`).

---

## Tâche 6 : Vs Invité = pas de sauvegarde serveur

Quand `_startOption == GameStartOption.guest` :
- Le match n'est PAS envoyé au serveur (pas d'appel API).
- Le `matchController.setupMatch()` est appelé sans `inviterId`/`inviteeId`.
- Le match est purement local (c'est déjà le cas actuel, confirmer que rien n'est cassé).
- Forcer `isRanked = false`.
- Le nom du joueur 2 est "Invité" (hardcodé).

---

## Contraintes
- Conserver le code existant pour `_buildCounter`, `_finishLabel`, `_resolveGameMode`, etc. — ne pas les refactorer.
- Le `mobile_scanner` doit être initialisé/disposé proprement dans le `QrScanScreen` (dispose du `MobileScannerController`).
- Ne pas utiliser `qr_code_scanner` (déprécié). Utiliser exclusivement `mobile_scanner`.
- Le scan QR doit arrêter la caméra dès qu'un QR valide est détecté (éviter les scans multiples).
- Le layout doit rester scrollable (le ajout d'éléments ne doit pas overflow).
