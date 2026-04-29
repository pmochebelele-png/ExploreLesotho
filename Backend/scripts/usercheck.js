// check-user.js
const mysql = require('mysql2/promise');
require('dotenv').config();

async function check() {
    console.log('🔍 Checking for user in MySQL...\n');
    
    const conn = await mysql.createConnection({
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '12345',  // Your password
        database: 'explore_lesotho'
    });

    const [users] = await conn.execute(
        "SELECT user_id, email, full_name, role FROM users WHERE email = 'thabo.molapo@explorelesotho.co.ls'"
    );

    if (users.length > 0) {
        console.log('✅ USER FOUND IN MYSQL:');
        console.log('   user_id:', users[0].user_id);
        console.log('   email:', users[0].email);
        console.log('   name:', users[0].full_name);
        console.log('   role:', users[0].role);
    } else {
        console.log('❌ User NOT found in MySQL');
        console.log('\n📝 Run this SQL to add the user:');
        console.log(`
INSERT INTO users (email, password_hash, full_name, role, phone) 
VALUES (
    'thabo.molapo@explorelesotho.co.ls',
    'MONGODB_AUTH_ONLY',
    'Thabo Molapo',
    'tourist',
    '+26658889999'
);
        `);
    }

    await conn.end();
}

check().catch(console.error);