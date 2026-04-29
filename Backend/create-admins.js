// backend/create-admins.js
const bcrypt = require('bcryptjs');
const { mysqlPool, connectMongo } = require('./config/databases');

async function createAdmins() {
    try {
        console.log('🔧 Creating Admin Users...\n');
        
        // Connect to MongoDB
        let db;
        try {
            db = await connectMongo();
            console.log('✅ MongoDB connected successfully\n');
        } catch (mongoError) {
            console.log('⚠️ MongoDB connection failed, continuing with MySQL only\n');
            console.log('   MongoDB error:', mongoError.message);
        }
        
        // List of admins to create
        const admins = [
            {
                full_name: 'Phelehetso Mochebelele',
                email: 'phelehetso@explorelesotho.co.ls',
                password: 'admin123',
                phone: '+26658883476'
            },
            {
                full_name: 'Thato Nkhahle',
                email: 'thato@explorelesotho.co.ls',
                password: 'admin123',
                phone: '+26658883477'
            },
            {
                full_name: 'Pakalitha Thabelo',
                email: 'pakalitha@explorelesotho.co.ls',
                password: 'admin123',
                phone: '+26658883478'
            },
            {
                full_name: 'Mohlapiso Machoba',
                email: 'mohlapiso@explorelesotho.co.ls',
                password: 'admin123',
                phone: '+26658883479'
            },
            {
                full_name: 'Makebile Thabana',
                email: 'makebile@explorelesotho.co.ls',
                password: 'admin123',
                phone: '+26658883480'
            }
        ];
        
        let createdCount = 0;
        let updatedCount = 0;
        
        for (const admin of admins) {
            console.log(`📝 Processing: ${admin.full_name} (${admin.email})`);
            
            // Hash the password
            const hashedPassword = await bcrypt.hash(admin.password, 10);
            
            // Check if admin already exists in MySQL
            const [existingMySQL] = await mysqlPool.execute(
                'SELECT user_id FROM users WHERE email = ?',
                [admin.email]
            );
            
            let userId;
            if (existingMySQL.length > 0) {
                // Update existing user to admin role
                await mysqlPool.execute(
                    'UPDATE users SET role = "admin", full_name = ?, password_hash = ? WHERE email = ?',
                    [admin.full_name, hashedPassword, admin.email]
                );
                
                const [user] = await mysqlPool.execute(
                    'SELECT user_id FROM users WHERE email = ?',
                    [admin.email]
                );
                userId = user[0].user_id;
                console.log(`   ✅ Updated existing user (ID: ${userId}) to admin role`);
                updatedCount++;
            } else {
                // Insert new admin into MySQL users table
                const [result] = await mysqlPool.execute(
                    `INSERT INTO users (full_name, email, role, password_hash, phone, created_at) 
                     VALUES (?, ?, 'admin', ?, ?, NOW())`,
                    [admin.full_name, admin.email, hashedPassword, admin.phone]
                );
                userId = result.insertId;
                console.log(`   ✅ New admin inserted into MySQL, ID: ${userId}`);
                createdCount++;
            }
            
            // Insert into MongoDB if connected
            if (db) {
                try {
                    const usersCollection = db.collection('users');
                    
                    // Check if admin already exists in MongoDB
                    const existingMongo = await usersCollection.findOne({ email: admin.email });
                    
                    if (existingMongo) {
                        // Update existing MongoDB record
                        await usersCollection.updateOne(
                            { email: admin.email },
                            { 
                                $set: { 
                                    name: admin.full_name,
                                    password: hashedPassword,
                                    role: 'admin',
                                    phone: admin.phone,
                                    updatedAt: new Date()
                                } 
                            }
                        );
                        console.log(`   ✅ Updated in MongoDB`);
                    } else {
                        // Insert into MongoDB
                        await usersCollection.insertOne({
                            user_id: userId,
                            email: admin.email,
                            name: admin.full_name,
                            password: hashedPassword,
                            role: 'admin',
                            phone: admin.phone,
                            createdAt: new Date(),
                            updatedAt: new Date()
                        });
                        console.log(`   ✅ Inserted into MongoDB`);
                    }
                } catch (mongoError) {
                    console.log(`   ⚠️ MongoDB error: ${mongoError.message}`);
                }
            } else {
                console.log(`   ⚠️ Skipping MongoDB (not connected)`);
            }
            
            console.log(`   ✅ ${admin.full_name} is now an ADMIN!\n`);
        }
        
        console.log('=================================');
        console.log('✅ ADMIN USERS CREATED SUCCESSFULLY!');
        console.log('=================================');
        console.log(`📊 Summary:`);
        console.log(`   New Admins Created: ${createdCount}`);
        console.log(`   Existing Updated: ${updatedCount}`);
        console.log(`   Total Admins: ${createdCount + updatedCount}`);
        console.log('\n📧 Admin Credentials:');
        console.log('=================================');
        
        for (const admin of admins) {
            console.log(`👤 ${admin.full_name}`);
            console.log(`   Email: ${admin.email}`);
            console.log(`   Password: ${admin.password}`);
            console.log(`   Phone: ${admin.phone}`);
            console.log('---');
        }
        
        // Verify all admins in MySQL
        console.log('\n📊 Verifying Admins in MySQL Database:');
        const [verifyMySQL] = await mysqlPool.execute(
            'SELECT user_id, full_name, email, role, phone FROM users WHERE role = "admin" ORDER BY user_id'
        );
        
        console.log('\nMySQL Users Table:');
        verifyMySQL.forEach(user => {
            console.log(`   ID: ${user.user_id} | Name: ${user.full_name} | Email: ${user.email} | Role: ${user.role}`);
        });
        
        // Verify MongoDB if connected
        if (db) {
            try {
                const verifyMongo = await db.collection('users').find({ role: 'admin' }).toArray();
                console.log('\nMongoDB Users Collection:');
                verifyMongo.forEach(user => {
                    console.log(`   Name: ${user.name} | Email: ${user.email} | Role: ${user.role}`);
                });
            } catch (e) {
                console.log('\n⚠️ Could not verify MongoDB');
            }
        }
        
        console.log('\n✨ Done! You can now log in as any admin.');
        process.exit(0);
        
    } catch (error) {
        console.error('❌ Error creating admins:', error);
        process.exit(1);
    }
}

createAdmins();