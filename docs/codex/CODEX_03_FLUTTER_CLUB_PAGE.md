# 🏗️ CODEX PROMPT 03 – Flutter : Page Club (Recherche & Affichage)

## Contexte
Tu travailles sur l'app Flutter **Dart District** (`lib/`). L'app utilise GoRouter, Riverpod, Material 3.
La page Club actuelle est dans `lib/features/club/presentation/club_screen.dart`.
Le controller est dans `lib/features/club/controller/club_controller.dart`.
Le modèle est dans `lib/features/club/models/club_model.dart`.

Le backend a les endpoints :
- `GET /clubs` (findAll, avec limit)
- `GET /clubs/ranking`
- `GET /clubs/:id`

Référence les fichiers `ai_project_guidelines.md` et `context_project.md` pour les conventions.

---

## Tâche 1 : Nouveau endpoint backend `GET /clubs/search`

### Fichier : `backend/src/modules/clubs/clubs.controller.ts`
Ajouter un endpoint :
```typescript
@Get('search')
search(
  @Query('q') q?: string,
  @Query('lat') lat?: number,
  @Query('lng') lng?: number,
  @Query('radius') radius?: number,
  @Query('limit') limit?: number,
) {
  return this.clubsService.search({ q, lat, lng, radius, limit });
}
```

### Fichier : `backend/src/modules/clubs/clubs.service.ts`
Ajouter la méthode `search` :
- Si `q` fourni → `WHERE LOWER(name) LIKE '%q%' OR LOWER(city) LIKE '%q%'`
- Si `lat` + `lng` fournis → tri par distance (formule Haversine simplifiée en SQL) avec `radius` par défaut 20km
- Combiner les deux si les deux sont fournis (texte + distance)
- `limit` par défaut 20, max 50
- Relations: `['members']` pour avoir `member_count`
- Ajouter `dart_boards_count` au résultat

### Fichier : `backend/src/modules/clubs/entities/club.entity.ts`
Ajouter la colonne :
```typescript
@Column({ type: 'smallint', default: 0 })
dart_boards_count: number;
```

### Migration SQL (à ajouter dans `backend/sql/`)
```sql
-- 010_club_search_enhancements.sql
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS dart_boards_count SMALLINT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_clubs_city ON clubs (LOWER(city));
CREATE INDEX IF NOT EXISTS idx_clubs_name_lower ON clubs (LOWER(name));
```

---

## Tâche 2 : Nouveau `ClubSearchController` (Flutter)

### Fichier : `lib/features/club/controller/club_search_controller.dart`

```dart
class ClubSearchState {
  final List<ClubModel> results;
  final bool isLoading;
  final String? query;
  final String? error;
  // ...copyWith
}

class ClubSearchController extends StateNotifier<ClubSearchState> {
  // Injecter ApiClient via Ref
  // Timer? _debounce;

  void searchByText(String query);       // GET /clubs/search?q=...
  void searchNearby(double lat, double lng); // GET /clubs/search?lat=...&lng=...
  void clear();                           // Reset results
}
```

- Implémenter un **debounce de 400ms** sur `searchByText`.
- `searchNearby` utilise le package `geolocator` (déjà dans le projet) pour obtenir la position.
- Parser la réponse en `List<ClubModel>`.

### Provider :
```dart
final clubSearchControllerProvider = StateNotifierProvider<ClubSearchController, ClubSearchState>((ref) {
  return ClubSearchController(ref);
});
```

---

## Tâche 3 : Refonte `ClubScreen`

### Fichier : `lib/features/club/presentation/club_screen.dart`

Le nouveau flow est :
1. **Si l'utilisateur a un club** → afficher la page club existante (déjà codée, garder le code actuel).
2. **Si l'utilisateur n'a PAS de club** → afficher une page de recherche/découverte.

### Page "Pas de club" (remplace le "Aucun club" actuel) :

Structure :
```
📱
├─ Header "Trouver un club" (titre style Rajdhani 28px)
├─ Barre de recherche (TextField avec debounce 400ms)
│   - prefixIcon: Icons.search
│   - hintText: "Rechercher un club par nom ou ville..."
│   - onChanged → clubSearchController.searchByText(value)
├─ Bouton "Clubs à proximité" (Chip ou OutlinedButton)
│   - onTap → geolocator.getCurrentPosition() puis clubSearchController.searchNearby(lat, lng)
│   - Affiche un CircularProgressIndicator pendant le chargement géoloc
├─ Résultats (ListView.builder)
│   - Chaque item = ClubSearchTile (nouveau widget)
│   - Si isLoading → CircularProgressIndicator central
│   - Si vide + query non vide → "Aucun club trouvé"
│   - Si vide + query vide → illustration + texte "Recherchez un club"
└─ FAB "Créer un club" → futur (ne rien faire pour l'instant, juste le bouton)
```

### Widget `ClubSearchTile` :

Créer `lib/features/club/widgets/club_search_tile.dart` :
```
Container (GlassCard)
├─ Row
│   ├─ Icône/Avatar du club (Container 48x48, rounded 12, secondary)
│   ├─ Column
│   │   ├─ Text(club.name) - 15px bold
│   │   ├─ Row [ Icon(location) + Text(club.address ?? club.city) ] - 12px textSecondary
│   │   └─ Row [ Text("${club.memberCount} membres") + dot + Text("${club.dart_boards_count} cibles") ] - 12px textHint
│   └─ Icon(chevron_right)
└─ onTap → context.push('/club/${club.id}')
```

### `ClubModel` : ajouter `dartBoardsCount`
Dans `lib/features/club/models/club_model.dart`, ajouter :
```dart
final int dartBoardsCount;
```
Et dans `fromApi` :
```dart
dartBoardsCount: (json['dart_boards_count'] as num?)?.toInt() ?? 0,
```

---

## Tâche 4 : Route Club Detail

### Dans `app_routes.dart` :
```dart
static const String clubDetail = '/club/:id';
```

### Créer `lib/features/club/presentation/club_detail_screen.dart` :
- Placeholder : `AppBar(title: Text('Club'))` + `Text('Club detail - $id')`
- Récupère l'`id` via `state.pathParameters['id']`
- Route avec `parentNavigatorKey: _rootNavigatorKey` (plein écran, pas dans le shell)

---

## Contraintes
- Le `ClubScreen` existant (avec club) ne doit PAS être modifié. Juste wrapper dans un `if/else` : si `club != null` → afficher le widget existant, sinon → afficher la recherche.
- Le debounce doit être implémenté dans le controller, pas dans le widget.
- Le backend endpoint `/clubs/search` doit être **avant** `/clubs/:id` dans le controller (sinon GoRouter/NestJS conflit de routing).
- Utiliser `GlassCard` existant pour les tuiles.
- Ne pas dupliquer de logique : le `ClubSearchController` fait les appels API, le widget consomme le state.
