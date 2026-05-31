require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

function getMysqlConfigFromUrl() {
    const uri = process.env.MYSQL_URL || process.env.MYSQL_PUBLIC_URL || process.env.DATABASE_URL;
    if (!uri || !uri.startsWith('mysql://')) {
        return null;
    }

    const url = new URL(uri);
    return {
        host: url.hostname,
        port: Number(url.port || 3306),
        user: decodeURIComponent(url.username),
        password: decodeURIComponent(url.password),
        database: url.pathname.replace(/^\//, '') || 'railway',
    };
}

function getMysqlConfig() {
    return getMysqlConfigFromUrl() || {
        host: process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
        port: Number(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
        user: process.env.DB_USER || process.env.MYSQLUSER || 'root',
        password: process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '12345',
        database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'explore_lesotho',
    };
}

async function main() {
    const reset = process.argv.includes('--reset');
    const inputPath = process.argv.slice(2).find((arg) => arg !== '--reset');
    if (!inputPath) {
        throw new Error('Usage: node scripts/import-sql-file.js [--reset] <path-to-sql-file>');
    }

    const sqlPath = path.resolve(process.cwd(), inputPath);
    if (!fs.existsSync(sqlPath)) {
        throw new Error(`SQL file not found: ${sqlPath}`);
    }

    const config = getMysqlConfig();
    let sql = fs.readFileSync(sqlPath, 'utf8')
        .replace(/\/\*![\s\S]*?\*\//g, '')
        .replace(/^LOCK TABLES .*?;\s*$/gim, '')
        .replace(/^UNLOCK TABLES;\s*$/gim, '')
        .replace(/^\s*;\s*$/gim, '');

    if (!reset) {
        sql = sql
            .replace(/^DROP TABLE IF EXISTS .*?;\s*$/gim, '')
            .replace(/CREATE TABLE `/g, 'CREATE TABLE IF NOT EXISTS `')
            .replace(/INSERT INTO `/g, 'INSERT IGNORE INTO `');
    }

    const connection = await mysql.createConnection({
        ...config,
        multipleStatements: true,
    });

    try {
        console.log(`Importing ${path.basename(sqlPath)} into ${config.host}:${config.port}/${config.database}...`);
        console.log(reset ? 'Reset mode enabled: existing tables may be dropped.' : 'Safe mode enabled: existing tables will not be dropped.');
        await connection.query(sql);
        console.log('SQL import completed successfully.');
    } finally {
        await connection.end();
    }
}

main().catch((error) => {
    console.error('SQL import failed:', error.message);
    process.exit(1);
});
