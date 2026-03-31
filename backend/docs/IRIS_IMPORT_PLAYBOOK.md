# IRIS Import Playbook (PostgreSQL)

Ce guide explique le flux recommande pour charger en masse les zones IRIS dans la table territories.

## 1) Ordre SQL

1. backend/sql/001_schema.sql
2. backend/sql/006_iris_territories_refactor.sql (si base existante)
3. backend/sql/007_import_iris_from_csv.sql

## 2) Preparer un CSV d'attributs IRIS

Colonnes attendues:
- code_iris
- name
- insee_com
- nom_com
- nom_iris
- iris_type
- dep_code
- dep_name
- region_code
- region_name
- population
- centroid_lat
- centroid_lng
- area_m2

Note:
- La geometrie n'est pas stockee dans PostgreSQL (elle reste dans PMTiles).
- La carte Flutter utilise PMTiles pour le rendu, puis API statuses/panel pour la couche metier.

## 3) Charger staging_iris_import

Depuis psql:

copy staging_iris_import(code_iris,name,insee_com,nom_com,nom_iris,iris_type,dep_code,dep_name,region_code,region_name,population,centroid_lat,centroid_lng,area_m2) from 'C:/path/iris_attributes.csv' with (format csv, header true, delimiter ',', quote '"');

Puis executer le merge:

- backend/sql/007_import_iris_from_csv.sql

## 4) Verifications

- SELECT COUNT(*) FROM territories;
- SELECT dep_code, COUNT(*) FROM territories GROUP BY dep_code ORDER BY dep_code;
- SELECT COUNT(*) FROM territories WHERE code_iris !~ '^[0-9A-Za-z]{9}$';
- SELECT key, source_url, is_active FROM territory_tilesets;

## 5) Mise a jour metier ensuite

Une fois les IRIS charges:
- API: GET /api/v1/territories/map/statuses
- API: GET /api/v1/territories/:codeIris/panel
- WS: /ws/territory subscribe_map + events territory_status_updated/territory_owner_updated

Tu ne regeneres pas PMTiles pour un simple changement de statut/proprietaire.
