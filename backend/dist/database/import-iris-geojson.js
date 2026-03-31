"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const promises_1 = require("fs/promises");
const path = require("path");
const { Client } = require('pg');
async function loadDotEnv(projectRoot) {
    const envPath = path.resolve(projectRoot, '.env');
    let content = '';
    try {
        content = await (0, promises_1.readFile)(envPath, 'utf8');
    }
    catch {
        return;
    }
    for (const rawLine of content.split(/\r?\n/)) {
        const line = rawLine.trim();
        if (!line || line.startsWith('#')) {
            continue;
        }
        const separatorIndex = line.indexOf('=');
        if (separatorIndex <= 0) {
            continue;
        }
        const key = line.slice(0, separatorIndex).trim();
        const value = line.slice(separatorIndex + 1).trim().replace(/^['\"]|['\"]$/g, '');
        if (!process.env[key]) {
            process.env[key] = value;
        }
    }
}
function flattenCoordinates(value, acc) {
    if (!Array.isArray(value) || value.length === 0) {
        return;
    }
    const first = value[0];
    if (value.length >= 2 &&
        typeof value[0] === 'number' &&
        typeof value[1] === 'number') {
        acc.push([value[0], value[1]]);
        return;
    }
    if (Array.isArray(first)) {
        for (const child of value) {
            flattenCoordinates(child, acc);
        }
    }
}
function centroidFromGeometry(geometry) {
    if (!geometry || !geometry.coordinates) {
        return null;
    }
    const points = [];
    flattenCoordinates(geometry.coordinates, points);
    if (points.length === 0) {
        return null;
    }
    let minLng = Number.POSITIVE_INFINITY;
    let maxLng = Number.NEGATIVE_INFINITY;
    let minLat = Number.POSITIVE_INFINITY;
    let maxLat = Number.NEGATIVE_INFINITY;
    for (const [lng, lat] of points) {
        if (lng < minLng)
            minLng = lng;
        if (lng > maxLng)
            maxLng = lng;
        if (lat < minLat)
            minLat = lat;
        if (lat > maxLat)
            maxLat = lat;
    }
    return {
        lat: (minLat + maxLat) / 2,
        lng: (minLng + maxLng) / 2,
    };
}
function depCodeFromInsee(codeInsee) {
    if (!codeInsee || codeInsee.length < 2) {
        return null;
    }
    if (codeInsee.startsWith('97') && codeInsee.length >= 3) {
        return codeInsee.slice(0, 3);
    }
    return codeInsee.slice(0, 2);
}
function normalizeFeature(feature) {
    const props = feature.properties ?? {};
    const codeIris = (props.code_iris ?? '').toString().trim();
    if (!codeIris || codeIris.length !== 9) {
        return null;
    }
    const codeInseeRaw = (props.code_insee ?? '').toString().trim();
    const codeInsee = codeInseeRaw || null;
    const nomCommune = (props.nom_commune ?? '').toString().trim() || codeIris;
    const nomIris = (props.nom_iris ?? '').toString().trim() || nomCommune;
    const irisTypeRaw = (props.type_iris ?? '').toString().trim();
    const irisType = irisTypeRaw || null;
    const centroid = centroidFromGeometry(feature.geometry);
    if (!centroid) {
        return null;
    }
    return {
        codeIris,
        codeInsee,
        nomCommune,
        nomIris,
        irisType,
        depCode: depCodeFromInsee(codeInsee),
        latitude: centroid.lat,
        longitude: centroid.lng,
    };
}
async function upsertBatch(client, batch) {
    if (batch.length === 0) {
        return;
    }
    const values = [];
    const rowsSql = [];
    batch.forEach((row, i) => {
        const base = i * 12;
        rowsSql.push(`($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5}, $${base + 6}, $${base + 7}, $${base + 8}, $${base + 9}, $${base + 10}, $${base + 11}, $${base + 12}, 'available', NOW())`);
        values.push(row.codeIris, row.codeIris, row.nomIris, row.nomCommune, row.nomIris, row.codeInsee, row.nomCommune, row.nomIris, row.irisType, row.depCode, row.latitude, row.longitude);
    });
    const sql = `
    INSERT INTO territories (
      code_iris,
      code,
      name,
      city,
      district,
      insee_com,
      nom_com,
      nom_iris,
      iris_type,
      dep_code,
      latitude,
      longitude,
      status,
      updated_at
    )
    VALUES
      ${rowsSql.join(',\n      ')}
    ON CONFLICT (code_iris) DO UPDATE
      SET
        code = EXCLUDED.code,
        name = EXCLUDED.name,
        city = EXCLUDED.city,
        district = EXCLUDED.district,
        insee_com = EXCLUDED.insee_com,
        nom_com = EXCLUDED.nom_com,
        nom_iris = EXCLUDED.nom_iris,
        iris_type = EXCLUDED.iris_type,
        dep_code = EXCLUDED.dep_code,
        latitude = EXCLUDED.latitude,
        longitude = EXCLUDED.longitude,
        updated_at = NOW();
  `;
    await client.query(sql, values);
}
async function main() {
    const projectRoot = process.cwd();
    await loadDotEnv(projectRoot);
    const geojsonPath = process.argv[2]
        ? path.resolve(projectRoot, process.argv[2])
        : path.resolve(projectRoot, '..', 'iris_data', 'iris_france.geojson');
    const raw = await (0, promises_1.readFile)(geojsonPath, 'utf8');
    const parsed = JSON.parse(raw);
    if (parsed.type !== 'FeatureCollection' || !Array.isArray(parsed.features)) {
        throw new Error('Invalid GeoJSON file. Expected a FeatureCollection.');
    }
    const rows = parsed.features
        .map(normalizeFeature)
        .filter((row) => row !== null);
    if (rows.length === 0) {
        throw new Error('No valid IRIS rows parsed from GeoJSON file.');
    }
    const client = new Client({
        host: process.env.POSTGRES_HOST || 'localhost',
        port: parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
        user: process.env.POSTGRES_USER || 'dart_district',
        password: process.env.POSTGRES_PASSWORD || 'dart_district',
        database: process.env.POSTGRES_DB || 'dart_district',
    });
    await client.connect();
    const batchSize = 500;
    try {
        await client.query('BEGIN');
        for (let i = 0; i < rows.length; i += batchSize) {
            const batch = rows.slice(i, i + batchSize);
            await upsertBatch(client, batch);
        }
        await client.query('COMMIT');
        process.stdout.write(`Imported/updated ${rows.length} IRIS territories from ${geojsonPath}\n`);
    }
    catch (error) {
        await client.query('ROLLBACK');
        throw error;
    }
    finally {
        await client.end();
    }
}
main().catch((error) => {
    const message = error instanceof Error ? error.stack ?? error.message : String(error);
    process.stderr.write(`${message}\n`);
    process.exit(1);
});
//# sourceMappingURL=import-iris-geojson.js.map