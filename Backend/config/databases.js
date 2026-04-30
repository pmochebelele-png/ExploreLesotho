// config/databases.js
require('dotenv').config();
const mysql = require('mysql2/promise');
const { MongoClient } = require('mongodb');

const SUPPORTED_NODE_MAJOR_MIN = 18;
const SUPPORTED_NODE_MAJOR_MAX = 22;

function getMysqlConfigFromUrl() {
    const uri = process.env.MYSQL_URL || process.env.MYSQL_PUBLIC_URL || process.env.DATABASE_URL;
    if (!uri || !uri.startsWith('mysql://')) {
        return null;
    }

    try {
        const url = new URL(uri);
        return {
            host: url.hostname,
            port: Number(url.port || 3306),
            user: decodeURIComponent(url.username),
            password: decodeURIComponent(url.password),
            database: url.pathname.replace(/^\//, '') || 'railway'
        };
    } catch (error) {
        console.warn('Invalid MySQL connection URL, falling back to individual variables:', error.message);
        return null;
    }
}

function getMysqlConfig() {
    const urlConfig = getMysqlConfigFromUrl();
    if (urlConfig) return urlConfig;

    return {
        host: process.env.DB_HOST || process.env.MYSQLHOST || 'localhost',
        port: Number(process.env.DB_PORT || process.env.MYSQLPORT || 3306),
        user: process.env.DB_USER || process.env.MYSQLUSER || 'root',
        password: process.env.DB_PASSWORD || process.env.MYSQLPASSWORD || '12345',
        database: process.env.DB_NAME || process.env.MYSQLDATABASE || 'explore_lesotho'
    };
}

// MYSQL CONNECTION POOL
const mysqlConfig = getMysqlConfig();
const mysqlPool = mysql.createPool({
    ...mysqlConfig,
    waitForConnections: true,
    connectionLimit: Number(process.env.DB_CONNECTION_LIMIT || 10),
    queueLimit: 0,
    enableKeepAlive: true
});

// MONGODB CONNECTION
let mongoClient;
let mongoDb;

function getConfiguredMongoDbName(uri) {
    if (process.env.MONGODB_DB_NAME) {
        return process.env.MONGODB_DB_NAME;
    }

    try {
        const normalizedUri = uri.startsWith('mongodb+srv://')
            ? uri.replace('mongodb+srv://', 'https://')
            : uri.replace('mongodb://', 'https://');
        const url = new URL(normalizedUri);
        const dbName = url.pathname.substring(1).split('?')[0];
        return dbName || 'explore_lesotho';
    } catch (error) {
        return 'explore_lesotho';
    }
}

function assertSupportedNodeVersion() {
    const nodeMajor = Number.parseInt(process.versions.node.split('.')[0], 10);
    if (Number.isNaN(nodeMajor)) {
        return;
    }

    if (nodeMajor < SUPPORTED_NODE_MAJOR_MIN || nodeMajor > SUPPORTED_NODE_MAJOR_MAX) {
        throw new Error(
            `Unsupported Node.js runtime ${process.versions.node}. ` +
            `This project uses the MongoDB driver configured for Node.js ${SUPPORTED_NODE_MAJOR_MIN}-${SUPPORTED_NODE_MAJOR_MAX}. ` +
            'Use Node.js 22 LTS (recommended) or another supported LTS release and try again.'
        );
    }
}

async function connectMongo() {
    if (mongoDb) return mongoDb;
    
    try {
        assertSupportedNodeVersion();

        const uri = process.env.MONGODB_URI;
        
        if (!uri) {
            throw new Error('MONGODB_URI is not defined in .env file');
        }
        
        console.log('📡 Connecting to MongoDB Atlas...');
        
        const options = {
            useNewUrlParser: true,
            useUnifiedTopology: true,
            serverSelectionTimeoutMS: 30000,
            connectTimeoutMS: 30000,
            socketTimeoutMS: 45000,
            retryWrites: true,
            retryReads: true,
            writeConcern: { w: 'majority' }
        };
        
        mongoClient = new MongoClient(uri, options);
        await mongoClient.connect();
        
        const dbName = getConfiguredMongoDbName(uri);
        
        mongoDb = mongoClient.db(dbName);
        console.log('✅ MongoDB Atlas connected successfully');
        return mongoDb;
    } catch (error) {
        console.error('❌ MongoDB Atlas connection failed:', error.message);
        console.log('\n💡 Troubleshooting Tips:');
        console.log(`   1. Use a supported Node.js version (${SUPPORTED_NODE_MAJOR_MIN}-${SUPPORTED_NODE_MAJOR_MAX}); Node.js 22 LTS is recommended`);
        console.log('   2. Check your MongoDB Atlas connection string in .env file');
        console.log('   3. Make sure your IP is whitelisted in MongoDB Atlas Network Access');
        console.log('   4. Verify your username and password are correct');
        console.log('   5. Check if your cluster is active (not paused)');
        console.log('   6. Prefer the Atlas-generated mongodb+srv connection string when possible');
        throw error;
    }
}

// Graceful shutdown
process.on('SIGINT', async () => {
    if (mongoClient) await mongoClient.close();
    if (mysqlPool) await mysqlPool.end();
    process.exit(0);
});

module.exports = {
    mysqlPool,
    connectMongo,
    getMongoDb: () => mongoDb
};
