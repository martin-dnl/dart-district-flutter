/**
 * generate_territory_seed.js
 * Reads iris_france.geojson and writes backend/sql/seeds/002_territories_iris.sql
 * Run from the workspace root:  node generate_territory_seed.js
 */

const fs   = require('fs');
const path = require('path');

const GEOJSON_PATH = path.join(__dirname, 'iris_data', 'iris_france.geojson');
const OUTPUT_PATH  = path.join(__dirname, 'backend', 'sql', 'seeds', '002_territories_iris.sql');
const BATCH_SIZE   = 500;

// ── centroid: average of outer-ring vertices ─────────────────
function centroid(geometry) {
  let ring;
  if (geometry.type === 'Polygon') {
    ring = geometry.coordinates[0];
  } else if (geometry.type === 'MultiPolygon') {
    // Pick the largest ring (most vertices) for best accuracy
    let best = geometry.coordinates[0][0];
    for (const poly of geometry.coordinates) {
      if (poly[0].length > best.length) best = poly[0];
    }
    ring = best;
  } else {
    return { lat: '0.0000000', lng: '0.0000000' };
  }
  let sumLng = 0, sumLat = 0;
  for (const [lng, lat] of ring) { sumLng += lng; sumLat += lat; }
  return {
    lat: (sumLat / ring.length).toFixed(7),
    lng: (sumLng / ring.length).toFixed(7),
  };
}

// ── SQL string escaping ───────────────────────────────────────
function esc(v) {
  if (v === null || v === undefined) return 'NULL';
  return "'" + String(v).replace(/'/g, "''") + "'";
}

// ── dep_code derivation from code_insee ──────────────────────
function depCode(codeInsee) {
  if (!codeInsee) return null;
  // DOM: 971xx–976xx  → 3-char dep_code
  return codeInsee.startsWith('97') ? codeInsee.substring(0, 3) : codeInsee.substring(0, 2);
}

// ── main ─────────────────────────────────────────────────────
console.log('Reading GeoJSON …');
const raw  = fs.readFileSync(GEOJSON_PATH, 'utf8');
console.log('Parsing JSON …');
const data = JSON.parse(raw);
const features = data.features;
console.log(`Features: ${features.length}`);

const header = `-- ============================================================
-- Dart District – Territory seed from INSEE/IGN IRIS data
-- Auto-generated from iris_france.geojson (${features.length} zones)
-- DO NOT EDIT manually – regenerate with generate_territory_seed.js
-- ============================================================

BEGIN;

`;

const footer = '\nCOMMIT;\n';

// Build INSERT batches
const batches = [];
let rows = [];

function flushBatch() {
  if (rows.length === 0) return;
  const cols = `INSERT INTO territories (
  code_iris, name, insee_com, nom_com, nom_iris, iris_type,
  dep_code, dep_name,
  centroid_lat, centroid_lng,
  status, created_at, updated_at
) VALUES\n`;
  batches.push(
    cols +
    rows.join(',\n') +
    '\nON CONFLICT (code_iris) DO UPDATE SET\n' +
    '  nom_com      = EXCLUDED.nom_com,\n' +
    '  nom_iris     = EXCLUDED.nom_iris,\n' +
    '  iris_type    = EXCLUDED.iris_type,\n' +
    '  centroid_lat = EXCLUDED.centroid_lat,\n' +
    '  centroid_lng = EXCLUDED.centroid_lng,\n' +
    '  updated_at   = NOW();\n'
  );
  rows = [];
}

let skipped = 0;
for (const feature of features) {
  const p  = feature.properties;
  const ci = p.code_iris ? String(p.code_iris).trim().toUpperCase() : null;
  if (!ci) { skipped++; continue; }

  const { lat, lng } = centroid(feature.geometry);
  const dc = depCode(p.code_insee);
  const dn = dc ? dc.substring(0, 2) : null;   // dep_name = VARCHAR(2)
  const nm = p.nom_iris || p.nom_commune || ci;

  rows.push(
    `  (${esc(ci)}, ${esc(nm)}, ${esc(p.code_insee)}, ${esc(p.nom_commune)}, ` +
    `${esc(p.nom_iris)}, ${esc(p.type_iris)}, ${esc(dc)}, ${esc(dn)}, ` +
    `${lat}, ${lng}, 'available', NOW(), NOW())`
  );

  if (rows.length >= BATCH_SIZE) flushBatch();
}
flushBatch();

if (skipped > 0) console.warn(`Skipped ${skipped} features with no code_iris.`);

const sql = header + batches.join('\n') + footer;
fs.writeFileSync(OUTPUT_PATH, sql, 'utf8');
const sizeKB = (fs.statSync(OUTPUT_PATH).size / 1024).toFixed(0);
console.log(`Written: ${OUTPUT_PATH}`);
console.log(`Batches: ${batches.length}  |  Size: ${sizeKB} KB`);
