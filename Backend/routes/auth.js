// backend/routes/auth.js
const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { mysqlPool, getMongoDb } = require('../config/databases');
const {
    sendEmail,
    verificationEmail,
    passwordResetEmail,
} = require('../utils/mailer');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this';
const ML_SERVICE_BASE_URL = (
    process.env.ML_SERVICE_URL ||
    'http://127.0.0.1:5001/api/ml'
).replace(/\/+$/, '');

// Helper to generate token
const generateToken = (userId, email, role) => {
    return jwt.sign({ id: userId, email, role }, JWT_SECRET, { expiresIn: '7d' });
};

const generateVerificationCode = () =>
    crypto.randomInt(100000, 1000000).toString();
const hashResetToken = (token) =>
    crypto.createHash('sha256').update(token).digest('hex');

const toBoolean = (value) =>
    value === true || value === 1 || value === '1' || value === 'true' || value === 'yes';

const toNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

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

async function runVendorMlVerification(vendorPayload) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);

    try {
        const response = await fetch(`${ML_SERVICE_BASE_URL}/register_vendor`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
            body: JSON.stringify(vendorPayload),
            signal: controller.signal,
        });

        const text = await response.text();
        const payload = text ? JSON.parse(text) : {};
        if (!response.ok || payload.success === false) {
            throw new Error(payload.error || payload.message || 'ML verifier rejected the request');
        }

        return payload.result?.decision || payload.decision || null;
    } catch (error) {
        console.warn('Vendor ML verification unavailable:', error.message);
        return null;
    } finally {
        clearTimeout(timeout);
    }
}

async function sendAccountVerification({ db, email, name, role, userId }) {
    const code = generateVerificationCode();
    const hashedCode = hashResetToken(code);
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000);
    const emailContent = verificationEmail({ name, code });

    const sent = await sendEmail({
        to: email,
        subject: emailContent.subject,
        text: emailContent.text,
        html: emailContent.html,
    });

    if (!sent) return false;

    await db.collection('users').updateOne(
        { email },
        {
            $set: {
                user_id: userId,
                email,
                name,
                role,
                emailVerified: false,
                emailVerificationRequired: true,
                emailVerificationToken: hashedCode,
                emailVerificationExpiresAt: expiresAt,
                updatedAt: new Date(),
            },
            $setOnInsert: {
                createdAt: new Date(),
            },
        },
        { upsert: true }
    );

    return true;
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
            let emailVerificationSent = false;
            if (db) {
            await db.collection('users').insertOne({
                user_id: userId,
                email: email,
                name: name,
                password: hashedPassword,
                role: 'tourist',
                phone: phone,
                emailVerified: false,
                emailVerificationRequired: false,
                createdAt: new Date(),
                updatedAt: new Date()
            });
            console.log('✅ Tourist inserted into MongoDB');
            emailVerificationSent = await sendAccountVerification({
                db,
                email,
                name,
                role: 'tourist',
                userId,
            });
            }
            
            await connection.commit();
            
            // Generate JWT token
            const token = generateToken(userId, email, 'tourist');
            
            res.json({
                success: true,
                message: emailVerificationSent
                    ? 'Registration successful. Check your email for a verification code.'
                    : 'Registration successful',
                token: token,
                user: {
                    user_id: userId,
                    id: userId.toString(),
                    name: name,
                    email: email,
                    role: 'tourist',
                    phone: phone,
                    emailVerificationSent,
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
    const {
        full_name,
        email,
        password,
        business_name,
        business_phone,
        business_address,
        business_type,
        phone,
        district,
        has_license,
        license_valid,
        tax_clearance,
        previous_experience,
        rating,
    } = req.body;
    
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
            
            const vendorMlPayload = {
                name: business_name,
                owner_name: full_name,
                email,
                phone: business_phone || phone,
                business_type: business_type || 'Other',
                district: district || business_address || 'Maseru',
                has_license: toBoolean(has_license),
                license_valid: toBoolean(license_valid),
                tax_clearance: toBoolean(tax_clearance),
                previous_experience: toNumber(previous_experience, 0),
                rating: toNumber(rating, 3),
            };
            const mlDecision = await runVendorMlVerification(vendorMlPayload);
            const autoApproved = mlDecision?.approved === true;
            const initialVerified = autoApproved ? 1 : 0;
            const initialStatus = autoApproved ? 'active' : 'pending';

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
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
                [
                    userId,
                    business_name,
                    email,
                    business_phone,
                    business_type,
                    business_address,
                    initialVerified,
                    initialStatus,
                ]
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
            let emailVerificationSent = false;
            if (db) {
            await db.collection('users').insertOne({
                user_id: userId,
                email: email,
                name: full_name,
                password: hashedPassword,
                role: 'vendor',
                businessName: business_name,
                businessType: business_type,
                businessAddress: business_address,
                district,
                mlVerification: mlDecision,
                phone: phone,
                emailVerified: false,
                emailVerificationRequired: false,
                createdAt: new Date(),
                updatedAt: new Date()
            });
            console.log('✅ Vendor inserted into MongoDB');
            emailVerificationSent = await sendAccountVerification({
                db,
                email,
                name: full_name,
                role: 'vendor',
                userId,
            });
            }
            
            await connection.commit();
            
            // Generate JWT token
            const token = generateToken(userId, email, 'vendor');
            
            res.json({
                success: true,
                message: autoApproved
                    ? emailVerificationSent
                        ? 'Vendor registration successful. Your account was automatically approved. Check your email for a verification code.'
                        : 'Vendor registration successful. Your account was automatically approved.'
                    : emailVerificationSent
                        ? 'Vendor registration successful. Your account is pending approval. Check your email for a verification code.'
                        : 'Vendor registration successful. Your account is pending approval.',
                token: token,
                user: {
                    user_id: userId,
                    id: userId.toString(),
                    name: full_name,
                    email: email,
                    role: 'vendor',
                    businessName: business_name,
                    businessType: business_type,
                    verified: autoApproved,
                    emailVerificationSent,
                    linkedCultureVendorId: linkedCultureVendorId?.toString() ?? null,
                    mlVerification: mlDecision,
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
// VERIFY EMAIL
// ============================================
router.post('/verify-email', async (req, res) => {
    const { email, code } = req.body;

    if (!email || !code) {
        return res.status(400).json({
            success: false,
            message: 'Email and verification code are required'
        });
    }

    try {
        const db = getMongoDb();
        const hashedCode = hashResetToken(code);
        const result = await db.collection('users').findOneAndUpdate(
            {
                email,
                emailVerificationToken: hashedCode,
                emailVerificationExpiresAt: { $gt: new Date() }
            },
            {
                $set: {
                    emailVerified: true,
                    emailVerificationRequired: false,
                    updatedAt: new Date()
                },
                $unset: {
                    emailVerificationToken: '',
                    emailVerificationExpiresAt: ''
                }
            },
            { returnOriginal: false }
        );

        if (!result.value) {
            return res.status(400).json({
                success: false,
                message: 'Invalid or expired verification code'
            });
        }

        return res.json({
            success: true,
            message: 'Email verified successfully'
        });
    } catch (error) {
        console.error('❌ Error verifying email:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to verify email'
        });
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

        const db = getMongoDb();
        if (db) {
            const mongoUser = await db.collection('users').findOne({ email: user.email });
            if (mongoUser?.emailVerificationRequired === true && mongoUser.emailVerified !== true) {
                return res.status(403).json({
                    success: false,
                    message: 'Please verify your email before logging in.'
                });
            }
        }
        
        // Check vendor approval if role is vendor
        let businessName = null;
        let businessType = null;
        let verified = true;
        if (user.role === 'vendor') {
            const [vendors] = await mysqlPool.execute(
                'SELECT business_name, business_type, verified FROM vendors WHERE user_id = ?',
                [user.user_id]
            );
            if (vendors.length > 0) {
                businessName = vendors[0].business_name;
                businessType = vendors[0].business_type;
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
                businessType: businessType,
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
        const resetToken = generateVerificationCode();
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

        const emailContent = passwordResetEmail({
            name: user.full_name,
            code: resetToken,
        });
        const emailSent = await sendEmail({
            to: user.email,
            subject: emailContent.subject,
            text: emailContent.text,
            html: emailContent.html,
        });

        if (!emailSent || process.env.NODE_ENV !== 'production') {
            console.log(`🔐 Password reset code for ${user.email}: ${resetToken}`);
        }

        return res.json({
            success: true,
            message: emailSent
                ? 'If an account with that email exists, a reset code has been sent.'
                : 'If an account with that email exists, a reset code has been generated.',
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
