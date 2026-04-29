// backend/test-mongo.js
require('dotenv').config();
const { MongoClient } = require('mongodb');

async function testConnection() {
    const uri = process.env.MONGODB_URI;
    console.log('📡 Testing MongoDB Atlas connection...');
    
    if (!uri) {
        console.error('❌ MONGODB_URI not found in .env file');
        return;
    }
    
    // Mask password in log
    const maskedUri = uri.replace(/\/\/.*:.*@/, '//pmochebelele_db_user:***@');
    console.log('URI:', maskedUri);
    
    const options = {
        serverSelectionTimeoutMS: 30000,
        connectTimeoutMS: 30000,
        ssl: true,
        retryWrites: true
    };
    
    const client = new MongoClient(uri, options);
    
    try {
        console.log('📡 Connecting...');
        await client.connect();
        console.log('✅ Connected to MongoDB Atlas successfully!');
        
        const db = client.db('explore_lesotho');
        
        // List collections
        const collections = await db.listCollections().toArray();
        console.log('📊 Collections found:', collections.length);
        collections.forEach(c => console.log(`   - ${c.name}`));
        
        // Insert test document
        const testCollection = db.collection('test_connection');
        await testCollection.insertOne({
            test: true,
            timestamp: new Date(),
            message: 'Connection test successful'
        });
        console.log('✅ Test document inserted');
        
        // Clean up
        await testCollection.deleteMany({});
        console.log('✅ Test document cleaned up');
        
        await client.close();
        console.log('✅ Test complete!');
        
    } catch (error) {
        console.error('❌ Connection failed:', error.message);
        console.log('\n💡 Common Issues:');
        console.log('1. IP not whitelisted - Add your IP in MongoDB Atlas Network Access');
        console.log('2. Wrong password - Check credentials');
        console.log('3. Cluster paused - Make sure cluster is active');
        console.log('4. Network issues - Check your internet connection');
    }
}

testConnection();