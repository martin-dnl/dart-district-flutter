# Dart District - IRIS Territories Backend Contract

Ce document definit les APIs REST + WebSocket pour la carte IRIS nationale basee sur PMTiles.

## 1. SQL a appliquer

Ordre recommande:

1. `backend/sql/001_schema.sql` (nouvelle base)
2. `backend/sql/002_seed.sql` (optionnel dev)
3. `backend/sql/003_contacts_tables.sql`
4. `backend/sql/004_friend_requests.sql`
5. `backend/sql/005_match_invitation_flow.sql`
6. `backend/sql/006_iris_territories_refactor.sql` (base existante)

## 2. REST Territories

Base path: `/api/v1/territories`

### GET `/tileset`
Retourne la configuration PMTiles active pour Flutter:

```json
{
  "success": true,
  "data": {
    "key": "iris_france_pmtiles",
    "format": "pmtiles",
    "source_url": "https://dart-district.fr/tiles/converted.pmtiles",
    "attribution": "INSEE + IGN Contours IRIS",
    "minzoom": 0,
    "maxzoom": 14,
    "layer_name": "iris",
    "bounds_west": -5.225,
    "bounds_south": 41.333,
    "bounds_east": 9.85,
    "bounds_north": 51.2,
    "center_lng": 2.2137,
    "center_lat": 46.2276,
    "center_zoom": 6
  },
  "error": null
}
```

### GET `/map/statuses?updated_since=...&status=...&dep_code=...`
Retourne les statuts metier de toutes les zones IRIS (sans geometrie):

```json
{
  "success": true,
  "data": {
    "count": 3,
    "statuses": [
      {
        "code_iris": "751010101",
        "status": "available",
        "owner_club_id": null,
        "updated_at": "2026-03-31T10:35:20.904Z",
        "dep_code": "75"
      }
    ]
  },
  "error": null
}
```

### GET `/:codeIris`
Retourne la fiche complete de la zone.

### GET `/:codeIris/panel`
Retourne les donnees pour le panel detail Flutter:
- `territory`
- `active_duel`
- `latest_events`

### GET `/:codeIris/history`
Historique des changements de statut/proprietaire.

### PATCH `/:codeIris/status`
Body:

```json
{
  "status": "alert",
  "reason": "signalement utilisateur"
}
```

### PATCH `/:codeIris/owner`
Body:

```json
{
  "winner_club_id": "b6c2c8b2-6d77-4a4d-b327-37c902d98c75",
  "event": "duel_won:03f10e9f-4679-4426-8866-1438495f8cd4"
}
```

### POST `/duels`
Body:

```json
{
  "territory_id": "751010101",
  "defender_club_id": "b6c2c8b2-6d77-4a4d-b327-37c902d98c75"
}
```

### GET `/duels/pending`
Retourne les duels en attente pour le club de l'utilisateur courant.

### PATCH `/duels/:id/accept`
Accepte un duel.

### PATCH `/duels/:id/complete`
Body:

```json
{
  "winner_club_id": "b6c2c8b2-6d77-4a4d-b327-37c902d98c75"
}
```

## 3. WebSocket Territories

Namespace: `/ws/territory`

### Client -> Server
- `subscribe_map`: abonnement au flux global carte
- `subscribe_territory`: `{ "code_iris": "751010101" }`

Compat backward:
- `subscribe_territory` accepte aussi `{ "territory_id": "751010101" }`

### Server -> Client
- `territory_status_updated`: delta statut
- `territory_owner_updated`: delta proprietaire
- `duel_request`
- `duel_accepted`
- `duel_completed`
- `map_update` (compatibilite)
- `territory_update` (compatibilite)

Payload type (status/owner):

```json
{
  "code_iris": "751010101",
  "status": "conquered",
  "owner_club_id": "b6c2c8b2-6d77-4a4d-b327-37c902d98c75",
  "updated_at": "2026-03-31T10:42:11.101Z"
}
```

## 4. Contrat Flutter recommande

1. Charger `GET /territories/tileset` au demarrage.
2. Initialiser `VectorTileLayer` (vector_map_tiles + PMTiles provider).
3. Charger `GET /territories/map/statuses`.
4. Colorer via `Match(get('code_iris'), ...)` selon status local map.
5. Ecouter `/ws/territory` + `subscribe_map` pour appliquer les deltas sans recharger tout.
6. Sur tap polygon (`onFeatureTap`): lire `code_iris`, appeler `GET /territories/:codeIris/panel`.
