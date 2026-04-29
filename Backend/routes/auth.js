// backend/routes/auth.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { mysqlPool, getMongoDb } = require('../config/databases');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this';

// Helper to generate token
const generateToken = (userId, email, role) => {
    return jwt.sign({ id: userId, email, role }, JWT_SECRET, { expiresIn: '7d' });
};

const generateResetToken = () => crypto.randomBytes(32).toString('hex');
const hashResetToken = (token) =>
    crypto.createHash('sha256').update(token).digest('hex');

const normalizeName = (value) =>
    (value ?? '').toString().trim().replace(/\s+/g, ' ').toLowerCase();

async function ensureCultureClaimColumns(connection) {
    const requiredColumns = [
        { name: 'linked_vendor_id', definition: 'BIGINT NULL' },
        { name: 'linked_vendor_user_id', definition: 'BIGINT NULL' },
        { name: 'claimed_at', definition: 'TIMESTAMP NULL DEFAULT NULL' },
    ];

    for (const column of requiredColumns) {
        const [rows] = await connection.execute(
            `SELECT COUNT(*) AS count
             FROM INFORMATION_SCHEMA.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'culture_vendors'
               AND COLUMN_NAME = ?`,
            [column.name]
        );

        if ((rows[0]?.count ?? 0) === 0) {
            await connection.execute(
                `ALTER TABLE culture_vendors ADD COLUMN ${column.name} ${column.definition}`
            );
        }
    }
}

async function linkCultureVendorToRegisteredVendor(connection, vendorRecord) {
    const normalizedBusinessName = normalizeName(vendorRecord.business_name);
    if (!normalizedBusinessName) {
        return null;
    }

    await ensureCultureClaimColumns(connection);

    const [matches] = await connection.execute(
        `
        SELECT vendor_id
        FROM culture_vendors
        WHERE LOWER(TRIM(name)) = ?
        ORDER BY
            CASE WHEN linked_vendor_id IS NULL THEN 0 ELSE 1 END ASC,
            vendor_id ASC
        LIMIT 1
        `,
        [normalizedBusinessName]
    );

    if (!matches.length) {
        return null;
    }

    const cultureVendorId = Number(matches[0].vendor_id);
    await connection.execute(
        `
        UPDATE culture_vendors
        SET linked_vendor_id = ?,
            linked_vendor_user_id = ?,
            claimed_at = NOW(),
            status = 'active'
        WHERE vendor_id = ?
        `,
        [vendorRecord.vendor_id, vendorRecord.user_id, cultureVendorId]
    );

    return cultureVendorId;
}

// ============================================
// REGISTER TOURIST
// ============================================
router.post('/register', async (req, res) => {
    const { name, email, password, phone } = req.body;
    
    console.log('📝 Registering tourist:', { name, email });
    
    try {
        // Check if user exists in MySQL
        const [existing] = await mysqlPool.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [email]
        );
        
        if (existing.length > 0) {
            return res.status(400).json({ success: false, message: 'Email already registered' });
        }
        
        const connection = await mysqlPool.getConnection();
        await connection.beginTransaction();
        
        try {
            // Hash password
            const hashedPassword = await bcrypt.hash(password, 10);
            
            // Insert into MySQL with password_hash
            const [result] = await connection.execute(
                `INSERT INTO users (full_name, email, role, password_hash, created_at) 
                 VALUES (?, ?, 'tourist', ?, NOW())`,
                [name, email, hashedPassword]
            );
            
            const userId = result.insertId;
            console.log('✅ Tourist inserted into MySQL, ID:', userId);
            
            // Insert into MongoDB
            const db = getMongoDb();
            await db.collection('users').insertOne({
                user_id: userId,
                email: email,
                name: name,
                password: hashedPassword,
                role: 'tourist',
                phone: phone,
                createdAt: new Date(),
                updatedAt: new Date()
            });
            console.log('✅ Tourist inserted into MongoDB');
            
            await connection.commit();
            
            // Generate JWT token
            const token = generateToken(userId, email, 'tourist');
            
            res.json({
                success: true,
                message: 'Registration successful',
                token: token,
                user: {
                    user_id: userId,
                    id: userId.toString(),
                    name: name,
                    email: email,
                    role: 'tourist',
                    phone: phone
                }
            });
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    } catch (error) {
        console.error('❌ Error registering tourist:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// REGISTER VENDOR
// ============================================
router.post('/register-vendor', async (req, res) => {
    const { full_name, email, password, business_name, business_phone, business_address, business_type, phone } = req.body;
    
    console.log('📝 Registering vendor:', { full_name, email, business_name });
    
    try {
        // Check if user exists
        const [existing] = await mysqlPool.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [email]
        );
        
        if (existing.length > 0) {
            return res.status(400).json({ success: false, message: 'Email already registered' });
        }
        
        const connection = await mysqlPool.getConnection();
        await connection.beginTransaction();
        
        try {
            // Hash password
            const hashedPassword = await bcrypt.hash(password, 10);
            
            // Insert into MySQL users table with password_hash
            const [result] = await connection.execute(
                `INSERT INTO users (full_name, email, role, password_hash, created_at) 
                 VALUES (?, ?, 'vendor', ?, NOW())`,
                [full_name, email, hashedPassword]
            );
            
            const userId = result.insertId;
            console.log('✅ Vendor user inserted into MySQL, ID:', userId);
            
            // Insert into MySQL vendors table
            const [vendorResult] = await connection.execute(
                `INSERT INTO vendors (
                    user_id, 
                    business_name, 
                    business_email, 
                    business_phone, 
                    business_type, 
                    business_address,
                    verified, 
                    status, 
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, 0, 'pending', NOW())`,
                [userId, business_name, email, business_phone, business_type, business_address]
            );
            console.log('✅ Vendor record created (pending approval)');

            const vendorId = vendorResult.insertId;
            const linkedCultureVendorId = await linkCultureVendorToRegisteredVendor(connection, {
                vendor_id: vendorId,
                user_id: userId,
                business_name,
            });
            
            // Insert into MongoDB
            const db = getMongoDb();
            await db.collection('users').insertOne({
                user_id: userId,
                email: email,
                name: full_name,
                password: hashedPassword,
                role: 'vendor',
                businessName: business_name,
                phone: phone,
                createdAt: new Date(),
                updatedAt: new Date()
            });
            console.log('✅ Vendor inserted into MongoDB');
            
            await connection.commit();
            
            // Generate JWT token
            const token = generateToken(userId, email, 'vendor');
            
            res.json({
                success: true,
                message: 'Vendor registration successful. Your account is pending approval.',
                token: token,
                user: {
                    user_id: userId,
                    id: userId.toString(),
                    name: full_name,
                    email: email,
                    role: 'vendor',
                    businessName: business_name,
                    verified: false,
                    linkedCultureVendorId: linkedCultureVendorId?.toString() ?? null,
                }
            });
        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }
    } catch (error) {
        console.error('❌ Error registering vendor:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// LOGIN
// ============================================
router.post('/login', async (req, res) => {
    const { email, password } = req.body;
    
    console.log('🔐 Login attempt:', { email });
    
    try {
        // Check in MySQL first
        const [users] = await mysqlPool.execute(
            'SELECT user_id, full_name, email, role, password_hash FROM users WHERE email = ?',
            [email]
        );
        
        if (users.length === 0) {
            return res.status(401).json({ success: false, message: 'Invalid email or password' });
        }
        
        const user = users[0];
        
        // Verify password using bcrypt
        const isValidPassword = await bcrypt.compare(password, user.password_hash);
        
        if (!isValidPassword) {
            return res.status(401).json({ success: false, message: 'Invalid email or password' });
        }
        
        // Check vendor approval if role is vendor
        let businessName = null;
        let verified = true;
        if (user.role === 'vendor') {
            const [vendors] = await mysqlPool.execute(
                'SELECT business_name, verified FROM vendors WHERE user_id = ?',
                [user.user_id]
            );
            if (vendors.length > 0) {
                businessName = vendors[0].business_name;
                verified = vendors[0].verified === 1;
                if (!verified) {
                    return res.status(403).json({ 
                        success: false, 
                        message: 'Your vendor account is pending approval. Please wait for admin approval.' 
                    });
                }
            }
        }
        
        // Generate JWT token
        const token = generateToken(user.user_id, user.email, user.role);
        
        res.json({
            success: true,
            message: 'Login successful',
            token: token,
            user: {
                user_id: user.user_id,
                id: user.user_id.toString(),
                name: user.full_name,
                email: user.email,
                role: user.role,
                businessName: businessName,
                verified: verified
            }
        });
    } catch (error) {
        console.error('❌ Error during login:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// REQUEST PASSWORD RESET
// ============================================
router.post('/forgot-password', async (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({
            success: false,
            message: 'Email is required'
        });
    }

    try {
        const [users] = await mysqlPool.execute(
            'SELECT user_id, full_name, email, role FROM users WHERE email = ?',
            [email]
        );

        // Keep the response generic so the endpoint doesn't reveal which emails exist.
        if (users.length === 0) {
            return res.json({
                success: true,
                message: 'If an account with that email exists, a reset code has been generated.'
            });
        }

        const user = users[0];
        const db = getMongoDb();
        const resetToken = generateResetToken();
        const hashedResetToken = hashResetToken(resetToken);
        const resetExpiresAt = new Date(Date.now() + 15 * 60 * 1000);

        await db.collection('users').updateOne(
            { email: user.email },
            {
                $set: {
                    user_id: user.user_id,
                    email: user.email,
                    name: user.full_name,
                    role: user.role,
                    resetPasswordToken: hashedResetToken,
                    resetPasswordExpiresAt: resetExpiresAt,
                    updatedAt: new Date()
                },
                $setOnInsert: {
                    createdAt: new Date()
                }
            },
            { upsert: true }
        );

        console.log(`🔐 Password reset token for ${user.email}: ${resetToken}`);

        return res.json({
            success: true,
            message: 'If an account with that email exists, a reset code has been generated.',
            resetToken: process.env.NODE_ENV === 'production' ? undefined : resetToken
        });
    } catch (error) {
        console.error('❌ Error requesting password reset:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to start password reset'
        });
    }
});

// ============================================
// RESET PASSWORD
// ============================================
router.post('/reset-password', async (req, res) => {
    const { email, token, password } = req.body;

    if (!email || !token || !password) {
        return res.status(400).json({
            success: false,
            message: 'Email, token and new password are required'
        });
    }

    if (password.length < 8) {
        return res.status(400).json({
            success: false,
            message: 'Password must be at least 8 characters'
        });
    }

    try {
        const db = getMongoDb();
        const hashedToken = hashResetToken(token);
        const mongoUser = await db.collection('users').findOne({
            email,
            resetPasswordToken: hashedToken,
            resetPasswordExpiresAt: { $gt: new Date() }
        });

        if (!mongoUser) {
            return res.status(400).json({
                success: false,
                message: 'Invalid or expired reset code'
            });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        await mysqlPool.execute(
            'UPDATE users SET password_hash = ? WHERE email = ?',
            [hashedPassword, email]
        );

        await db.collection('users').updateOne(
            { email },
            {
                $set: {
                    password: hashedPassword,
                    updatedAt: new Date()
                },
                $unset: {
                    resetPasswordToken: '',
                    resetPasswordExpiresAt: ''
                }
            }
        );

        return res.json({
            success: true,
            message: 'Password reset successful'
        });
    } catch (error) {
        console.error('❌ Error resetting password:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to reset password'
        });
    }
});

// ============================================
// GET ALL USERS (Admin only)
// ============================================
router.get('/admin/users', async (req, res) => {
    try {
        const [users] = await mysqlPool.execute(`
            SELECT u.user_id, u.full_name, u.email, u.role, v.business_name, v.verified
            FROM users u
            LEFT JOIN vendors v ON u.user_id = v.user_id
            ORDER BY u.created_at DESC
        `);
        
        const formattedUsers = users.map(user => ({
            id: user.user_id,
            name: user.full_name,
            email: user.email,
            role: user.role,
            businessName: user.business_name,
            verified: user.verified
        }));
        
        res.json({ success: true, users: formattedUsers });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

module.exports = router;
