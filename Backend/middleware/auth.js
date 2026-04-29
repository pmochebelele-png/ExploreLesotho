// middleware/auth.js
const { verifyToken } = require('../config/auth');

const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({ error: 'Access denied. No token provided.' });
    }
    
    const decoded = verifyToken(token);
    if (!decoded) {
        return res.status(403).json({ error: 'Invalid or expired token.' });
    }

    req.user = {
        ...decoded,
        userId: decoded.userId ?? decoded.id,
        user_id: decoded.user_id ?? decoded.userId ?? decoded.id,
    };
    next();
};

const authorize = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ 
                error: 'You do not have permission to access this resource.' 
            });
        }
        next();
    };
};

module.exports = {
    authenticateToken,
    authorize
};
