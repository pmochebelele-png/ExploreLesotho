// controllers/authController.js
const { getMongoDb } = require('../config/databases');
const { hashPassword, comparePassword, generateToken } = require('../config/auth');
const { validateEmail, validatePhone } = require('../utils/validators');

// Register new user
const register = async (req, res) => {
    const db = getMongoDb();
    try {
        const { email, password, fullName, role = 'tourist', phone } = req.body;

        // Validate input
        if (!email || !password || !fullName) {
            return res.status(400).json({ 
                error: 'Missing required fields',
                required: ['email', 'password', 'fullName']
            });
        }

        if (!validateEmail(email)) {
            return res.status(400).json({ error: 'Invalid email format' });
        }

        if (phone && !validatePhone(phone)) {
            return res.status(400).json({ error: 'Invalid phone format. Use +266XXXXXXXX' });
        }

        if (password.length < 8) {
            return res.status(400).json({ error: 'Password must be at least 8 characters' });
        }

        // Check if user exists
        const existingUser = await db.collection('users').findOne({ email });
        if (existingUser) {
            return res.status(400).json({ error: 'User already exists' });
        }

        // Hash password
        const hashedPassword = await hashPassword(password);

        // Create user in MongoDB
        const user = {
            email,
            password: hashedPassword,
            fullName,
            role,
            phone,
            createdAt: new Date(),
            updatedAt: new Date()
        };

        const result = await db.collection('users').insertOne(user);

        // Generate token
        const token = generateToken(result.insertedId, email, role);

        // Track registration in analytics
        await db.collection('user_analytics').insertOne({
            userId: result.insertedId,
            eventType: 'registration',
            timestamp: new Date(),
            role
        });

        res.status(201).json({
            success: true,
            message: 'User registered successfully',
            token,
            user: {
                id: result.insertedId,
                email,
                fullName,
                role,
                phone
            }
        });

    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ error: 'Registration failed', details: error.message });
    }
};

// Login user
const login = async (req, res) => {
    const db = getMongoDb();
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password required' });
        }

        // Find user in MongoDB
        const user = await db.collection('users').findOne({ email });
        if (!user) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Check password
        const validPassword = await comparePassword(password, user.password);
        if (!validPassword) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Generate token
        const token = generateToken(user._id, user.email, user.role);

        // Track login in analytics
        await db.collection('user_analytics').insertOne({
            userId: user._id,
            eventType: 'login',
            timestamp: new Date(),
            device: req.headers['user-agent'] || 'unknown'
        });

        res.json({
            success: true,
            message: 'Login successful',
            token,
            user: {
                id: user._id,
                email: user.email,
                fullName: user.fullName,
                role: user.role,
                phone: user.phone
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Login failed', details: error.message });
    }
};

// Get user profile
const getProfile = async (req, res) => {
    const db = getMongoDb();
    try {
        const user = await db.collection('users').findOne(
            { _id: req.user.userId },
            { projection: { password: 0 } }
        );

        if (!user) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json({
            success: true,
            user
        });

    } catch (error) {
        console.error('Profile error:', error);
        res.status(500).json({ error: 'Failed to fetch profile' });
    }
};

module.exports = {
    register,
    login,
    getProfile
};