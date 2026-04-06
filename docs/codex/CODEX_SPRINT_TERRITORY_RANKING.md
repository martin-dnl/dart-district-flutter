# 🎯 GPT5-Codex Sprint Instructions — Corrections & Territoire Club Ranking

> **Projet** : Dart District (Flutter + NestJS + PostgreSQL)
> **Date** : 2026-04-06  
> **Scope** : Bug fixes + Nouveau système de classement territorial des clubs

---

## 📖 Contexte Projet

- **Frontend** : Flutter (Riverpod, GoRouter, Mapbox PMTiles)  
- **Backend** : NestJS (TypeORM, PostgreSQL, WebSockets)  
- **Conventions** : `ai_project_guidelines.md` — Architecture feature-first, snake_case fichiers, PascalCase classes, camelCase variables  
- **Réponses API** : Toutes wrappées via `TransformInterceptor` → `{ success: true, data: ..., error: null }`

---

## PARTIE A — CORRECTIONS DE BUGS

---

### A1. Navigation Bar — Animation de changement de page non fluide

**Fichier** : `lib/shared/widgets/app_scaffold.dart`

**Problème** : Le `_DockItem` utilise `AnimatedContainer` avec `duration: 220ms` et `Curves.easeOutCubic`. Le changement de page via `context.go()` reconstruit **tout le widget tree** (GoRouter remplace la page), ce qui cause un "flash" plutôt qu'une transition fluide. Le `AnimatedContainer` ne transitionne que le fond du bouton, pas le contenu (icône/couleur) qui change instantanément.

**Instructions** :

1. **Convertir `_DockItem` en `StatefulWidget`** avec un `AnimationController` + `ColorTween` pour animer l'icône et le fond de manière synchrone.

2. **Ajouter `AnimatedSwitcher`** ou `TweenAnimationBuilder` sur l'icône pour une transition de couleur fluide entre sélectionné/non-sélectionné.

3. **Alternative plus simple** : Wrappez le `Column` contenant l'icône dans un `AnimatedDefaultTextStyle` et remplacez le `Icon` par un `AnimatedSwitcher` avec `transitionBuilder: FadeTransition` :

```dart
class _DockItem extends StatelessWidget {
  // ...existing fields...

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,  // ← Plus fluide que easeOutCubic seul
      // ...decoration inchangée...
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ← Animer la couleur de l'icône
                    TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: selected
                            ? AppColors.background
                            : AppColors.textSecondary,
                      ),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      builder: (context, color, _) =>
                          Icon(icon, size: 26, color: color),
                    ),
                    // ...badge inchangé...
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

4. **Ne PAS utiliser `PageView` ni `IndexedStack`** — GoRouter gère les routes. Le problème est purement cosmétique sur l'animation du dock.

---

### A2. Configuration de partie — Restructuration des options de jeu

**Fichier** : `lib/features/play/presentation/game_setup_screen.dart`

**Problème actuel** :
- 4 boutons en `GridView` : "Inviter un ami", "Scanner QR", "Territoire", "Vs Invite"
- "Territoire" est un bouton dans les options de jeu (devrait être un switch dans la section "Type de match")
- "Classé/Amical" est un `SegmentedButton` (devrait être un switch)

**Instructions** :

1. **Supprimer `GameStartOption.territory`** de l'enum `GameStartOption` :
```dart
enum GameStartOption { inviteFriend, scanQr, guest }
```

2. **Renommer le label** `'Vs Invite'` → `'Local'` dans le `_OptionCard` correspondant.

3. **Le `GridView` ne contient plus que 3 cartes** :
   - "Inviter un ami" (icon: `Icons.person_add`)
   - "Scan" (icon: `Icons.qr_code_scanner`)
   - "Local" (icon: `Icons.person_outline`)

4. **Ajouter un état `_isTerritorial`** (bool, default `false`) dans `_GameSetupScreenState`.

5. **Section "Type de match"** — Remplacer le `SegmentedButton<bool>` par deux `SwitchListTile` (ou des `Row` avec `Switch.adaptive`) :

```dart
// ─── Section Type de match ───
const Text('Type de match', style: ...),
const SizedBox(height: 10),

// Switch Classé / Amical
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Text('Classé', style: TextStyle(...)),
      Switch.adaptive(
        value: _isRanked,
        activeColor: AppColors.primary,
        onChanged: _startOption == GameStartOption.guest
            ? null  // Désactivé pour les parties locales
            : (val) => setState(() => _isRanked = val),
      ),
    ],
  ),
),
const SizedBox(height: 8),

// Switch Territorial
Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(14),
  ),
  child: Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Territorial', style: TextStyle(...)),
          Switch.adaptive(
            value: _isTerritorial,
            activeColor: AppColors.primary,
            onChanged: _startOption == GameStartOption.guest
                ? null
                : (val) {
                    setState(() {
                      _isTerritorial = val;
                      if (val) _isRanked = true;  // Force classé
                    });
                    if (val) _handleTerritoryClubScan(); // Ouvre le QR scanner (voir A5/B3)
                  },
          ),
        ],
      ),
      // Afficher le nom du club scanné si territorial activé
      if (_isTerritorial && _territoryClub != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _territoryClub!.name,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
    ],
  ),
),
```

6. **Quand `_isTerritorial = true`**, le switch "Classé" est forcé à `true` et le `onChanged` du switch classé est `null` (désactivé).

7. **Quand `_startOption == GameStartOption.guest`** (partie locale), les deux switches sont désactivés et `_isRanked = false`, `_isTerritorial = false`.

---

### A3. Valeur par défaut du type de match

**Fichier** : `lib/features/play/presentation/game_setup_screen.dart`

**Problème** : `_isRanked` est initialisé à `true` (ligne 39). Le type de match par défaut devrait être "Amical".

**Correction** :
```dart
bool _isRanked = false;  // ← était `true`
```

---

### A4. Territoire force "Classé" à true

**Fichier** : `lib/features/play/presentation/game_setup_screen.dart`

**Logique** (déjà intégrée dans A2 ci-dessus) :
- Quand `_isTerritorial` passe à `true` → `_isRanked = true` automatiquement
- Quand `_isTerritorial == true` → le switch Classé est `disabled` (pas de `onChanged`)
- Quand `_isTerritorial` repasse à `false` → `_isRanked` reste modifiable par l'utilisateur

---

### A5. Liste des clubs vide — "Impossible de rechercher des clubs"

**Fichiers** :
- `lib/features/club/controller/club_search_controller.dart`
- `backend/src/modules/clubs/clubs.service.ts` (méthode `search()`)
- `backend/src/modules/clubs/clubs.controller.ts` (endpoint `GET /clubs/search`)

**Diagnostic probable** :

Le endpoint `GET /clubs/search` retourne le résultat direct de `clubsService.search()` qui renvoie un **array d'entités Club** (via `qb.getMany()`). Le `TransformInterceptor` le wrappe en `{ success: true, data: [...], error: null }`.

Côté Flutter, `club_search_controller.dart` lit `response.data?['data']` (ligne 116). **Le problème est probablement** :

1. **Le type de `response.data`** : `api.get<Map<String, dynamic>>('/clubs/search', ...)` — si la lib Dio ne parse pas correctement le JSON, `response.data` peut être un `String` au lieu d'un `Map`.

2. **Les query parameters** : La méthode `_search()` envoie `q`, `lat`, `lng`, `radius`, `limit` — mais si aucun n'est présent (premier chargement via `loadInitial()`), le backend reçoit un appel sans paramètres. Le `search()` côté backend ne filtre pas par `q` si vide (c'est correct), mais il retourne **toutes les entités** avec `isTerritorial` join qui peut échouer.

3. **Le `leftJoinAndSelect('club.members', 'members')`** — Si la relation `members` a un problème de mapping TypeORM (e.g. la colonne `club_id` est mal nommée), le query échoue en 500.

**Instructions de débogage et fix** :

1. **Backend — Vérifier les logs** : Ajouter un `Logger` dans `search()` pour tracer l'erreur exacte :
```typescript
async search(params: { ... }) {
  this.logger.log(`Club search called: ${JSON.stringify(params)}`);
  try {
    // ... query existante ...
  } catch (err) {
    this.logger.error(`Club search failed: ${err.message}`, err.stack);
    throw err;
  }
}
```

2. **Backend — Wrapper le retour** dans `clubs.controller.ts` pour s'assurer de la structure :
```typescript
@Get('search')
async search(...) {
  const results = await this.clubsService.search({ q, lat, lng, radius, limit });
  return results;  // TransformInterceptor wrappera en { success, data, error }
}
```

3. **Flutter — Ajouter un log d'erreur explicite** dans le catch de `_search()` :
```dart
} catch (e, stack) {
  debugPrint('Club search error: $e\n$stack');
  state = state.copyWith(
    isLoading: false,
    results: const [],
    error: 'Impossible de rechercher des clubs.',
  );
}
```

4. **Vérification TypeORM** : S'assurer que l'entité `Club` a bien la relation `members` configurée :
```typescript
@OneToMany(() => ClubMember, (m) => m.club, { eager: false })
members: ClubMember[];
```
Et que `ClubMember` a :
```typescript
@ManyToOne(() => Club, (c) => c.members)
@JoinColumn({ name: 'club_id' })
club: Club;
```

5. **Test direct** : Appeler `curl https://dart-district.fr/api/v1/clubs/search?limit=5` et vérifier la réponse HTTP. Si 500, voir les logs PM2.

---

## PARTIE B — NOUVELLES FONCTIONNALITÉS : CLASSEMENT TERRITORIAL DES CLUBS

---

### B1. Nouvelle table `club_territory_points`

**Fichier à créer** : `backend/sql/015_club_territory_points.sql`

**Objectif** : Associer les clubs aux territoires avec un nombre de points pour le classement sur chaque zone IRIS.

```sql
-- Migration 015: Club territory points association
CREATE TABLE IF NOT EXISTS club_territory_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id UUID NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    code_iris VARCHAR(9) NOT NULL,
    points INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(club_id, code_iris)
);

CREATE INDEX IF NOT EXISTS idx_ctp_club_id ON club_territory_points(club_id);
CREATE INDEX IF NOT EXISTS idx_ctp_code_iris ON club_territory_points(code_iris);
CREATE INDEX IF NOT EXISTS idx_ctp_code_iris_points ON club_territory_points(code_iris, points DESC);
```

**Entité TypeORM à créer** : `backend/src/modules/clubs/entities/club-territory-points.entity.ts`

```typescript
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  UpdateDateColumn,
  Unique,
} from 'typeorm';
import { Club } from './club.entity';

@Entity('club_territory_points')
@Unique(['club_id', 'code_iris'])
export class ClubTerritoryPoints {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'uuid' })
  club_id: string;

  @Column({ type: 'varchar', length: 9 })
  code_iris: string;

  @Column({ type: 'int', default: 0 })
  points: number;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @ManyToOne(() => Club, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'club_id' })
  club: Club;
}
```

**Enregistrer l'entité** dans le module `ClubsModule` (imports TypeORM).

---

### B2. Création de club → Initialiser la relation territoire

**Fichier** : `backend/src/modules/clubs/clubs.service.ts` — méthode `create()`

**Logique actuelle** :
```typescript
async create(dto: CreateClubDto, _userId: string) {
  let resolvedCodeIris = dto.code_iris ?? null;
  // ... resolve code_iris ...
  const club = this.clubRepo.create({ ...dto, country: dto.country ?? 'France' });
  club.code_iris = resolvedCodeIris;
  await this.clubRepo.save(club);
  return this.clubRepo.findOne({ ... });
}
```

**Modification** — Après `await this.clubRepo.save(club)`, ajouter :

```typescript
// Initialiser la relation territoire du club
if (club.code_iris) {
  const existingCtp = await this.ctpRepo.findOne({
    where: { club_id: club.id, code_iris: club.code_iris },
  });
  if (!existingCtp) {
    await this.ctpRepo.save(
      this.ctpRepo.create({
        club_id: club.id,
        code_iris: club.code_iris,
        points: 0,
      }),
    );
  }
}
```

**Injecter** `@InjectRepository(ClubTerritoryPoints) private readonly ctpRepo: Repository<ClubTerritoryPoints>` dans le constructeur de `ClubsService`.

---

### B3. Switch Territoire → QR Scanner pour UUID de club

**Fichier** : `lib/features/play/presentation/game_setup_screen.dart`

**Nouvel état** dans `_GameSetupScreenState` :
```dart
bool _isTerritorial = false;
ClubModel? _territoryClub;  // Club scanné pour le match territorial
```

**Nouvelle méthode** `_handleTerritoryClubScan()` :

```dart
Future<void> _handleTerritoryClubScan() async {
  final result = await context.push(
    AppRoutes.qrScan,
    extra: {'mode': QrScanMode.club.name},
  );

  if (!mounted) return;

  if (result is ClubModel) {
    setState(() {
      _territoryClub = result;
    });
  } else {
    // L'utilisateur a annulé → désactiver le switch territorial
    setState(() {
      _isTerritorial = false;
      _territoryClub = null;
    });
  }
}
```

**Affichage** : Sous le switch "Territorial", afficher le nom du club scanné (voir code dans A2 ci-dessus).

**QrScanScreen existant** (`lib/features/play/presentation/qr_scan_screen.dart`) :
- Mode `QrScanMode.club` scanne un UUID de club, appelle `GET /clubs/:id` et retourne un `ClubModel`.
- Vérifier que ce mode retourne bien un `ClubModel` complet (avec `codeIris`).

---

### B4. Validation avant lancement d'un match territorial

**Fichier** : `lib/features/play/presentation/game_setup_screen.dart` — méthode `_startMatch()`

**Ajouter les validations AVANT l'appel API** quand `_isTerritorial == true` :

```dart
if (_isTerritorial && _territoryClub != null) {
  final authState = ref.read(authControllerProvider);
  final currentUser = authState.user;
  
  if (currentUser == null || selectedOpponent == null) {
    _showTerritoryError('Sélectionnez un adversaire.');
    return;
  }

  // Vérification 1 : Les deux joueurs ne doivent pas être du même club
  if (currentUser.clubId != null &&
      currentUser.clubId == selectedOpponent.clubId) {
    _showTerritoryError(
      'Impossible de lancer un défi territorial : '
      'les deux joueurs appartiennent au même club.',
    );
    return;
  }

  // Vérification 2 : Au moins un des deux joueurs doit appartenir au club du lieu
  final territoryClubId = _territoryClub!.id;
  final currentUserInClub = currentUser.clubId == territoryClubId;
  final opponentInClub = selectedOpponent.clubId == territoryClubId;
  
  if (!currentUserInClub && !opponentInClub) {
    _showTerritoryError(
      'Impossible de lancer un défi territorial : '
      'aucun des deux joueurs n\'appartient au club "${_territoryClub!.name}".',
    );
    return;
  }
}

// Méthode utilitaire pour afficher l'erreur
void _showTerritoryError(String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Défi territorial impossible',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

**Note** : Pour que ces vérifications fonctionnent, il faut que :
- `ContactModel` expose un champ `clubId` (l'ajouter au modèle si absent)
- Le `UserModel` de l'utilisateur courant contienne `clubId`
- Les données du QR scan pour l'adversaire incluent le `clubId`

**Fichiers à vérifier/modifier** :
- `lib/features/contacts/models/contact_models.dart` → ajouter `String? clubId`
- `lib/features/auth/models/user_model.dart` → vérifier présence de `clubId`
- Backend `GET /users/:id` et `GET /contacts` → inclure `club_id` dans la réponse

---

### B5. Nouveaux champs sur le match : `territory_club_id` et `territory_code_iris`

**Migration SQL** : Ajouter dans `backend/sql/015_club_territory_points.sql` (ou créer `016_match_territory_club.sql`) :

```sql
ALTER TABLE matches
ADD COLUMN IF NOT EXISTS territory_club_id UUID REFERENCES clubs(id) ON DELETE SET NULL;

ALTER TABLE matches
ADD COLUMN IF NOT EXISTS territory_code_iris VARCHAR(9);
```

**Entité TypeORM** : `backend/src/modules/matches/entities/match.entity.ts`

Ajouter les colonnes :
```typescript
@Column({ type: 'uuid', nullable: true })
territory_club_id: string | null;

@Column({ type: 'varchar', length: 9, nullable: true })
territory_code_iris: string | null;
```

**Backend — `createInvitation()`** dans `matches.service.ts` :

Ajouter les paramètres dans le body :
```typescript
async createInvitation(
  inviterId: string,
  body: {
    // ...champs existants...
    territory_club_id?: string;
    territory_code_iris?: string;
  },
) {
  // ...
  const match = queryRunner.manager.create(Match, {
    // ...champs existants...
    territory_club_id: body.territory_club_id ?? null,
    territory_code_iris: body.territory_code_iris ?? null,
  });
}
```

**Flutter — `MatchService.createMatchInvitation()`** dans `lib/features/match/data/match_service.dart` :

Ajouter les paramètres :
```dart
Future<MatchModel> createMatchInvitation({
  // ...paramètres existants...
  String? territoryClubId,
  String? territoryCodeIris,
}) async {
  final response = await _api.post(
    '/matches/invitation',
    data: {
      // ...champs existants...
      if (territoryClubId != null) 'territory_club_id': territoryClubId,
      if (territoryCodeIris != null) 'territory_code_iris': territoryCodeIris,
    },
  );
  return matchFromJson(response.data['data']);
}
```

**Flutter — `_startMatch()` dans `game_setup_screen.dart`** :

Passer les nouveaux champs lors de l'appel :
```dart
final invitation = await service.createMatchInvitation(
  // ...champs existants...
  isTerritorial: _isTerritorial,
  territoryClubId: _isTerritorial ? _territoryClub?.id : null,
  territoryCodeIris: _isTerritorial ? _territoryClub?.codeIris : null,
);
```

---

### B6. Fin de partie — Mise à jour ELO + Points territoriaux

**Fichier** : `backend/src/modules/stats/stats.service.ts`

**Logique actuelle** : `processElo()` est appelé à la fin d'un match. Il met à jour l'ELO des deux joueurs.

**Nouvelle méthode** à ajouter dans `StatsService` :

```typescript
async processTerritoryPoints(
  matchId: string,
  winnerId: string,
  loserId: string,
) {
  const match = await this.matchRepo.findOne({
    where: { id: matchId },
    relations: ['players', 'players.user'],
  });

  if (!match || !match.is_territorial || !match.territory_code_iris) {
    return;
  }

  // Trouver le club du gagnant
  const winnerMembership = await this.clubMemberRepo.findOne({
    where: { user: { id: winnerId } },
    relations: ['club'],
  });

  if (!winnerMembership) return;

  const winnerClubId = winnerMembership.club.id;
  const codeIris = match.territory_code_iris;

  // Calculer le delta ELO (déjà calculé dans processElo — réutiliser ou passer en paramètre)
  const winner = await this.userRepo.findOne({ where: { id: winnerId } });
  const loser = await this.userRepo.findOne({ where: { id: loserId } });
  if (!winner || !loser) return;

  // Recalculer le delta (ou le recevoir en paramètre pour éviter la duplication)
  const expectedWinner = 1 / (1 + Math.pow(10, (loser.elo - winner.elo) / 400));
  const deltaWinner = Math.round(K_FACTOR * (1 - expectedWinner));

  // Trouver ou créer l'association club-territoire
  let ctp = await this.ctpRepo.findOne({
    where: { club_id: winnerClubId, code_iris: codeIris },
  });

  if (!ctp) {
    ctp = this.ctpRepo.create({
      club_id: winnerClubId,
      code_iris: codeIris,
      points: 0,
    });
  }

  ctp.points += Math.abs(deltaWinner);
  await this.ctpRepo.save(ctp);
}
```

**Appeler `processTerritoryPoints()`** depuis la logique de fin de match (dans `matches.service.ts`, méthode `checkMatchCompletion()`) :

```typescript
if (setsWon >= setsToWin) {
  // Match won
  match.status = 'completed';
  match.ended_at = new Date();
  await this.matchRepo.save(match);

  // ...existing player update...

  // ELO processing
  const winnerId = lastSetWinnerId;
  const loserId = match.players.find(p => p.user.id !== winnerId)?.user.id;
  if (loserId) {
    await this.statsService.processElo(match.id, winnerId, loserId, match.is_ranked);
    
    // ← NOUVEAU : Points territoriaux
    if (match.is_territorial) {
      await this.statsService.processTerritoryPoints(match.id, winnerId, loserId);
    }
  }
}
```

**Injecter les repos nécessaires** dans `StatsService` :
- `ClubTerritoryPoints` repository (ctpRepo)
- `ClubMember` repository
- `Match` repository

---

### B7. Map — Podium Top 3 clubs sur un territoire

**Fichier backend** : Ajouter un endpoint ou enrichir `GET /territories/:codeIris/panel`

Dans le service territories (ou clubs), ajouter une méthode :

```typescript
async getTerritoryTopClubs(codeIris: string, limit = 3) {
  return this.ctpRepo.find({
    where: { code_iris: codeIris },
    order: { points: 'DESC' },
    take: limit,
    relations: ['club'],
  });
}
```

**Enrichir la réponse du panel** dans le controller/service territories :

```typescript
// Dans la méthode getPanel() ou équivalent
const topClubs = await this.clubsService.getTerritoryTopClubs(codeIris, 3);

return {
  territory: { ... },
  active_duel: { ... },
  latest_events: [ ... ],
  top_clubs: topClubs.map((ctp, index) => ({
    rank: index + 1,
    club_id: ctp.club.id,
    club_name: ctp.club.name,
    points: ctp.points,
  })),
};
```

**Fichier Flutter** : `lib/features/map/presentation/map_screen.dart` — dans `_openPanelForTerritoryCode()`

Ajouter l'affichage du podium dans la modale du territoire. Après la section "owner_club" :

```dart
// Parser les topClubs depuis panelData
final topClubs = (panelData?['top_clubs'] as List<dynamic>? ?? [])
    .whereType<Map<String, dynamic>>()
    .toList();

// ...dans le ListView du BottomSheet, après la section ownerClub...

if (topClubs.isNotEmpty) ...[
  const SizedBox(height: 20),
  const Text(
    'Classement du territoire',
    style: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.bold,
    ),
  ),
  const SizedBox(height: 12),
  _buildPodium(topClubs),
],
```

**Widget Podium** — Créer un widget `_buildPodium()` :

```dart
Widget _buildPodium(List<Map<String, dynamic>> topClubs) {
  // Couleurs du podium
  const podiumColors = [
    Color(0xFFFFD700), // Or (1er)
    Color(0xFFC0C0C0), // Argent (2ème)
    Color(0xFFCD7F32), // Bronze (3ème)
  ];
  
  // Hauteurs relatives des barres
  const podiumHeights = [80.0, 60.0, 45.0];
  
  // Ordre d'affichage : 2ème - 1er - 3ème
  final displayOrder = <int>[];
  if (topClubs.length >= 2) displayOrder.add(1); // 2ème à gauche
  displayOrder.add(0); // 1er au centre
  if (topClubs.length >= 3) displayOrder.add(2); // 3ème à droite

  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: displayOrder.map((index) {
      if (index >= topClubs.length) return const SizedBox();
      final club = topClubs[index];
      final rank = (club['rank'] as num?)?.toInt() ?? (index + 1);
      final name = (club['club_name'] ?? '').toString();
      final pts = (club['points'] as num?)?.toInt() ?? 0;
      
      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '$pts pts',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: podiumHeights[index],
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: podiumColors[index].withValues(alpha: 0.3),
                border: Border.all(color: podiumColors[index]),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: podiumColors[index],
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}
```

---

### B8. Admin — Création de tournoi depuis les clubs

**Prérequis** : Le champ `is_admin` existe sur les users (migration `013_user_admin_flag.sql`).

**Backend — `tournaments.controller.ts`** — Modifier `create()` :

```typescript
@Post()
async create(
  @Body() dto: CreateTournamentDto,
  @Req() req: { user: { id: string; is_guest?: boolean; is_admin?: boolean } },
) {
  if (req.user.is_guest || req.user.id === 'guest') {
    throw new ForbiddenException('Guest account cannot create tournaments');
  }

  // Si un club_id est spécifié, vérifier que l'utilisateur est admin OU président du club
  if (dto.club_id) {
    const isAdmin = req.user.is_admin === true;
    if (!isAdmin) {
      const membership = await this.clubsService.getMembership(dto.club_id, req.user.id);
      if (!membership || membership.role !== 'president') {
        throw new ForbiddenException(
          'Seul un admin ou le président du club peut créer un tournoi pour ce club.',
        );
      }
    }
  }

  return this.tournamentsService.create(dto, req.user.id);
}
```

**Flutter — Écran de création de tournoi** (dans `lib/features/tournaments/`) :

- Ajouter un bouton "Créer un tournoi" visible uniquement si `user.isAdmin == true` ou si l'utilisateur est président du club
- Le formulaire de création doit inclure le `club_id` du club courant

**Fichier** : Vérifier le modèle User pour `isAdmin` :
```dart
// lib/features/auth/models/user_model.dart
class UserModel {
  // ...existing fields...
  final bool isAdmin;  // ← vérifier sa présence
}
```

---

### B9. Configuration de tournoi — Ajout "Classé/Amical" et "Territorial"

**Backend — `CreateTournamentDto`** : `backend/src/modules/tournaments/dto/create-tournament.dto.ts`

Ajouter :
```typescript
@IsBoolean()
@IsOptional()
is_ranked?: boolean;
```

**Note** : `is_territorial` existe déjà dans le DTO.

**Backend — `tournament.entity.ts`** :

Ajouter la colonne :
```typescript
@Column({ type: 'boolean', default: false })
is_ranked: boolean;
```

**Migration SQL** : Ajouter dans `015_club_territory_points.sql` ou créer `016_tournament_ranked.sql` :

```sql
ALTER TABLE tournaments
ADD COLUMN IF NOT EXISTS is_ranked BOOLEAN DEFAULT false;
```

**Backend — `tournaments.service.ts`** :

Lors de la création d'un match depuis un tournoi, utiliser les valeurs `is_ranked` et `is_territorial` du tournoi :

```typescript
// Dans la méthode qui crée les matches de tournoi
const match = this.matchRepo.create({
  mode: tournament.mode,
  finish: tournament.finish,
  is_ranked: tournament.is_ranked,
  is_territorial: tournament.is_territorial,
  tournament_id: tournament.id,
  // ... autres champs ...
});
```

**Flutter — `TournamentModel`** : `lib/features/tournaments/models/tournament_model.dart`

Ajouter :
```dart
final bool isRanked;
final bool isTerritorial;
```

Et dans `fromApi()` :
```dart
isRanked: (json['is_ranked'] as bool?) ?? false,
isTerritorial: (json['is_territorial'] as bool?) ?? false,
```

**Flutter — Écran de création de tournoi** :

Ajouter deux `Switch.adaptive` dans le formulaire :
- "Classé" (is_ranked)
- "Territorial" (is_territorial) — avec la même logique que pour les matchs : si territorial = true, classé est forcé à true

---

## PARTIE C — RÉSUMÉ DES FICHIERS À MODIFIER/CRÉER

### Fichiers à créer :
| Fichier | Description |
|---------|-------------|
| `backend/sql/015_club_territory_points.sql` | Migration : table `club_territory_points` + colonnes `territory_club_id` / `territory_code_iris` sur `matches` + `is_ranked` sur `tournaments` |
| `backend/src/modules/clubs/entities/club-territory-points.entity.ts` | Entité TypeORM `ClubTerritoryPoints` |

### Fichiers à modifier (Backend) :
| Fichier | Modifications |
|---------|---------------|
| `backend/src/modules/clubs/clubs.service.ts` | `create()` : initialiser relation territoire ; `getTerritoryTopClubs()` : nouveau endpoint |
| `backend/src/modules/clubs/clubs.module.ts` | Enregistrer `ClubTerritoryPoints` dans TypeORM |
| `backend/src/modules/matches/entities/match.entity.ts` | Ajouter `territory_club_id`, `territory_code_iris` |
| `backend/src/modules/matches/matches.service.ts` | `createInvitation()` : accepter les nouveaux champs ; `checkMatchCompletion()` : appeler `processTerritoryPoints()` |
| `backend/src/modules/stats/stats.service.ts` | `processTerritoryPoints()` : nouvelle méthode |
| `backend/src/modules/territories/territories.service.ts` | Enrichir `getPanel()` avec `top_clubs` |
| `backend/src/modules/tournaments/dto/create-tournament.dto.ts` | Ajouter `is_ranked` |
| `backend/src/modules/tournaments/entities/tournament.entity.ts` | Ajouter colonne `is_ranked` |
| `backend/src/modules/tournaments/tournaments.controller.ts` | Vérification admin/président pour création club |
| `backend/src/modules/tournaments/tournaments.service.ts` | Propager `is_ranked` / `is_territorial` aux matchs du tournoi |

### Fichiers à modifier (Flutter) :
| Fichier | Modifications |
|---------|---------------|
| `lib/shared/widgets/app_scaffold.dart` | `_DockItem` : utiliser `TweenAnimationBuilder` pour la couleur de l'icône |
| `lib/features/play/presentation/game_setup_screen.dart` | Supprimer `territory` de l'enum ; renommer "Vs Invite" → "Local" ; remplacer `SegmentedButton` par switches ; ajouter switch territorial ; default `_isRanked = false` ; validations B4 |
| `lib/features/match/data/match_service.dart` | Ajouter `territoryClubId`, `territoryCodeIris` dans `createMatchInvitation()` |
| `lib/features/match/models/match_model.dart` | Ajouter `territoryClubId`, `territoryCodeIris` au modèle et parsing |
| `lib/features/map/presentation/map_screen.dart` | Ajouter podium top 3 dans la modale territoire |
| `lib/features/club/controller/club_search_controller.dart` | Ajouter log d'erreur détaillé |
| `lib/features/contacts/models/contact_models.dart` | Ajouter `clubId` si absent |
| `lib/features/tournaments/models/tournament_model.dart` | Ajouter `isRanked`, `isTerritorial` |
| Écran création tournoi (à localiser) | Ajouter switches classé/territorial |

---

## PARTIE D — ORDRE D'EXÉCUTION RECOMMANDÉ

```
1. A5 — Fix bug club search (débloquer la feature clubs)
2. A1 — Fix animation navbar
3. A3 — Default _isRanked = false
4. A2 + A4 — Restructurer options de jeu + switches
5. B1 — Migration SQL + entité ClubTerritoryPoints
6. B2 — Init relation territoire à la création de club
7. B5 — Nouveaux champs match (territory_club_id, territory_code_iris)
8. B3 — QR scanner pour club territorial
9. B4 — Validations avant match territorial
10. B6 — Points territoriaux en fin de match
11. B7 — Podium top 3 sur la carte
12. B9 — Config tournoi classé/territorial
13. B8 — Admin création de tournoi
```

---

## PARTIE E — PROMPT CODEX AUTONOME

Voici le prompt à fournir directement à GPT5-Codex pour exécution autonome :

---

```
Tu es un développeur fullstack expert Flutter + NestJS + PostgreSQL.
Tu travailles sur le projet "Dart District" dont l'architecture est décrite dans `ai_project_guidelines.md`.

## Contexte
- Frontend : Flutter (Riverpod, GoRouter)
- Backend : NestJS (TypeORM, PostgreSQL)
- Conventions : snake_case fichiers, PascalCase classes, camelCase variables
- API wrappée par TransformInterceptor → { success, data, error }

## Tâches à effectuer dans l'ordre :

### BUGS À CORRIGER

1. **`lib/shared/widgets/app_scaffold.dart`** : Le widget `_DockItem` a une animation non fluide lors du changement de page. Envelopper l'`Icon` dans un `TweenAnimationBuilder<Color?>` avec `duration: 250ms` et `Curves.easeInOutCubic` pour animer la transition de couleur entre `AppColors.background` (sélectionné) et `AppColors.textSecondary` (non sélectionné).

2. **`lib/features/play/presentation/game_setup_screen.dart`** :
   a. Supprimer `territory` de l'enum `GameStartOption`
   b. Renommer le label `'Vs Invite'` en `'Local'`
   c. Changer `_isRanked = true` → `_isRanked = false`
   d. Remplacer le `SegmentedButton<bool>` "Classé/Amical" par un `Switch.adaptive` dans un `Container` stylé
   e. Ajouter un nouveau `Switch.adaptive` "Territorial" (état `_isTerritorial`) sous le switch Classé. Quand territorial = true : forcer `_isRanked = true` et désactiver le switch Classé ; ouvrir le QR scanner club (mode `QrScanMode.club`). Stocker le résultat dans `_territoryClub` (ClubModel?) et afficher son nom sous le switch.
   f. Supprimer la méthode `_handleTerritoryScan()` existante et la remplacer par `_handleTerritoryClubScan()` qui ouvre le QR scanner et stocke le ClubModel résultant.
   g. Dans `_startMatch()` : avant l'appel API, si `_isTerritorial && _territoryClub != null`, vérifier que (1) les deux joueurs ne sont pas du même club, et (2) au moins un joueur appartient au club scanné. Sinon, afficher une AlertDialog avec le message d'erreur. Passer `territoryClubId: _territoryClub?.id` et `territoryCodeIris: _territoryClub?.codeIris` dans l'appel `createMatchInvitation()`.

3. **`lib/features/club/controller/club_search_controller.dart`** : Ajouter `debugPrint('Club search error: $e')` dans le catch de `_search()` pour faciliter le débogage. Vérifier que le backend `GET /clubs/search` fonctionne (tester avec un appel sans paramètres).

### NOUVELLES FONCTIONNALITÉS

4. **Créer `backend/sql/015_club_territory_points.sql`** avec :
   - Table `club_territory_points` (id UUID PK, club_id UUID FK clubs, code_iris VARCHAR(9), points INT DEFAULT 0, created_at, updated_at, UNIQUE(club_id, code_iris))
   - Index sur club_id, code_iris, et (code_iris, points DESC)
   - ALTER TABLE matches ADD COLUMN territory_club_id UUID REFERENCES clubs, ADD COLUMN territory_code_iris VARCHAR(9)
   - ALTER TABLE tournaments ADD COLUMN is_ranked BOOLEAN DEFAULT false

5. **Créer `backend/src/modules/clubs/entities/club-territory-points.entity.ts`** : Entité TypeORM @Entity('club_territory_points') avec les champs correspondants et relation @ManyToOne vers Club.

6. **`backend/src/modules/clubs/clubs.service.ts`** :
   - Dans `create()`, après save du club, si `club.code_iris` existe, créer une entrée ClubTerritoryPoints avec 0 points.
   - Ajouter méthode `getTerritoryTopClubs(codeIris: string, limit = 3)` qui retourne les top clubs par points sur un territoire.

7. **`backend/src/modules/matches/entities/match.entity.ts`** : Ajouter `territory_club_id` (UUID nullable) et `territory_code_iris` (VARCHAR(9) nullable).

8. **`backend/src/modules/matches/matches.service.ts`** : Dans `createInvitation()`, accepter et persister `territory_club_id` et `territory_code_iris`.

9. **`backend/src/modules/stats/stats.service.ts`** : Ajouter méthode `processTerritoryPoints(matchId, winnerId, loserId)` qui : charge le match, vérifie is_territorial et territory_code_iris, trouve le club du gagnant via ClubMember, calcule le delta ELO, trouve ou crée l'association ClubTerritoryPoints, et ajoute les points.

10. **`backend/src/modules/matches/matches.service.ts`** : Dans `checkMatchCompletion()`, quand le match est terminé, appeler `processTerritoryPoints()` si `match.is_territorial`.

11. **Endpoint panel territoire** : Enrichir `GET /territories/:codeIris/panel` pour inclure `top_clubs` (top 3 clubs par points sur ce territoire).

12. **`lib/features/map/presentation/map_screen.dart`** : Dans `_openPanelForTerritoryCode()`, parser `top_clubs` depuis panelData et afficher un widget podium (3 colonnes : 2ème à gauche, 1er au centre, 3ème à droite) avec couleurs or/argent/bronze.

13. **`lib/features/match/data/match_service.dart`** : Ajouter paramètres `territoryClubId` et `territoryCodeIris` dans `createMatchInvitation()`.

14. **`backend/src/modules/tournaments/dto/create-tournament.dto.ts`** : Ajouter `@IsBoolean() @IsOptional() is_ranked?: boolean`.

15. **`backend/src/modules/tournaments/entities/tournament.entity.ts`** : Ajouter `@Column({ type: 'boolean', default: false }) is_ranked: boolean`.

16. **`backend/src/modules/tournaments/tournaments.controller.ts`** : Dans `create()`, si `dto.club_id` est fourni, vérifier que l'utilisateur est admin (`req.user.is_admin`) ou président du club. Sinon throw ForbiddenException.

17. **`lib/features/tournaments/models/tournament_model.dart`** : Ajouter `isRanked` et `isTerritorial` avec parsing depuis `fromApi()`.

## Règles :
- Respecter snake_case pour les fichiers, PascalCase pour les classes
- Ne pas modifier la logique métier des widgets (la mettre dans les controllers/services)
- Toujours ajouter les DTO de validation côté backend
- Tester chaque endpoint modifié
- Ne pas casser les fonctionnalités existantes
```

---
