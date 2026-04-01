# 🏗️ CODEX PROMPT 06 – Flutter : Refonte Page Profil

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`).
Fichiers concernés :
- `lib/features/profile/presentation/profile_screen.dart` — page profil actuelle
- `lib/features/profile/controller/profile_controller.dart` — controller
- `lib/features/profile/widgets/elo_chart.dart` — graphique ELO
- `lib/features/profile/widgets/badge_grid.dart` — grille de badges
- `lib/features/profile/widgets/match_history_tile.dart` — tuile historique
- `lib/shared/widgets/stat_card.dart` — carte de stat réutilisable
- `lib/shared/widgets/player_avatar.dart` — avatar joueur

L'utilisateur est accessible via `ref.watch(currentUserProvider)` (provider `authControllerProvider`).

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Nouvelle disposition des statistiques (3 + 2 + 3)

### Remplacer la Row actuelle de 4 StatCard
La ligne actuelle : ELO, Victoires, Moyenne, Checkout (4 en rang).

Nouvelle disposition :

**Ligne 1 (3 items)** :
| ELO | Victoires | Défaites |
|-----|-----------|----------|
| `user.elo` | `stats.matchesWon` | `stats.matchesPlayed - stats.matchesWon` |
| `Icons.trending_up` accent | `Icons.emoji_events` success | `Icons.close` error |

**Ligne 2 (2 items, plus larges)** :
| Moyenne | Checkout % |
|---------|------------|
| `stats.averageScore.toStringAsFixed(1)` | `stats.checkoutRate.toStringAsFixed(0)%` |
| `Icons.analytics` primary | `Icons.check_circle` secondary |

**Ligne 3 (3 items)** :
| 180s | 140+ | 100+ |
|------|------|------|
| `stats.total180s` | `stats.count140Plus` | `stats.count100Plus` |
| `Icons.stars` accent | `Icons.local_fire_department` warning | `Icons.bolt` primary |

Utiliser le `StatCard` existant. Wrapper chaque ligne dans un `Padding(horizontal: 16)` + `Row` avec `Expanded` + `SizedBox(width: 8)` entre chaque.

### Ajouter les champs manquants dans le modèle utilisateur
Dans le modèle `UserStats` (chercher dans les fichiers auth ou profile) :
```dart
final int count140Plus;
final int count100Plus;
```

Parser depuis l'API :
```dart
count140Plus: (json['count_140_plus'] as num?)?.toInt() ?? 0,
count100Plus: (json['count_100_plus'] as num?)?.toInt() ?? 0,
```

---

## Tâche 2 : Section Badges avec "Voir tout"

### 2.1 Afficher 4 badges max sur le profil
Modifier `BadgeGrid` pour accepter un paramètre `maxDisplay: 4`.
Afficher les 4 premiers badges. Si plus de 4, ne pas les afficher.

### 2.2 Bouton "Voir tout"
Ajouter un `SectionHeader(title: 'Badges', actionText: 'Voir tout', onAction: () => context.push(AppRoutes.badges))`.

### 2.3 Créer la page Badges complète
Fichier : `lib/features/profile/presentation/badges_screen.dart`
- Route : `AppRoutes.badges = '/profile/badges'`
- AppBar avec titre "Mes Badges"
- `GridView.builder` avec crossAxisCount: 3
- Chaque badge : icône + label + date d'obtention
- Badges non obtenus : grayed out (opacity 0.3)

### 2.4 Backend (si inexistant)
Vérifier si les tables `badges` et `user_badges` existent. Si non, créer la migration :
```sql
-- 011_badges_tables.sql
CREATE TABLE IF NOT EXISTS badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) UNIQUE NOT NULL,
  label VARCHAR(100) NOT NULL,
  description TEXT,
  icon VARCHAR(50) NOT NULL,
  category VARCHAR(30) NOT NULL DEFAULT 'general',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_badges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
  earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, badge_id)
);

-- Badge seeds
INSERT INTO badges (code, label, description, icon, category) VALUES
  ('first_win', 'Première Victoire', 'Gagnez votre premier match', 'emoji_events', 'milestone'),
  ('elo_1200', 'Grimpeur', 'Atteignez 1200 ELO', 'trending_up', 'elo'),
  ('elo_1500', 'Expert', 'Atteignez 1500 ELO', 'star', 'elo'),
  ('ten_wins', 'Décagone', 'Gagnez 10 matchs', 'military_tech', 'milestone'),
  ('first_180', 'Maximum !', 'Réalisez votre premier 180', 'stars', 'performance'),
  ('territory_conquer', 'Conquérant', 'Conquérez un premier territoire', 'flag', 'territory'),
  ('tournament_win', 'Champion', 'Gagnez un tournoi', 'workspace_premium', 'tournament')
ON CONFLICT (code) DO NOTHING;
```

### 2.5 Endpoint backend
```
GET /users/me/badges → retourne user_badges avec JOIN badges
```

---

## Tâche 3 : Composant Historique des Matchs réutilisable

### 3.1 Créer `lib/shared/widgets/match_history_list.dart`
Widget réutilisable qui affiche une liste de matchs :
```dart
class MatchHistoryList extends StatelessWidget {
  final List<MatchHistorySummary> matches;
  final bool showLoadMore;
  final VoidCallback? onLoadMore;
  final ValueChanged<String>? onMatchTap; // callback avec matchId
  // ...
}
```

Ce widget sera utilisé :
- Dans `ProfileScreen` (5 derniers matchs)
- Dans `MatchHistoryScreen` (tous les matchs avec pagination, CODEX_02)
- Dans la section "Forme Récente" du Home (5 derniers ranked)

### 3.2 Modèle commun
```dart
class MatchHistorySummary {
  final String matchId;
  final String opponentName;
  final String? opponentAvatarUrl;
  final String setsScore; // "2 - 1"
  final bool won;
  final bool isRanked;
  final DateTime playedAt;
  final String mode; // "501", "Cricket", etc.
}
```

### 3.3 Widget de chaque tuile
Chaque tuile dans un `Container` (GlassCard style) :
```
Row
├─ PlayerAvatar(opponent, size: 36)
├─ SizedBox(8)
├─ Expanded Column
│   ├─ Text(opponentName) 14px w500
│   └─ Text(mode + " · " + relative time) 11px textHint
├─ Text(setsScore) 16px bold textPrimary
├─ SizedBox(8)
└─ Container (badge V ou D)
    ├─ width: 28, height: 28, borderRadius: 8
    ├─ color: won ? success.withOpacity(0.15) : error.withOpacity(0.15)
    └─ Text(won ? 'V' : 'D', color: won ? success : error, 13px bold)
```

Au tap : `onMatchTap?.call(match.matchId)`.

---

## Tâche 4 : Bouton QR Code personnel

### 4.1 Position
En haut à gauche du header profil (symétrique au bouton Settings en haut à droite).

### 4.2 Widget
```dart
IconButton(
  onPressed: () => _showMyQrCode(context, user),
  icon: const Icon(Icons.qr_code_2, color: AppColors.textSecondary),
),
```

### 4.3 Modale QR
```dart
void _showMyQrCode(BuildContext context, User user) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(user.username, style: 20px bold),
          SizedBox(height: 16),
          QrImageView(
            data: user.id, // UUID de l'utilisateur
            version: QrVersions.auto,
            size: 200,
            eyeStyle: QrEyeStyle(color: AppColors.textPrimary),
            dataModuleStyle: QrDataModuleStyle(color: AppColors.primary),
          ),
          SizedBox(height: 12),
          Text('Faites scanner ce code pour être ajouté ou défié', style: 13px textSecondary, textAlign: center),
          SizedBox(height: 24),
        ],
      ),
    ),
  );
}
```

### 4.4 Package `qr_flutter`
Ajouter dans `pubspec.yaml` si absent :
```yaml
qr_flutter: ^4.1.0
```

---

## Tâche 5 : Upload d'avatar

### 5.1 Rendre l'avatar cliquable
Dans le header du profil, wrapper `PlayerAvatar` dans un `GestureDetector` :
```dart
onTap: () => _changeAvatar(),
```

### 5.2 Méthode `_changeAvatar`
1. `showModalBottomSheet` avec 2 options :
   - "Prendre une photo" → `ImagePicker.pickImage(source: ImageSource.camera)`
   - "Choisir dans la galerie" → `ImagePicker.pickImage(source: ImageSource.gallery)`
2. Si image sélectionnée → appel `PATCH /users/me/avatar` (multipart/form-data)
3. Rafraîchir le `currentUserProvider`.

### 5.3 Package `image_picker`
Ajouter si absent :
```yaml
image_picker: ^1.1.0
```

L'endpoint backend `PATCH /users/me/avatar` doit être créé dans CODEX_01 (backend prerequisites). Ici on crée juste le client Flutter.

### 5.4 Service Flutter
Créer ou étendre le `UserService` pour :
```dart
Future<String> uploadAvatar(File imageFile) async {
  final formData = FormData.fromMap({
    'file': await MultipartFile.fromFile(imageFile.path),
  });
  final response = await api.patch('/users/me/avatar', data: formData);
  return response.data['data']['avatar_url'];
}
```

---

## Contraintes
- Le `ProfileScreen` est maintenant accessible uniquement via le header du Home (pas de tab nav bar), suite au CODEX_02.
- Les stats 140+ et 100+ doivent venir des `player_stats` backend. Si la colonne n'existe pas, la migration est dans CODEX_01.
- Le `StatCard` existant doit rester compatible (ne pas modifier son API, seulement l'utiliser).
- L'upload avatar doit valider côté client : fichier < 5MB, formats jpg/png/webp uniquement.
- Le QR code contient **uniquement** le UUID de l'utilisateur (pas de données sensibles).
