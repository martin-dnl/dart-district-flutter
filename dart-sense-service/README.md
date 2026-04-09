# Dart Sense Service

Service FastAPI pour detection de flechettes.

## Lancer localement

```bash
docker compose up -d --build
```

## Endpoint

- `POST /detect` multipart avec champ `image`
- Reponse:

```json
{
  "success": true,
  "data": {
    "darts": []
  }
}
```

## Notes

- `app/detector.py` est un placeholder et doit etre remplace par l'inference YOLO.
- Le modele attendu peut etre fourni via `MODEL_PATH`.
