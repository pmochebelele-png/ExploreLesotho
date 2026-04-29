// config/databases.js
require('dotenv').config();
const mysql = require('mysql2/promise');
const { MongoClient } = require('mongodb');

// MYSQL CONNECTION POOL
const mysqlPool = mysql.createPool({
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '123456789',
    database: process.env.DB_NAME || 'explore_lesotho',
    port: process.env.DB_PORT || 3306,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    enableKeepAlive: true
});

// MONGODB CONNECTION
let mongoClient;
let mongoDb;

async function connectMongo() {
    if (mongoDb) return mongoDb;
    
    try {
        const uri = process.env.MONGODB_URI;
        
        if (!uri) {
            throw new Error('MONGODB_URI is not defined in .env file');
        }
        
        console.log('📡 Connecting to MongoDB Atlas...');
        
        // Connection options for MongoDB Atlas
        const options = {
            serverSelectionTimeoutMS: 30000,
            connectTimeoutMS: 30000,
            socketTimeoutMS: 45000,
            // SSL/TLS settings for Atlas
            ssl: true,
            tlsAllowInvalidCertificates: false,
            tlsAllowInvalidHostnames: false,
            // Retry settings
            retryWrites: true,
            retryReads: true,
            w: 'majority'
        };
        
        mongoClient = new MongoClient(uri, options);
        await mongoClient.connect();
        
        // Get database name
        let dbName = 'explore_lesotho';
        try {
            // Try to extract database name from URI
            const url = new URL(uri.replace('mongodb://', 'http://'));
            const path = url.pathname.substring(1);
            if (path && path !== '') {
                dbName = path.split('?')[0];
            }
        } catch (e) {
            console.log('Using default database name: explore_lesotho');
        }
        
        mongoDb = mongoClient.db(dbName);
        console.log(`✅ MongoDB Atlas connected successfully to database: ${dbName}`);
        return mongoDb;
    } catch (error) {
        console.error('❌ MongoDB Atlas connection failed:', error.message);
        console.log('\n💡 Troubleshooting Tips:');
        console.log('   1. Check your MongoDB Atlas connection string in .env file');
        console.log('   2. Make sure your IP is whitelisted in MongoDB Atlas Network Access');
        console.log('   3. Verify username and password are correct');
        console.log('   4. Check if your cluster is active (not paused)');
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