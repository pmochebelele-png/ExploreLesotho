// config/auth.js
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

const JWT_SECRET = process.env.JWT_SECRET || 'Lesotho2026!SuperSecureKey';
const JWT_EXPIRE = '7d';
const BCRYPT_ROUNDS = 10;

// Hash password
const hashPassword = async (password) => {
    return await bcrypt.hash(password, BCRYPT_ROUNDS);
};

// Compare password
const comparePassword = async (password, hash) => {
    return await bcrypt.compare(password, hash);
};

// Generate JWT token
const generateToken = (userId, email, role) => {
    return jwt.sign(
        { userId, email, role },
        JWT_SECRET,
        { expiresIn: JWT_EXPIRE }
    );
};

// Verify JWT token
const verifyToken = (token) => {
    try {
        return jwt.verify(token, JWT_SECRET);
    } catch (error) {
        return null;
    }
};

module.exports = {
    hashPassword,
    comparePassword,
    generateToken,
    verifyToken,
    JWT_SECRET,
    JWT_EXPIRE,
    BCRYPT_ROUNDS
};