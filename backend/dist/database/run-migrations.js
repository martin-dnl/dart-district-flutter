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
async function resolveMigrationFiles(sqlDir) {
    const explicitFiles = (process.env.MIGRATION_FILES ?? '')
        .split(',')
        .map((value) => value.trim())
        .filter(Boolean);
    if (explicitFiles.length > 0) {
        return explicitFiles.map((file) => path.resolve(sqlDir, file));
    }
    return [path.resolve(sqlDir, '006_iris_territories_refactor.sql')];
}
async function main() {
    const projectRoot = process.cwd();
    await loadDotEnv(projectRoot);
    const sqlDir = path.resolve(process.cwd(), 'sql');
    const existingEntries = new Set(await (0, promises_1.readdir)(sqlDir));
    const migrationFiles = await resolveMigrationFiles(sqlDir);
    for (const filePath of migrationFiles) {
        const fileName = path.basename(filePath);
        if (!existingEntries.has(fileName)) {
            throw new Error(`Migration file not found: ${fileName}`);
        }
    }
    const client = new Client({
        host: process.env.POSTGRES_HOST || 'localhost',
        port: parseInt(process.env.POSTGRES_PORT ?? '5432', 10),
        user: process.env.POSTGRES_USER || 'dart_district',
        password: process.env.POSTGRES_PASSWORD || 'dart_district',
        database: process.env.POSTGRES_DB || 'dart_district',
    });
    await client.connect();
    try {
        for (const filePath of migrationFiles) {
            const sql = await (0, promises_1.readFile)(filePath, 'utf8');
            await client.query(sql);
            process.stdout.write(`Applied migration ${path.basename(filePath)}\n`);
        }
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
//# sourceMappingURL=run-migrations.js.map