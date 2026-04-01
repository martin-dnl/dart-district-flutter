# 🏗️ CODEX PROMPT 07 – Flutter : Contacts, Rapport de Match, Mode Spectateur

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`).
- Contacts : `lib/features/contacts/presentation/contacts_screen.dart`
- Match : `lib/features/match/`
- Shared widgets : `lib/shared/widgets/`

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Bouton raccourci Contacts vers Game Setup

### 1.1 Ajouter un bouton "Défier" dans la liste de contacts
Dans `ContactsScreen`, chaque contact affiché dans la liste a un avatar + nom + statut. Ajouter un `IconButton` à droite de chaque tuile de contact :

```dart
IconButton(
  icon: const Icon(Icons.sports_esports, color: AppColors.primary, size: 20),
  onPressed: () {
    // Pré-sélectionner ce contact comme adversaire
    ref.read(contactsControllerProvider.notifier).selectFriend(contact);
    // Naviguer vers la sélection de mode (PlayScreen)
    context.go(AppRoutes.play);
  },
),
```

### 1.2 Vérifier que `selectFriend` existe
Dans `contacts_controller.dart`, vérifier qu'il existe une méthode `selectFriend(ContactModel contact)` qui met à jour `state.selectedFriend`. Si elle n'existe pas, la créer.

---

## Tâche 2 : Page Rapport de Match (Match Report)

### 2.1 Route
```dart
static const String matchReport = '/match/:id/report';
```
Route plein écran avec `parentNavigatorKey: _rootNavigatorKey`.

### 2.2 Fichier : `lib/features/match/presentation/match_report_screen.dart`

Structure de la page :

```
📱 Match Report Screen
├─ AppBar("Rapport de match") + bouton retour
├─ Résultat global (header)
│   ├─ Row: [Avatar J1] [Score sets "2 - 1"] [Avatar J2]
│   ├─ Noms des joueurs sous chaque avatar
│   └─ Badge "VICTOIRE" (vert) ou "DÉFAITE" (rouge) sous le score
├─ Section "Statistiques" (GlassCard)
│   ├─ _StatRow("Moyenne", p1.average, p2.average)
│   ├─ _StatRow("Best Leg", p1.bestLegAvg, p2.bestLegAvg)
│   ├─ _StatRow("Checkout %", p1.checkoutRate, p2.checkoutRate)
│   ├─ _StatRow("180s", p1.count180, p2.count180)
│   ├─ _StatRow("140+", p1.count140, p2.count140)
│   ├─ _StatRow("100+", p1.count100, p2.count100)
│   ├─ _StatRow("Doubles tentés", p1.doublesAttempted, p2.doublesAttempted)
│   └─ _StatRow("Doubles réussis", p1.doublesHit, p2.doublesHit)
├─ Section "Timeline" (SectionHeader)
│   └─ ListView des legs en ordre chronologique
│       ├─ "Set 1 - Leg 1 : Joueur 1 ✓" (vert)
│       ├─ "Set 1 - Leg 2 : Joueur 2 ✓" (vert)
│       └─ ...
└─ Bouton "Partager" (optionnel, placeholder)
```

### 2.3 Widget `_StatRow`
```dart
class _StatRow extends StatelessWidget {
  final String label;
  final String valueP1;
  final String valueP2;

  Widget build(context) => Padding(
    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
    child: Row(
      children: [
        SizedBox(width: 60, child: Text(valueP1, textAlign: right, style: isBetter ? bold+primary : normal)),
        Expanded(child: Text(label, textAlign: center, style: 12px textSecondary)),
        SizedBox(width: 60, child: Text(valueP2, textAlign: left, style: isBetter ? bold+primary : normal)),
      ],
    ),
  );
}
```
Logique `isBetter` : la valeur la plus élevée est mise en `bold + primary` (sauf pour "Doubles tentés" où plus bas = mieux → inverser).

### 2.4 Données
- **Match local terminé** : utiliser le `MatchModel` en mémoire (le passer via `state.extra` du GoRouter).
- **Match remote** : appeler `GET /matches/:id` pour récupérer les stats complètes. Créer un provider :
```dart
final matchReportProvider = FutureProvider.family<MatchReportData, String>((ref, matchId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/matches/$matchId');
  return MatchReportData.fromApi(response.data['data']);
});
```

### 2.5 Modèle `MatchReportData`
```dart
class MatchReportData {
  final String matchId;
  final String mode;
  final PlayerReportStats player1;
  final PlayerReportStats player2;
  final String setsScore;
  final int winnerIndex;
  final bool wasAbandoned;
  final DateTime playedAt;
  final List<LegResult> timeline;
}

class PlayerReportStats {
  final String name;
  final String? avatarUrl;
  final double average;
  final double bestLegAvg;
  final double checkoutRate;
  final int count180;
  final int count140Plus;
  final int count100Plus;
  final int doublesAttempted;
  final int doublesHit;
  final int totalDarts;
}

class LegResult {
  final int setNumber;
  final int legNumber;
  final int winnerIndex;
  final int dartsToFinish;
}
```

### 2.6 Navigation vers le rapport
- Depuis `match_live_screen.dart` : quand le match se termine (`status == MatchStatus.finished`), afficher un dialog "Match terminé" avec un bouton "Voir le rapport" → `context.pushReplacement('/match/${match.id}/report', extra: match)`.
- Depuis `match_history` : au clic sur une tuile → `context.push('/match/${match.matchId}/report')`.

---

## Tâche 3 : Mode Spectateur (lecture seule)

### 3.1 Concept
Un spectateur peut rejoindre un match en cours via WebSocket et voir le score en temps réel, sans pouvoir modifier le score.

### 3.2 Route
```dart
static const String matchSpectate = '/match/:id/spectate';
```

### 3.3 Fichier : `lib/features/match/presentation/match_spectate_screen.dart`

Structure identique à `match_live_screen.dart` SAUF :
- **PAS** de `DartInput` (pas de zone de saisie de score)
- **PAS** de bouton Undo
- **PAS** de bouton Abandon
- AppBar titre : "🔴 LIVE · {mode}"
- Indicateur "Spectateur" en badge en haut

### 3.4 WebSocket
Le spectateur se connecte au namespace `/ws/match` et écoute les events du match :
```dart
socket.emit('join_match', { 'match_id': matchId, 'role': 'spectator' });
socket.on('match_updated', (data) {
  // Mettre à jour le state local
});
```

Le backend doit accepter le rôle `spectator` dans le room du match (vérifier dans `backend/src/modules/realtime/` si c'est géré). Si non, ajouter :
- Gateway : laisser rejoindre un room avec `role: spectator`
- Ne pas permettre d'events `submit_score` de la part d'un spectateur

### 3.5 Partage du lien spectateur
Depuis `match_live_screen.dart`, ajouter un `IconButton` (actions AppBar) :
```dart
IconButton(
  icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
  tooltip: 'Inviter un spectateur',
  onPressed: () {
    // Copier l'ID du match dans le presse-papier
    Clipboard.setData(ClipboardData(text: match.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID du match copié. Partagez-le pour que d\'autres puissent regarder.')),
    );
  },
)
```

Pour le MVP, le spectateur entre l'ID manuellement. Le deep linking viendra plus tard.

---

## Contraintes
- Le rapport de match doit fonctionner pour les matchs locaux (pas d'API call) ET les matchs remote (API call).
- Le mode spectateur est read-only. Aucune action de scoring ne doit être possible.
- Le bouton "Défier" dans les contacts ne doit pas dupliquer de logique — il pré-sélectionne et redirige.
- Utiliser les widgets existants (`Scoreboard`, `RoundDetails`, `PlayerAvatar`, `GlassCard`) dans les nouvelles pages.
- Le rapport doit gérer le cas "match abandonné" : afficher "Abandon de {nom}" dans la timeline.
