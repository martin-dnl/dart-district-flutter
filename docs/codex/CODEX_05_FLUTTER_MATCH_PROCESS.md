# 🏗️ CODEX PROMPT 05 – Flutter : Déroulé du Match (Scoring, BO Fix, Checkout Chart)

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`).
Fichiers concernés :
- `lib/features/match/controller/match_controller.dart` — logique cœur
- `lib/features/match/models/match_model.dart` — modèle de données
- `lib/features/match/presentation/match_live_screen.dart` — UI de scoring
- `lib/features/match/widgets/scoreboard.dart` — tableau de score
- `lib/features/match/widgets/dart_input.dart` — saisie du score
- `lib/features/match/widgets/round_details.dart` — historique des tours

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Correction du Bug "Best Of" (BO) – CRITIQUE

### Problème actuel
Dans `match_controller.dart`, ligne ~113 :
```dart
if (currentPlayer.legsWon + 1 >= state.legsPerSet) {
```
Cela signifie : si `legsPerSet = 3`, il faut gagner **3** legs pour remporter le set. Or la convention "Best of 3" (BO3) implique qu'il faut gagner **2** legs (majorité = ceil(3/2) = 2).

### Correction
Remplacer toutes les occurrences de la comparaison de legs par :
```dart
final legsToWinSet = (state.legsPerSet / 2).ceil();
if (currentPlayer.legsWon + 1 >= legsToWinSet) {
```

De même, vérifier que la condition de victoire du match (`setsToWin`) est correcte. Actuellement `setsToWin` est utilisé comme "nombre de sets à gagner" (pas "best of"), ce qui est cohérent avec le label "Sets pour gagner" dans `game_setup_screen.dart`. **Ne pas modifier** `setsToWin`.

**Résumé** :
- `legsPerSet` = Best Of N → il faut `ceil(N/2)` victoires → **à corriger**
- `setsToWin` = Sets à gagner → il faut exactement N victoires → **déjà correct**

### Label UI à aligner
Dans `game_setup_screen.dart`, le label "Legs par set" est ambigu. Renommer en :
```dart
label: 'Legs par set (BO)',
```

---

## Tâche 2 : Titre du match – afficher Leg + Set

### Fichier : `match_live_screen.dart`
L'AppBar actuelle affiche :
```dart
title: Text('${match.mode} · Leg ${match.currentLeg}'),
```

Remplacer par :
```dart
title: Text('${match.mode} · Set ${match.currentSet} · Leg ${match.currentLeg}'),
```

Si `setsToWin == 1` (partie en un seul set), afficher seulement :
```dart
title: Text('${match.mode} · Leg ${match.currentLeg}'),
```

---

## Tâche 3 : Checkout Chart (table de sortie statique)

### 3.1 Créer `lib/features/match/data/checkout_chart.dart`
Fichier Dart contenant une `Map<int, String>` statique avec toutes les combinaisons de checkout de 2 à 170 pour le mode Double Out.

Exemples :
```dart
const Map<int, String> checkoutChart = {
  170: 'T20 T20 Bull',
  167: 'T20 T19 Bull',
  164: 'T20 T18 Bull',
  161: 'T20 T17 Bull',
  160: 'T20 T20 D20',
  // ...
  2: 'D1',
};
```

Source de référence : table de checkout officielle du darts. Couvrir de 170 à 2. Les valeurs impossibles (169, 168, 166, 165, 163, 162) ne sont pas dans la map.

### 3.2 Afficher le checkout dans le scoreboard
Dans `match_live_screen.dart` ou dans `scoreboard.dart`, lorsque le score restant d'un joueur est **≤ 170** et que la clé existe dans `checkoutChart` :
- Afficher en petit sous le score du joueur : le texte du checkout (ex: "T20 T20 D20")
- Couleur : `AppColors.accent` (doré), fontSize: 11, fontWeight: w500

### 3.3 Afficher uniquement en mode Double Out
Si `finishType != 'doubleOut'`, ne pas afficher le checkout (les tables sont différentes pour Single Out / Master Out et on ne les gère pas pour l'instant).

---

## Tâche 4 : Refonte de la modale "Doubles tentés"

### Problème actuel
Le `_askDoubleAttempts()` dans `match_live_screen.dart` affiche un `AlertDialog` avec 3 `TextButton` (1, 2, 3) et un bouton Annuler. C'est fonctionnel mais pas ergonomique.

### Nouvelle modale
Remplacer par un `showModalBottomSheet` avec :
1. Titre : "Checkout ! 🎯" (20px bold)
2. Sous-titre : "Combien de doubles tentés pour finir ?" (14px textSecondary)
3. **Rangée de 4 boutons horizontaux** :
   - `0` — cas où le joueur finit sans tenter de double (single out accidentel en mode hybride — laisser pour flexibilité)
   - `1` — premier double réussi
   - `2` — un double raté puis réussi
   - `3` — deux doubles ratés puis réussi

   Chaque bouton :
   ```
   Container(
     width: 64, height: 64,
     decoration: BoxDecoration(
       color: AppColors.card,
       borderRadius: 14,
       border: Border.all(AppColors.surfaceLight),
     ),
     child: Center(Text('$n', style: 28px bold primary)),
   )
   ```
   
   Au tap → `Navigator.pop(context, n);`

4. Bouton "Annuler" en dessous (pleine largeur, `TextButton`).

---

## Tâche 5 : Moyenne sur tout le match (pas par leg)

### Problème actuel
La méthode `_computePlayerAverage` calcule la moyenne à partir de `roundHistory` qui contient **tout le match** — ce qui est correct. Mais les scores (`throwScores`) sont réinitialisés à chaque nouveau leg/set dans `submitScore`:
```dart
for (var i = 0; i < players.length; i++) {
  players[i] = players[i].copyWith(score: state.startingScore);
}
```
`throwScores` n'est pas resetté, donc la liste grandit (correct). Cependant, **la moyenne est recalculée uniquement sur les `roundHistory`** du match entier, ce qui est correct.

### Vérification
Confirmer que `_computePlayerAverage` utilise bien **toute la `roundHistory`** du match (pas seulement le leg courant). **C'est déjà le cas**. Pas de modification nécessaire.

### Ajout : afficher "Moy." dans le Scoreboard
Dans `scoreboard.dart`, sous le score de chaque joueur, afficher :
```dart
Text('Moy. ${player.average.toStringAsFixed(1)}', style: 12px textSecondary)
```

---

## Tâche 6 : Bouton Abandon

### 6.1 Ajouter un bouton dans l'AppBar
Dans `match_live_screen.dart` `actions`, ajouter un `IconButton` :
```dart
IconButton(
  onPressed: _confirmAbandon,
  icon: const Icon(Icons.flag_outlined, color: AppColors.warning),
  tooltip: 'Abandonner',
),
```

Placer **avant** le bouton Undo existant.

### 6.2 Modale de confirmation
```dart
Future<void> _confirmAbandon() async {
  final result = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => _AbandonSheet(players: match.players),
  );
  if (result == null) return;
  // result = index du joueur qui abandonne
  _processAbandon(result);
}
```

`_AbandonSheet` :
- Titre : "Qui abandonne ?" (18px bold)
- Liste des joueurs avec RadioListTile : l'utilisateur sélectionne le joueur qui abandonne
- Bouton "Confirmer l'abandon" (rouge, pleine largeur)
- Bouton "Annuler" (textButton)

### 6.3 Logique d'abandon
Ajouter dans `MatchController` :
```dart
void abandonMatch(int abandoningPlayerIndex) {
  // Le joueur opposé gagne
  final winnerIndex = abandoningPlayerIndex == 0 ? 1 : 0;
  final players = List<PlayerMatch>.from(state.players);
  // Marquer abandoned
  state = state.copyWith(
    status: MatchStatus.finished,
    players: players,
    abandonedByIndex: abandoningPlayerIndex,
  );
}
```

Ajouter dans `MatchModel` :
```dart
final int? abandonedByIndex;
```

### 6.4 Sync serveur (match remote)
Si le match est un match remote, appeler un nouvel endpoint :
```
POST /matches/:id/abandon
Body: { "surrendered_by_index": 0 }
```
(Endpoint à créer côté backend dans CODEX_01.)

---

## Tâche 7 : Ajout `totalDartsThrown` dans `PlayerMatch`

Ajouter dans `PlayerMatch` :
```dart
int get totalDartsThrown => throwScores.length * 3; // approximation 3 fléchettes par tour
```

Note : c'est une approximation. Le nombre réel de fléchettes par tour est toujours 3 dans notre modèle (on ne track pas les fléchettes individuellement, seulement le total du tour).

Ce getter sera utilisé dans la page de rapport (CODEX_07).

---

## Contraintes
- Le fix BO (Tâche 1) est la plus critique. Tester que : BO3 → 2 wins, BO5 → 3 wins, BO1 → 1 win.
- Ne pas refactorer les méthodes privées existantes (`_isDoubleOutMode`, `_nextStartingPlayer`, etc.).
- Le checkout chart doit être en `const` (pas de chargement dynamique).
- L'abandon doit fonctionner aussi bien en mode local qu'en mode remote.
- Conserver la compatibilité avec le `loadMatch(MatchModel)` utilisé par les WebSockets.
