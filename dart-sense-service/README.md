# Dart Sense Service

Service FastAPI de detection de flechettes, exploitable en image unique et en
lecture continue video via envoi de frames successives.

## Prerequis

1. Fichier modele present sur le VPS:

```bash
dart-sense-service/app/models/dart_sense.pt
```

2. Docker et Docker Compose disponibles.

## Lancer le service

```bash
cd dart-sense-service
docker compose up -d --build
```

Verifier:

```bash
docker ps --filter name=dartdistrict-dart-sense
docker logs -f --tail 200 dartdistrict-dart-sense
curl -sS http://127.0.0.1:8001/health
```

## Endpoints

### GET /health

Retourne l'etat du service et du chargement modele:

```json
{
  "success": true,
  "model_path": "/app/app/models/dart_sense.pt",
  "ready": true,
  "error": null
}
```

### POST /detect

Multipart avec un fichier `image`.

```bash
curl -sS -X POST -F "image=@./tests/frame.jpg" http://127.0.0.1:8001/detect
```

### POST /detect/batch

Multipart avec plusieurs fichiers `images`, utile pour la video continue.

Parametres query:

- `min_occurrences` (defaut: 2): nombre minimal d'apparitions d'un meme dart
  (zone+multiplier) pour le garder dans le resultat stabilise.
- `max_frames` (defaut: 24): limite de frames traitees par requete.

Exemple:

```bash
curl -sS -X POST \
  -F "images=@./tests/f_0001.jpg" \
  -F "images=@./tests/f_0002.jpg" \
  -F "images=@./tests/f_0003.jpg" \
  "http://127.0.0.1:8001/detect/batch?min_occurrences=2&max_frames=24"
```

## Validation VPS complete

1. Verifier le modele:

```bash
ls -lah dart-sense-service/app/models
test -f dart-sense-service/app/models/dart_sense.pt && echo MODEL_OK || echo MODEL_MISSING
```

2. Build et lancement:

```bash
cd dart-sense-service
docker compose down
docker compose up -d --build
```

3. Validation locale service:

```bash
curl -sS http://127.0.0.1:8001/health | jq
curl -sS -X POST -F "image=@/opt/tests/frame.jpg" http://127.0.0.1:8001/detect | jq
```

4. Validation video continue sur un fichier test:

```bash
mkdir -p /tmp/dartsense_frames
ffmpeg -hide_banner -loglevel error -i /opt/tests/darts.mp4 -vf fps=6,scale=960:-1 /tmp/dartsense_frames/f_%05d.jpg

curl_cmd='curl -sS -X POST "http://127.0.0.1:8001/detect/batch?min_occurrences=2&max_frames=24"'
for f in /tmp/dartsense_frames/*.jpg; do
  curl_cmd="$curl_cmd -F images=@$f"
done
eval "$curl_cmd" | jq
```

### POST /feedback

Enregistre une photo annotee manuellement (zone + multiplicateur) pour le
pipeline d'entrainement.

```bash
curl -sS -X POST \
  -F "image=@./tests/frame.jpg" \
  -F "zone=20" \
  -F "multiplier=3" \
  -F "source=mobile_app" \
  -F "note=vue legere gauche" \
  http://127.0.0.1:8001/feedback | jq
```

Les echantillons sont stockes dans `app/training_feedback` (volume Docker).

## Reverse proxy Caddy (VPS)

Ajouter dans le Caddyfile:

```caddyfile
handle_path /api/dart-sense/* {
  reverse_proxy 127.0.0.1:8001
}
```

Puis recharger Caddy:

```bash
docker exec dartdistrict-reverse-proxy caddy reload --config /etc/caddy/Caddyfile
```

Test public:

```bash
curl -sS https://dart-district.fr/api/dart-sense/health | jq
```
