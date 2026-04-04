# Plan d'implémentation – Création & Gestion de Club

> Document d'analyse complète avec prompts IA (GPT-5 Codex) pour chaque étape.
> Basé sur l'analyse du codebase existant : architecture feature-first, Riverpod, Go Router, Dio, NestJS + TypeORM + PostgreSQL.

---

## Table des matières

1. [Vue d'ensemble & architecture](#1-vue-densemble--architecture)
2. [PHASE 1 – Backend : Enrichissement du module Clubs](#phase-1)
3. [PHASE 2 – Backend : Endpoint de résolution territoire](#phase-2)
4. [PHASE 3 – Backend : API Map filtrée par clubs](#phase-3)
5. [PHASE 4 – Flutter : Service Google Places](#phase-4)
6. [PHASE 5 – Flutter : Refonte ClubCreateScreen](#phase-5)
7. [PHASE 6 – Flutter : Résolution territoire + Modales](#phase-6)
8. [PHASE 7 – Flutter : Page détail club](#phase-7)
9. [PHASE 8 – Flutter : Clubs sur la carte](#phase-8)
10. [PHASE 9 – Tests & intégration](#phase-9)

---

## 1. Vue d'ensemble & architecture

### Fichiers impactés (existants à modifier)

| Couche | Fichier | Modification |
|--------|---------|--------------|
| Backend Entity | `backend/src/modules/clubs/entities/club.entity.ts` | Ajouter `postal_code`, `country`, `opening_hours` (jsonb) |
| Backend DTO | `backend/src/modules/clubs/dto/create-club.dto.ts` | Ajouter champs ville, CP, pays, nb cibles, horaires |
| Backend Service | `backend/src/modules/clubs/clubs.service.ts` | Logique résolution territoire, endpoint map filtré |
| Backend Controller | `backend/src/modules/clubs/clubs.controller.ts` | Nouvel endpoint `POST /clubs/resolve-territory` |
| Backend Territories | `backend/src/modules/territories/territories.service.ts` | Modifier `getTilesetMetadata()` → filtrage par clubs |
| Frontend Model | `lib/features/club/models/club_model.dart` | Ajouter champs correspondants |
| Frontend Screen | `lib/features/club/presentation/club_create_screen.dart` | Refonte complète avec Google Places |
| Frontend Screen | `lib/features/club/presentation/club_detail_screen.dart` | Refonte complète avec TabBar |
| Frontend Map | `lib/features/map/presentation/map_screen.dart` | Ajouter marqueurs club dartboard |
| Frontend Map | `lib/features/map/controller/map_controller.dart` | Charger clubs pour markers |

### Fichiers à créer

| Couche | Fichier | Rôle |
|--------|---------|------|
| Frontend Service | `lib/core/network/google_places_service.dart` | Autocomplete + Place Details API |
| Frontend Widget | `lib/features/club/widgets/territory_confirmation_modal.dart` | Modale confirmation territoire |
| Frontend Widget | `lib/features/club/widgets/territory_not_found_modal.dart` | Modale aucun territoire |
| Frontend Widget | `lib/features/club/widgets/club_map_marker.dart` | Icône dartboard pour la carte |
| Frontend Widget | `lib/features/club/widgets/club_map_modal.dart` | Modale info club sur la carte |
| Frontend Widget | `lib/features/club/widgets/opening_hours_input.dart` | Widget saisie horaires semaine |
| Backend DTO | `backend/src/modules/clubs/dto/resolve-territory.dto.ts` | DTO résolution territoire |

---

<a id="phase-1"></a>
## PHASE 1 – Backend : Enrichissement du module Clubs

### Étape 1.1 – Migration SQL : nouveaux champs club

**Objectif** : Ajouter les colonnes `postal_code`, `country`, `opening_hours` à la table `clubs`.

#### Prompt IA :

```
CONTEXTE :
- Projet NestJS + TypeORM + PostgreSQL
- Fichier de migration : backend/sql/014_club_creation_enhancements.sql
- Table existante `clubs` (voir backend/src/modules/clubs/entities/club.entity.ts)
- Colonnes existantes : id, name, description, avatar_url, address, city, region, latitude, longitude, code_iris, conquest_points, dart_boards_count, rank, status, created_at, updated_at

TÂCHE :
Crée le fichier SQL de migration backend/sql/014_club_creation_enhancements.sql qui :
1. Ajoute la colonne `postal_code VARCHAR(10) NULL` à la table clubs
2. Ajoute la colonne `country VARCHAR(100) NULL DEFAULT 'France'` à la table clubs
3. Ajoute la colonne `opening_hours JSONB NULL` à la table clubs
   - Format attendu : {"monday": {"open": "10:00", "close": "22:00"}, "tuesday": {...}, ...}
   - Les jours sans horaires signifient fermé
4. Ajoute un commentaire SQL sur chaque colonne

Ne PAS toucher aux colonnes existantes.
Utiliser ALTER TABLE ... ADD COLUMN IF NOT EXISTS.
```

---

### Étape 1.2 – Mise à jour de l'entité Club

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/clubs/entities/club.entity.ts
- Entité TypeORM existante avec les colonnes : id, name, description, avatar_url, address, city, region, latitude, longitude, code_iris, conquest_points, dart_boards_count, rank, status, created_at, updated_at, members (relation)

TÂCHE :
Ajoute à l'entité Club les colonnes suivantes (après la colonne `region`) :
1. `postal_code` : varchar(10), nullable
2. `country` : varchar(100), nullable, default 'France'
3. `opening_hours` : type 'jsonb', nullable
   - Typer en TypeScript comme : Record<string, { open: string; close: string }> | null

Respecter exactement le style existant des @Column déclarations.
Ne PAS modifier les colonnes/relations existantes.
```

---

### Étape 1.3 – Mise à jour du CreateClubDto

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/clubs/dto/create-club.dto.ts
- DTO existant avec : name (string required), address (string optional), latitude (number optional), longitude (number optional), code_iris (string optional)
- Utilise class-validator pour la validation

TÂCHE :
Enrichis le CreateClubDto avec les champs suivants :
1. `city` : string, optionnel, @IsString, @IsOptional, @MaxLength(100)
2. `postal_code` : string, optionnel, @IsString, @IsOptional, @MaxLength(10)
3. `country` : string, optionnel, @IsString, @IsOptional, @MaxLength(100)
4. `dart_boards_count` : number, optionnel, @IsNumber, @IsOptional, @Min(0), @Max(100)
5. `opening_hours` : objet, optionnel, @IsOptional, @IsObject
   - Type TS : Record<string, { open: string; close: string }>
6. `google_place_id` : string, optionnel, @IsString, @IsOptional
   - Servira pour traçabilité future

Garder TOUS les champs existants intacts.
Respecter le style et les imports existants.
```

---

### Étape 1.4 – Mise à jour du ClubsService.create()

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/clubs/clubs.service.ts
- Méthode create(dto: CreateClubDto, userId: string) existante
- La méthode actuelle :
  1. Résout le code IRIS le plus proche si lat/lng fournis
  2. Crée le club
  3. Ajoute le créateur comme membre president
  4. Retourne le club avec membres
- Méthode existante : resolveNearestCodeIris(lat, lng) qui requête les territoires par distance

TÂCHE :
Modifie la méthode create() pour :
1. Sauvegarder les nouveaux champs (city, postal_code, country, dart_boards_count, opening_hours) dans le club créé
2. NE PLUS ajouter automatiquement le créateur comme membre du club
   - Supprimer/commenter le bloc qui fait clubMemberRepository.save({ club_id, user_id, role: 'president' })
   - Le créateur admin n'est pas associé au club (un utilisateur ne peut avoir qu'un seul club)
3. Garder la résolution de code_iris si lat/lng fournis (mais elle sera aussi dispo via le nouvel endpoint)
4. Retourner le club créé (sans membres puisqu'il n'y en a pas)

Ne PAS modifier les autres méthodes.
```

---

<a id="phase-2"></a>
## PHASE 2 – Backend : Endpoint de résolution territoire

### Étape 2.1 – DTO de résolution territoire

#### Prompt IA :

```
CONTEXTE :
- Projet NestJS, utilise class-validator
- Nouveau fichier : backend/src/modules/clubs/dto/resolve-territory.dto.ts

TÂCHE :
Crée un DTO ResolveTerritoryDto avec :
1. `latitude` : number, required, @IsNumber, @Min(-90), @Max(90)
2. `longitude` : number, required, @IsNumber, @Min(-180), @Max(180)

Ce DTO sera utilisé pour résoudre le territoire (IRIS) à partir de coordonnées GPS.
Suivre le style des autres DTOs du projet (imports, decorators).
```

---

### Étape 2.2 – Endpoint POST /clubs/resolve-territory

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/clubs/clubs.controller.ts
- Controller NestJS existant avec les endpoints CRUD clubs
- Le service a déjà une méthode resolveNearestCodeIris(lat, lng) qui retourne un code IRIS
- Le module territories a une méthode findByCodeIris(codeIris) qui retourne le territoire complet (name, nom_com, code_iris, dep_name, region_name, centroid_lat, centroid_lng)
- Format réponse standard : { success: boolean, data: T | null, error: string | null }

TÂCHE :
Ajoute un nouvel endpoint dans clubs.controller.ts :

POST /clubs/resolve-territory
- Guard : JWT (l'utilisateur doit être connecté)
- Body : ResolveTerritoryDto { latitude, longitude }
- Logique :
  1. Appeler clubsService.resolveNearestCodeIris(dto.latitude, dto.longitude)
  2. Si aucun code IRIS trouvé → retourner { success: false, data: null, error: 'no_territory_found' }
  3. Si trouvé → charger le territoire complet via territoriesService.findByCodeIris(codeIris)
  4. Retourner { success: true, data: { code_iris, name, city: nom_com, department: dep_name, region: region_name, latitude: centroid_lat, longitude: centroid_lng } }

Injecter le TerritoriesService dans le ClubsModule si nécessaire (via imports dans clubs.module.ts).
Importer le nouveau DTO.
```

---

### Étape 2.3 – Améliorer resolveNearestCodeIris avec seuil de distance

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/clubs/clubs.service.ts
- Méthode existante : resolveNearestCodeIris(lat, lng) qui fait un query sur territories triées par distance et retourne le code_iris le plus proche
- Problème : si le club est en dehors de France ou très loin de tout territoire IRIS, on ne veut PAS l'associer

TÂCHE :
Modifie resolveNearestCodeIris pour :
1. Calculer la distance réelle (formule haversine) entre les coordonnées reçues et le centroïde du territoire le plus proche
2. Si la distance > 5 km → retourner null (aucun territoire assez proche)
3. Si la distance <= 5 km → retourner le code_iris comme avant
4. Ajouter un paramètre optionnel maxDistanceKm avec une valeur par défaut de 5

La formule haversine est probablement déjà utilisée dans le service search() pour les clubs géolocalisés. Réutiliser la même logique.
```

---

<a id="phase-3"></a>
## PHASE 3 – Backend : API Map filtrée par clubs

### Étape 3.1 – Modifier le tileset pour ne servir que les zones avec clubs

#### Prompt IA :

```
CONTEXTE :
- Fichier : backend/src/modules/territories/territories.service.ts
- Méthode existante getTilesetMetadata() qui retourne les métadonnées PMTiles (source_url, zoom, bounds, etc.)
- Actuellement, le frontend charge TOUTES les tuiles IRIS de France
- Objectif : ne charger que les zones qui ont au minimum un club associé (club.code_iris IS NOT NULL)

APPROCHE RECOMMANDÉE :
Le PMTiles est un fichier statique pré-généré, on ne peut pas le filtrer dynamiquement.
La solution est de filtrer côté rendu frontend en fournissant la liste des code_iris actifs.

TÂCHE :
1. Créer une nouvelle méthode getActiveIrisCodes() dans territories.service.ts :
   - Requête : SELECT DISTINCT code_iris FROM clubs WHERE code_iris IS NOT NULL
   - Retourne un Set<string> de codes IRIS ayant au moins un club
2. Créer un nouvel endpoint GET /territories/tileset/active-zones dans territories.controller.ts :
   - Retourne { success: true, data: { codes: string[] } }
   - Pas de guard JWT (public, utilisé par la carte)
3. Alternativement, enrichir l'endpoint existant GET /territories/tileset pour inclure un champ `active_codes: string[]`

Le frontend utilisera cette liste pour ne dessiner que les polygones IRIS dont le code est dans cette liste.
```

---

<a id="phase-4"></a>
## PHASE 4 – Flutter : Service Google Places

### Étape 4.1 – Créer le service Google Places

#### Prompt IA :

```
CONTEXTE :
- Projet Flutter, architecture feature-first
- Fichier existant similaire à utiliser comme modèle : lib/core/network/nominatim_service.dart (service HTTP basique avec Dio)
- La clé API Google est stockée dans config/flutter.env.json sous la clé "google_places_api_key"
- Le projet utilise Dio pour les requêtes HTTP (lib/core/network/api_client.dart)

TÂCHE :
Créer le fichier lib/core/network/google_places_service.dart avec :

1. Classe GooglePlacesService
2. Méthode autocomplete(String query) :
   - Appelle l'API Google Places Autocomplete (New) :
     POST https://places.googleapis.com/v1/places:autocomplete
   - Headers : X-Goog-Api-Key, Content-Type: application/json
   - Body : { "input": query, "includedPrimaryTypes": ["bar", "restaurant", "establishment", "sports_complex", "bowling_alley"], "languageCode": "fr" }
   - Retourne List<PlaceSuggestion> avec : placeId, mainText, secondaryText
   - Debounce pas nécessaire ici (géré côté widget)

3. Méthode getPlaceDetails(String placeId) :
   - Appelle l'API Google Places Details (New) :
     GET https://places.googleapis.com/v1/places/{placeId}
   - Headers : X-Goog-Api-Key, X-Goog-FieldMask: displayName,formattedAddress,location,addressComponents,regularOpeningHours
   - Retourne un PlaceDetails avec :
     - name (displayName.text)
     - formattedAddress
     - latitude, longitude (location.latitude, location.longitude)
     - city (extrait de addressComponents où type contient "locality")
     - postalCode (type "postal_code")
     - country (type "country")
     - openingHours : Map<String, OpeningPeriod> (lundi→dimanche avec open/close)

4. Classes modèles dans le même fichier :
   - PlaceSuggestion { placeId, mainText, secondaryText }
   - PlaceDetails { name, formattedAddress, latitude, longitude, city, postalCode, country, openingHours }
   - OpeningPeriod { open, close } (format "HH:mm")

5. Gestion d'erreurs : try/catch avec retour liste vide ou null
6. Timeout de 5 secondes

Utiliser Dio directement (pas l'ApiClient du projet qui est pour le backend dart-district).
Lire la clé API depuis les variables d'environnement Flutter.
```

---

### Étape 4.2 – Provider Riverpod pour Google Places

#### Prompt IA :

```
CONTEXTE :
- Le projet utilise Riverpod pour le state management
- Les providers réseau sont dans lib/core/network/api_providers.dart
- Modèle : final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

TÂCHE :
Ajouter dans lib/core/network/api_providers.dart (ou créer un fichier dédié lib/core/network/google_places_providers.dart) :

1. Un Provider<GooglePlacesService> :
   final googlePlacesServiceProvider = Provider<GooglePlacesService>((ref) {
     return GooglePlacesService();
   });

Importer google_places_service.dart.
```

---

<a id="phase-5"></a>
## PHASE 5 – Flutter : Refonte ClubCreateScreen

### Étape 5.1 – Widget de saisie des horaires

#### Prompt IA :

```
CONTEXTE :
- Projet Flutter, design dark theme (AppColors.background, AppColors.surface, AppColors.textPrimary, etc.)
- Police : GoogleFonts.manrope pour le corps, GoogleFonts.rajdhani pour les titres
- Style des inputs existant : fond AppColors.surface, bordure AppColors.stroke, border radius 12

TÂCHE :
Créer le widget lib/features/club/widgets/opening_hours_input.dart :

1. Widget OpeningHoursInput (StatefulWidget) :
   - Paramètre : ValueChanged<Map<String, dynamic>> onChanged
   - Paramètre optionnel : Map<String, dynamic>? initialValue

2. Affiche 7 lignes (Lundi à Dimanche) :
   - Chaque ligne a :
     - Un Switch pour activer/désactiver le jour (fermé par défaut)
     - Le nom du jour
     - Si activé : deux TimePicker boutons (Ouverture / Fermeture) avec format HH:mm
   - Design compact, adapté au formulaire existant

3. Callbacks :
   - À chaque changement, appeler onChanged avec le Map complet :
     { "monday": { "open": "10:00", "close": "22:00" }, ... }
   - Les jours désactivés ne sont PAS inclus dans le Map

4. Style cohérent avec le thème dark du projet :
   - Texte : AppColors.textPrimary
   - Switch : couleur active AppColors.primary
   - TimePicker : utiliser showTimePicker natif Flutter

Importer : app_colors.dart, google_fonts
```

---

### Étape 5.2 – Refonte complète du ClubCreateScreen

#### Prompt IA :

```
CONTEXTE :
- Fichier existant : lib/features/club/presentation/club_create_screen.dart
- Le formulaire actuel n'a que 2 champs : nom et adresse (optionnel)
- Services disponibles :
  - GooglePlacesService avec autocomplete(query) et getPlaceDetails(placeId) (via googlePlacesServiceProvider)
  - ApiClient pour les appels backend (via apiClientProvider)
- Design : dark theme, AppColors, GoogleFonts.rajdhani (titres), GoogleFonts.manrope (corps)
- Widget disponible : OpeningHoursInput pour les horaires
- Résolution territoire via : POST /clubs/resolve-territory { latitude, longitude }

TÂCHE :
Réécrire entièrement club_create_screen.dart avec :

### FORMULAIRE :
1. **Champ Nom du club** (TextFormField) :
   - Pendant la saisie (après 3 caractères), appeler GooglePlacesService.autocomplete(query) avec un debounce de 500ms
   - Afficher les suggestions dans une ListView (overlay ou intégré sous le champ) :
     - Chaque suggestion affiche : mainText (gras) + secondaryText (gris)
   - Au clic sur une suggestion → appeler getPlaceDetails(placeId)
   - Remplir automatiquement les champs : adresse, ville, code postal, pays avec les données retournées
   - Stocker latitude/longitude en mémoire (non affichés dans le formulaire)

2. **Champ Adresse** (TextFormField, pré-rempli si Places)
3. **Champ Ville** (TextFormField, pré-rempli si Places)
4. **Champ Code postal** (TextFormField, pré-rempli si Places)
5. **Champ Pays** (TextFormField, pré-rempli si Places, défaut "France")
6. **Champ Nombre de cibles** (TextFormField, type numérique, validation 1-100)
7. **Widget OpeningHoursInput** pour les horaires de la semaine

### BOUTON CRÉER :
Au clic sur "Créer le club" :
1. Valider le formulaire (_formKey)
2. Si latitude/longitude disponibles (issus de Google Places) :
   - Appeler POST /clubs/resolve-territory { latitude, longitude }
3. Si latitude/longitude NON disponibles :
   - Utiliser l'API Nominatim (NominatimService existant) ou Google Geocoding pour résoudre les coordonnées depuis l'adresse saisie
   - Puis appeler POST /clubs/resolve-territory
4. Selon la réponse :
   - Si error == 'no_territory_found' → afficher TerritoryNotFoundModal
   - Si success == true → afficher TerritoryConfirmationModal avec les infos du territoire
5. Si confirmé dans la modale → appeler POST /clubs avec tous les champs + code_iris du territoire
6. Afficher un SnackBar de succès et naviguer vers la page club

### UX :
- Les champs pré-remplis par Google Places sont éditables
- Loader pendant les appels API
- Les suggestions Google Places disparaissent quand on sélectionne ou clique ailleurs
- Chaque champ a un label au-dessus (style _label existant)
- Le formulaire est scrollable (ListView)

Conserver le style existant (Container avec cardGradient, border AppColors.stroke, etc.)
Utiliser ConsumerStatefulWidget + ConsumerState avec ref.read() pour les providers.
```

---

<a id="phase-6"></a>
## PHASE 6 – Flutter : Modales de résolution territoire

### Étape 6.1 – Modale "Aucun territoire trouvé"

#### Prompt IA :

```
CONTEXTE :
- Projet Flutter, dark theme (AppColors)
- Polices : GoogleFonts.rajdhani (titres), GoogleFonts.manrope (corps)
- Convention : les modales utilisent showModalBottomSheet ou showDialog

TÂCHE :
Créer lib/features/club/widgets/territory_not_found_modal.dart :

1. Fonction statique show(BuildContext context) qui affiche un Dialog :
   - Icône : Icons.location_off_rounded, taille 48, couleur AppColors.error
   - Titre : "Aucun territoire trouvé"
   - Message : "Impossible de localiser un territoire pour cette adresse. Vérifiez l'adresse ou essayez un autre emplacement."
   - UN SEUL bouton : "Retour" (TextButton) qui ferme la modale
   - Pas de bouton de confirmation → l'utilisateur reste sur le formulaire de création

2. Style :
   - DialogTheme dark : background AppColors.surface, border radius 16
   - Texte centré
   - Padding confortable (24px)
```

---

### Étape 6.2 – Modale "Confirmation du territoire"

#### Prompt IA :

```
CONTEXTE :
- Même style que TerritoryNotFoundModal
- Données reçues de l'API : code_iris, name, city, department, region

TÂCHE :
Créer lib/features/club/widgets/territory_confirmation_modal.dart :

1. Classe TerritoryConfirmationModal avec méthode statique :
   Future<bool> show(BuildContext context, { required String name, required String city, String? department, String? region })
   - Retourne true si confirmé, false sinon

2. Contenu du Dialog :
   - Icône : Icons.map_rounded, taille 48, couleur AppColors.primary
   - Titre : "Territoire identifié"
   - Infos affichées dans un Container stylisé :
     - "Nom : {name}"
     - "Ville : {city}"
     - "Département : {department}" (si disponible)
     - "Région : {region}" (si disponible)
   - Message : "Ce club sera associé à ce territoire. Confirmer ?"
   - Deux boutons :
     - "Annuler" (TextButton) → retourne false
     - "Confirmer" (FilledButton, couleur AppColors.primary) → retourne true

3. Style cohérent dark theme.
```

---

<a id="phase-7"></a>
## PHASE 7 – Flutter : Page détail club

### Étape 7.1 – Refonte complète du ClubDetailScreen

#### Prompt IA :

```
CONTEXTE :
- Fichier existant : lib/features/club/presentation/club_detail_screen.dart
- Actuellement : page vide avec juste "Club detail - $id"
- Le ClubModel existant contient : id, name, city, address, imageUrl, memberCount, dartBoardsCount, zonesControlled, rank, members (List<ClubMember>)
- Le backend a un endpoint GET /clubs/:id qui retourne le club complet avec membres
- Le backend a GET /tournaments?club_id=:id pour les tournois du club
- Widget existant : MemberListTile (lib/features/club/widgets/member_list_tile.dart)
- Packages disponibles : url_launcher (pour ouvrir Maps/Waze)

TÂCHE :
Réécrire entièrement club_detail_screen.dart :

### STRUCTURE :
1. **En-tête (SliverAppBar ou fixe)** :
   - Nom du club (grand, rajdhani)
   - Adresse complète cliquable :
     - Au clic → ouvrir l'application de navigation (Maps/Waze/Plans) via url_launcher
     - Utiliser launchUrl avec scheme `geo:` pour Android ou `maps:` pour iOS
     - Format : `geo:0,0?q={address encodée}` (fonctionne sur Android et iOS)
   - Ville, code postal
   - Icône dartboard + nombre de cibles
   - Stats : rang, zones contrôlées, membres

2. **TabBar** (sous l'en-tête) avec 2 onglets :
   - **"Tournois en cours"** : liste des tournois actifs du club
   - **"Membres"** : liste des membres avec MemberListTile

3. **TabBarView** :
   - Onglet Tournois :
     - Charger depuis GET /tournaments?club_id={clubId}
     - Afficher nom tournoi, mode, statut, nombre de participants
     - Si aucun tournoi : message "Aucun tournoi en cours"
   - Onglet Membres :
     - Utiliser les membres du ClubModel
     - Afficher avec MemberListTile existant
     - Tri par rôle (président > capitaine > joueur) puis par ELO desc

### TECHNIQUE :
- ConsumerStatefulWidget avec TabController (TickerProviderStateMixin)
- Charger le club via FutureProvider ou dans initState avec apiClientProvider
- Utiliser le package url_launcher pour l'ouverture navigation
- Gérer les états loading/error

### STYLE :
- Dark theme cohérent (AppColors)
- TabBar : indicateur AppColors.primary, texte blanc
- Tab non sélectionnée : texte AppColors.textSecondary
```

---

### Étape 7.2 – Mise à jour du ClubModel

#### Prompt IA :

```
CONTEXTE :
- Fichier : lib/features/club/models/club_model.dart
- Champs actuels : id, name, city, address, imageUrl, memberCount, dartBoardsCount, zonesControlled, rank, members

TÂCHE :
Ajouter les champs suivants au ClubModel :
1. `postalCode` (String?) 
2. `country` (String?)
3. `latitude` (double?)
4. `longitude` (double?)
5. `openingHours` (Map<String, dynamic>?)
6. `codeIris` (String?)

Mettre à jour :
- Le constructeur (paramètres nommés optionnels)
- La factory fromApi() pour parser les nouveaux champs depuis la réponse API :
  - postal_code → postalCode
  - country → country
  - latitude → latitude (parser en double si string)
  - longitude → longitude (parser en double si string)
  - opening_hours → openingHours
  - code_iris → codeIris
- La factory fromJson() si utilisée pour le cache local

Ne PAS supprimer les champs existants.
```

---

<a id="phase-8"></a>
## PHASE 8 – Flutter : Clubs sur la carte

### Étape 8.1 – Marqueur dartboard pour la carte

#### Prompt IA :

```
CONTEXTE :
- La carte utilise flutter_map (package Leaflet-like pour Flutter)
- Les marqueurs sont ajoutés via MarkerLayer avec une liste de Marker widgets
- Le MapController charge déjà les clubs via GET /clubs/map qui retourne : id, name, latitude, longitude, address, city, member_count
- L'état MapState a déjà un champ pour les club markers

TÂCHE :
Créer lib/features/club/widgets/club_map_marker.dart :

1. Widget ClubMapMarker (StatelessWidget) :
   - Affiche une icône de dartboard (cible de fléchettes)
   - Taille : 36x36 pixels
   - Utiliser soit :
     - Un IconData personnalisé
     - Ou un Container circulaire avec un icon Icons.my_location ou Icons.track_changes stylisé pour ressembler à une cible
     - Ou un widget CustomPaint qui dessine une cible (3 cercles concentriques + bull's eye)
   - Couleur : AppColors.primary pour la base, cercle rouge au centre
   - Ombre portée légère pour la visibilité sur la carte

2. Le widget doit être utilisable comme child d'un Marker flutter_map :
   Marker(
     point: LatLng(lat, lng),
     width: 36,
     height: 36,
     child: ClubMapMarker(),
   )
```

---

### Étape 8.2 – Modale info club sur la carte

#### Prompt IA :

```
CONTEXTE :
- Projet Flutter, dark theme
- Au clic sur un marqueur de club sur la carte, une modale doit apparaître
- Données disponibles : clubId, name, address, city

TÂCHE :
Créer lib/features/club/widgets/club_map_modal.dart :

1. Fonction statique show(BuildContext context, { required String clubId, required String name, required String address, String? city }) :
   - Utilise showModalBottomSheet
   - Contenu :
     - Icône dartboard (même style que le marqueur)
     - Nom du club (grand, rajdhani, bold)
     - Adresse complète (manrope, textSecondary)
     - Ville si disponible
     - Bouton "Voir le club" (FilledButton) → context.push('/club/$clubId')
   - Style : dark theme, border radius top 16, background AppColors.surface
   - Hauteur : wrap_content (pas de hauteur fixe)
   - Drag handle en haut (petit rectangle gris centré)
```

---

### Étape 8.3 – Intégrer les marqueurs clubs dans MapScreen

#### Prompt IA :

```
CONTEXTE :
- Fichier : lib/features/map/presentation/map_screen.dart
- La carte utilise FlutterMap avec plusieurs layers : TileLayer (fond de carte), VectorTileLayer (IRIS/PMTiles), MarkerLayer (position utilisateur)
- Le MapController charge les clubs via GET /clubs/map et les stocke dans MapState
- Les données club sont : List<Map> avec { id, name, latitude, longitude, address, city }
- Widgets créés : ClubMapMarker et ClubMapModal

TÂCHE :
Modifier map_screen.dart pour :

1. Ajouter un nouveau MarkerLayer APRÈS le VectorTileLayer existant :
   - Pour chaque club dans state.clubMarkers, créer un Marker :
     - point: LatLng(club.latitude, club.longitude)
     - width: 36, height: 36
     - child: GestureDetector(
         onTap: () => ClubMapModal.show(context, clubId: club.id, name: club.name, address: club.address, city: club.city),
         child: const ClubMapMarker(),
       )

2. Les marqueurs ne s'affichent QUE si le zoom est >= 10 (pour éviter la surcharge visuelle à zoom lointain)

3. Si le MapController ne charge pas encore les clubs (GET /clubs/map), ajouter l'appel dans la méthode de chargement initiale.

NE PAS casser les layers existants (tiles, IRIS vectors, user position).
Ajouter le MarkerLayer clubs entre le VectorTileLayer et le MarkerLayer de position utilisateur.
```

---

### Étape 8.4 – Filtrer les tuiles IRIS aux zones avec clubs

#### Prompt IA :

```
CONTEXTE :
- Fichier : lib/features/map/presentation/map_screen.dart
- Le rendu des tuiles IRIS utilise VectorTileLayer avec PmTilesVectorTileProvider
- Les polygones IRIS sont stylisés dans un theme/style function qui reçoit chaque feature avec ses propriétés (dont le code IRIS)
- Le nouvel endpoint GET /territories/tileset/active-zones retourne { codes: string[] } = liste des codes IRIS ayant un club

TÂCHE :
Modifier le rendu des tuiles vectorielles pour :

1. Au chargement de la carte, appeler GET /territories/tileset/active-zones pour récupérer les codes IRIS actifs
2. Dans la fonction de style des features IRIS :
   - Si le code IRIS de la feature N'EST PAS dans la liste des codes actifs → ne PAS dessiner le polygone (retourner un style transparent ou ne pas inclure la feature)
   - Si le code IRIS EST dans la liste → appliquer le style normal (avec la couleur basée sur le statut : available, conquered, etc.)

3. Stocker la liste active_codes dans le MapState ou en variable locale du widget

Cela fera que seuls les territoires avec au moins un club seront visibles sur la carte.
```

---

<a id="phase-9"></a>
## PHASE 9 – Tests & intégration

### Étape 9.1 – Tests backend

#### Prompt IA :

```
CONTEXTE :
- Backend NestJS avec Jest pour les tests
- Module clubs avec ClubsService et ClubsController modifiés

TÂCHE :
Écrire les tests unitaires pour :

1. ClubsService.create() :
   - Vérifie que les nouveaux champs (city, postal_code, country, dart_boards_count, opening_hours) sont sauvegardés
   - Vérifie que le créateur N'EST PAS ajouté comme membre
   - Vérifie que resolve-territory est appelé si lat/lng présents

2. ClubsService.resolveNearestCodeIris() :
   - Test avec coordonnées dans un territoire → retourne un code IRIS
   - Test avec coordonnées trop lointaines (>5km) → retourne null

3. ClubsController POST /clubs/resolve-territory :
   - Test 200 avec territoire trouvé
   - Test 200 avec aucun territoire (no_territory_found)
   - Test 401 sans JWT

4. TerritoriesService.getActiveIrisCodes() :
   - Retourne les codes IRIS des clubs existants
   - Retourne liste vide si aucun club

Utiliser les mocks TypeORM standard du projet.
```

---

### Étape 9.2 – Tests Flutter

#### Prompt IA :

```
CONTEXTE :
- Tests Flutter dans test/features/
- Utilise flutter_test et mockito ou mocktail pour les mocks
- Riverpod : utiliser ProviderScope.overrides pour les tests

TÂCHE :
Écrire les tests widget pour :

1. ClubCreateScreen :
   - Vérifie que le formulaire affiche tous les champs (nom, adresse, ville, CP, pays, nb cibles, horaires)
   - Vérifie que les suggestions Google Places apparaissent après saisie de 3+ caractères
   - Vérifie que la sélection d'une suggestion remplit les champs automatiquement
   - Vérifie que le bouton "Créer" déclenche la résolution de territoire

2. TerritoryNotFoundModal :
   - Vérifie que seul le bouton "Retour" est affiché
   - Vérifie que le bouton ferme la modale

3. TerritoryConfirmationModal :
   - Vérifie que les infos territoire sont affichées
   - Vérifie que "Confirmer" retourne true
   - Vérifie que "Annuler" retourne false

4. ClubDetailScreen :
   - Vérifie que le TabBar a 2 onglets
   - Vérifie que l'adresse est cliquable
   - Vérifie l'affichage des membres

Mocker GooglePlacesService et ApiClient.
```

---

## Résumé de l'ordre d'exécution

```
PHASE 1 (Backend - Club entity/DTO)
  ├── 1.1 Migration SQL
  ├── 1.2 Entity update
  ├── 1.3 DTO update
  └── 1.4 Service update

PHASE 2 (Backend - Territory resolution)
  ├── 2.1 DTO résolution
  ├── 2.2 Endpoint resolve-territory
  └── 2.3 Seuil distance haversine

PHASE 3 (Backend - Map filtrage)
  └── 3.1 Active IRIS codes endpoint

PHASE 4 (Flutter - Google Places)
  ├── 4.1 Service Google Places
  └── 4.2 Provider Riverpod

PHASE 5 (Flutter - ClubCreateScreen)
  ├── 5.1 Widget horaires
  └── 5.2 Refonte formulaire

PHASE 6 (Flutter - Modales)
  ├── 6.1 Modale "pas de territoire"
  └── 6.2 Modale "confirmation territoire"

PHASE 7 (Flutter - Club detail)
  ├── 7.1 Refonte ClubDetailScreen
  └── 7.2 Update ClubModel

PHASE 8 (Flutter - Map clubs)
  ├── 8.1 Marqueur dartboard
  ├── 8.2 Modale info club
  ├── 8.3 Intégration MapScreen
  └── 8.4 Filtrage tuiles IRIS

PHASE 9 (Tests)
  ├── 9.1 Tests backend
  └── 9.2 Tests Flutter
```

### Dépendances entre phases

```
PHASE 1 ──→ PHASE 2 ──→ PHASE 6 (modales dépendent de l'API)
                    └──→ PHASE 5 (formulaire appelle resolve-territory)
PHASE 3 ──→ PHASE 8.4 (filtrage côté Flutter)
PHASE 4 ──→ PHASE 5 (formulaire utilise Google Places)
PHASE 7.2 ──→ PHASE 7.1 (detail screen utilise le model enrichi)
PHASE 8.1 + 8.2 ──→ PHASE 8.3 (intégration dans MapScreen)
TOUT ──→ PHASE 9 (tests en dernier)
```

---

## Notes techniques importantes

### Clé API Google Places
- Stocker dans `config/flutter.env.json` et `.env` backend
- Restreindre la clé aux APIs : Places API (New), Geocoding API
- Restreindre par package name / bundle ID en production

### Performances carte
- Les marqueurs clubs ne s'affichent qu'à zoom >= 10
- Les tuiles IRIS ne s'affichent que pour les zones avec clubs
- Le endpoint `active-zones` peut être mis en cache 5 min côté frontend

### Sécurité
- L'endpoint resolve-territory nécessite JWT (éviter l'abus)
- La clé Google Places NE DOIT PAS être dans le code source → env vars
- Valider côté backend que le créateur est bien admin et non guest
