require('dotenv').config();
const mysql = require('mysql2/promise');

async function checkListings() {
    console.log('🔍 Checking MySQL listings...\n');
    
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST || 'localhost',
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '',
        database: 'explore_lesotho'
    });

    try {
        // Check if listings table exists
        const [tables] = await connection.execute(
            "SHOW TABLES LIKE 'listings'"
        );
        
        if (tables.length === 0) {
            console.log('❌ Listings table does not exist!');
            return;
        }

        // Get all listings
        const [listings] = await connection.execute(`
            SELECT l.*, v.business_name 
            FROM listings l
            LEFT JOIN vendors v ON l.vendor_id = v.vendor_id
        `);
        
        console.log(`📊 Found ${listings.length} listings:\n`);
        
        if (listings.length === 0) {
            console.log('❌ No listings found. Creating test listing...\n');
            
            // Create test vendor first
            await connection.execute(`
                INSERT INTO users (email, password_hash, full_name, role) 
                VALUES ('vendor@explorelesotho.co.ls', 'dummyhash', 'Maletsunyane Adventures', 'vendor')
            `);
            
            const [vendorResult] = await connection.execute(`
                INSERT INTO vendors (user_id, business_name, business_type, verified) 
                VALUES (LAST_INSERT_ID(), 'Maletsunyane Falls Adventures', 'tour_operator', TRUE)
            `);
            
            // Create test listing
            const [listingResult] = await connection.execute(`
                INSERT INTO listings (vendor_id, title, description, category, price, location, district, status) 
                VALUES (?, 'Maletsunyane Falls Abseiling', 'World\'s highest commercial abseil - 204 meters!', 'experience', 850.00, 'Semonkong', 'Maseru', 'active')
            `, [vendorResult.insertId]);
            
            console.log(`✅ Test listing created with ID: ${listingResult.insertId}`);
            
            // Show the new listing
            const [newListing] = await connection.execute(`
                SELECT l.*, v.business_name 
                FROM listings l
                JOIN vendors v ON l.vendor_id = v.vendor_id
                WHERE l.listing_id = ?
            `, [listingResult.insertId]);
            
            console.table(newListing);
            
        } else {
            // Show existing listings
            console.table(listings.map(l => ({
                id: l.listing_id,
                title: l.title,
                category: l.category,
                price: l.price,
                status: l.status,
                vendor: l.business_name || 'Unknown'
            })));
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
        
        // If tables don't exist, create them
        if (error.message.includes('doesn\'t exist')) {
            console.log('\n📝 Tables missing! Please run your MySQL schema first.');
        }
    } finally {
        await connection.end();
    }
}

checkListings();