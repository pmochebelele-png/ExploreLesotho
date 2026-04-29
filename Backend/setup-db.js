// backend/setup-db.js
require('dotenv').config();
const { MongoClient } = require('mongodb');

async function setupDatabase() {
    const uri = process.env.MONGODB_URI;
    console.log('🚀 Setting up Explore Lesotho Database...');
    
    if (!uri) {
        console.error('❌ MONGODB_URI not found in .env file');
        return;
    }
    
    const client = new MongoClient(uri, {
        serverSelectionTimeoutMS: 30000,
        connectTimeoutMS: 30000,
        ssl: true
    });
    
    try {
        await client.connect();
        console.log('✅ Connected to MongoDB Atlas');
        
        const db = client.db('explore_lesotho');
        
        // Create collections
        const collections = [
            'reviews',
            'reviews_media',
            'user_analytics',
            'ai_recommendations',
            'chat_messages',
            'offline_sync_queue',
            'listing_views',
            'search_history',
            'user_sessions'
        ];
        
        console.log('\n📚 Creating collections...');
        
        for (const collectionName of collections) {
            try {
                await db.createCollection(collectionName);
                console.log(`   ✅ Created: ${collectionName}`);
            } catch (err) {
                if (err.code === 48) {
                    console.log(`   ⚠️  Collection already exists: ${collectionName}`);
                } else {
                    console.log(`   ❌ Error creating ${collectionName}:`, err.message);
                }
            }
        }
        
        // Create indexes
        console.log('\n🔧 Creating indexes...');
        
        // Reviews indexes
        await db.collection('reviews').createIndex({ listing_id: 1 });
        await db.collection('reviews').createIndex({ user_id: 1 });
        await db.collection('reviews').createIndex({ status: 1 });
        console.log('   ✅ Reviews indexes');
        
        // Chat messages indexes
        await db.collection('chat_messages').createIndex({ sender_id: 1, receiver_id: 1 });
        await db.collection('chat_messages').createIndex({ timestamp: -1 });
        console.log('   ✅ Chat messages indexes');
        
        // User analytics indexes
        await db.collection('user_analytics').createIndex({ user_id: 1, timestamp: -1 });
        await db.collection('user_analytics').createIndex({ event_type: 1 });
        console.log('   ✅ User analytics indexes');
        
        console.log('\n✅ Database setup complete!');
        
        // Show collections
        const allCollections = await db.listCollections().toArray();
        console.log(`\n📋 Total collections: ${allCollections.length}`);
        allCollections.forEach(c => console.log(`   - ${c.name}`));
        
    } catch (error) {
        console.error('❌ Setup failed:', error.message);
    } finally {
        await client.close();
        console.log('\n👋 Connection closed');
    }
}

setupDatabase();