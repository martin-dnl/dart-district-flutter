
# AI Project Guidelines (Updated) – Flutter + NestJS Backend + PostgreSQL (dart-district.fr)

## 1. Global Architecture
- **Frontend** : Flutter mobile app (Android & iOS)
- **Backend** : NestJS (Node + TypeScript) — scalable, modular, robust
- **Database** : PostgreSQL on VPS (Debian) accessible via domain `dart-district.fr`
- **Local Storage (Flutter)** : Hive or Drift for offline mode + caching
- **Communication** : REST (CRUD) + WebSockets (real-time)
- **Security** : JWT Auth + HTTPS + environment variables

## 2. Backend Structure (NestJS)
```
backend/
 ├─ src/
 │   ├─ modules/
 │   │    ├─ auth/
 │   │    ├─ users/
 │   │    ├─ items/
 │   │    └─ websocket/
 │   ├─ common/
 │   │    ├─ filters/
 │   │    ├─ interceptors/
 │   │    └─ guards/
 │   ├─ database/
 │   │    ├─ prisma.service.ts (ou TypeORM module)
 │   ├─ main.ts
 │   └─ app.module.ts
 ├─ .env
 └─ package.json
```

### Backend Rules
- DTO obligatoires pour chaque entrée/sortie
- Validation via class-validator
- Modules fortement découplés
- WebSockets via `@WebSocketGateway()`
- Logging structuré
- Pas de logique métier dans les controllers

## 3. Frontend Structure (Flutter)
```
lib/
 ├─ core/
 │   ├─ network/
 │   │    ├─ api_client.dart
 │   │    └─ websocket_client.dart
 │   ├─ errors/
 │   ├─ database/
 │   └─ config/
 ├─ features/
 │   ├─ auth/
 │   ├─ dashboard/
 │   ├─ items/
 │   └─ realtime/
 ├─ shared/
 │   ├─ widgets/
 │   └─ utils/
 └─ main.dart
```

### Flutter Rules
- Architecture feature-first
- State management recommandé : Riverpod
- Aucune logique métier dans les Widgets
- API client isolé dans `core/network`
- WebSocket client dans `core/network/websocket_client.dart`
- Stockage local pour accélérer l’app + offline

## 4. Database Policies (PostgreSQL)
- Utiliser migrations (Prisma/Migrate ou TypeORM migrations)
- Indexer les colonnes utilisées en recherche
- Ne jamais exposer directement un schéma DB au frontend
- Accès DB encapsulé dans des services
- Transactions pour opérations multi-étapes

## 5. API Rules
- Tous les endpoints versionnés : `/api/v1/...`
- Réponses formatées `{ success, data, error }`
- JWT obligatoire sauf quelques endpoints publics
- HTTPS seulement

## 6. WebSockets
- Utiliser un Namespace par fonctionnalité
- Petits payloads
- Heartbeat toutes les 30–60s
- Reconnexion côté Flutter

## 7. Security Policies
- Aucun secret dans le repo : tout dans `.env`
- JWT robuste (RS256 recommandé)
- Rate limiting sur endpoints sensibles
- Sanitization systématique (class-sanitizer)

## 8. File Naming Conventions
- **snake_case** : fichiers Flutter & backend
- **PascalCase** : classes
- **camelCase** : variables et méthodes

## 9. Git & CI/CD
- Branches : `main`, `dev`, `feature/*`
- CI : lint + tests
- CD : déploiement automatisé sur VPS Debian

## 10. Instructions pour les IA (GitHub Copilot / Cursor)

### GitHub Copilot
Créer ce fichier :
```
.github/copilot.md
```
Et y copier **intégralement ce document**.

Copilot s'en sert comme *global rule set*.

### Cursor AI
Créer :
```
.cursor/
 └─ rules/
      ├─ architecture.mdc
      ├─ backend.mdc
      ├─ flutter.mdc
      ├─ database.mdc
      └─ security.mdc
```
Y copier les sections correspondantes.

### Règles d’interprétation pour les IA
- Considérer ce fichier comme **source d'autorité n°1**.
- Toujours générer du code conforme aux structures décrites.
- Respecter le découpage en modules.
- Éviter toute logique métier dans :
  - widgets Flutter
  - controllers NestJS
- Respecter strictement les conventions de nommage.
- Toujours proposer :
  - DTO
  - service
  - controller
  - test minimal

### Patch Notes
- A chaque merge dans master qui modifie le comportement utilisateur, ajouter une entree dans lib/core/config/patch_notes.dart.
- Incrementer version dans pubspec.yaml et ajouter l'entree correspondante dans patchNotes avec la date du jour.
- Les nouveautes vont dans highlights, les bugs corriges dans fixes.

## 11. Emplacement officiel des fichiers de règles
- Racine du repo : `ai_project_guidelines.md`
- Copilot : `.github/copilot.md`
- Cursor : `.cursor/rules/*.mdc`

## 12. Backend Deployment (Debian)
- Utiliser PM2 pour Node
- Créer service système si besoin
- Reverse proxy via Nginx
- HTTPS via Certbot Let’s Encrypt

