# dart_district

A new Flutter project.

## Environment Variables

Backend:
- Use [backend/.env](backend/.env) for server secrets and OAuth config.
- Google token verification reads GOOGLE_CLIENT_ID (one or more IDs separated by commas).

Flutter:
- Use a local env file copied from [config/flutter.env.example.json](config/flutter.env.example.json).
- Create [config/flutter.env.json](config/flutter.env.json) (ignored by git) and put your local values there.

Example Flutter run commands:

```powershell
flutter run -d chrome --dart-define-from-file=config/flutter.env.json
```

```powershell
flutter run --dart-define-from-file=config/flutter.env.json
```

Notes:
- GOOGLE_WEB_CLIENT_ID is required for Google Sign-In on web.
- GOOGLE_SERVER_CLIENT_ID is used by mobile/web token exchange and backend audience validation alignment.

## IRIS / PMTiles Integration

- Backend IRIS API contract: [backend/docs/TERRITORIES_IRIS_API.md](backend/docs/TERRITORIES_IRIS_API.md)
- Bulk IRIS import playbook: [backend/docs/IRIS_IMPORT_PLAYBOOK.md](backend/docs/IRIS_IMPORT_PLAYBOOK.md)
- Flutter PMTiles integration guide: [docs/FLUTTER_PM_TILES_IRIS_INTEGRATION.md](docs/FLUTTER_PM_TILES_IRIS_INTEGRATION.md)

## MEP (Docker VPS)

Procedure la plus simple pour deployer le backend NestJS en production avec Docker (port 8081) en reutilisant PostgreSQL existant.

Fichiers utilises:
- [backend/Dockerfile](backend/Dockerfile)
- [backend/docker-compose.prod.yml](backend/docker-compose.prod.yml)
- [backend/.env.prod.example](backend/.env.prod.example)

### 1) Preparations (une seule fois)

Sur le VPS, dans le repo clone:

```bash
cd backend
cp .env.prod.example .env.prod
```

Edite `backend/.env.prod`:
- `POSTGRES_PASSWORD`
- `JWT_SECRET`
- variables OAuth Google/Apple
- `DOCKER_NETWORK_NAME` (reseau Docker partage avec Caddy + Postgres)

Pour trouver le reseau Docker:

```bash
docker inspect dartdistrict-postgres-prod --format '{{range $k, $v := .NetworkSettings.Networks}}{{println $k}}{{end}}'
```

### 2) Lancer / mettre a jour le backend (commande unique)

```bash
docker compose -f backend/docker-compose.prod.yml --env-file backend/.env.prod up -d --build
```

### 3) Verifier

```bash
docker ps --filter name=dartdistrict-backend-nest-prod
docker logs -f dartdistrict-backend-nest-prod
```

Si tu exposes temporairement le port local (debug), teste:

```bash
curl http://127.0.0.1:8081/api/docs
```

### 4) Routage Caddy

Canary recommande (nouveau backend sur `/api-nest`):

```caddyfile
dart-district.fr {
  handle_path /api-nest/* {
    reverse_proxy dartdistrict-backend-nest-prod:8081
  }

  handle_path /api/* {
    reverse_proxy dartdistrict-backend-prod:8080
  }
}
```

Reload Caddy:

```bash
docker exec dartdistrict-reverse-proxy caddy reload --config /etc/caddy/Caddyfile
```

### 5) Commandes utiles

Redemarrer:

```bash
docker compose -f backend/docker-compose.prod.yml --env-file backend/.env.prod restart
```

Stopper:

```bash
docker compose -f backend/docker-compose.prod.yml --env-file backend/.env.prod down
```

Notes:
- Ne pas utiliser `localhost` pour `POSTGRES_HOST` dans le conteneur backend.
- Utiliser le nom du conteneur PostgreSQL (`dartdistrict-postgres-prod`) ou son alias reseau.
- Reutiliser la meme base est possible, mais une base dediee est recommandee pendant la transition pour eviter les conflits de migrations.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
