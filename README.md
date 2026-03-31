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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
