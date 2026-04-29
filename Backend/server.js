require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { connectMongo, mysqlPool } = require('./config/databases');
const logger = require('./utils/logger');

const app = express();
const PORT = process.env.PORT || 3001;

function isLocalRequest(req) {
    const ip = req.ip || req.connection?.remoteAddress || '';
    return (
        ip === '::1' ||
        ip === '127.0.0.1' ||
        ip === '::ffff:127.0.0.1' ||
        ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        ip.startsWith('172.')
    );
}

// ============================================
// SECURITY MIDDLEWARE
// ============================================
app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(compression());

const corsOptions = {
    origin(origin, callback) {
        if (!origin) return callback(null, true);
        if (origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
            return callback(null, true);
        }

        const allowedOrigins = [
            'http://localhost:3000',
            'http://127.0.0.1:3000',
            'http://localhost:8080',
            'http://127.0.0.1:8080',
            'http://localhost:8081',
            'http://127.0.0.1:8081',
            process.env.CLIENT_URL,
        ].filter(Boolean);

        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            console.log('Blocked CORS request from:', origin);
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    optionsSuccessStatus: 200,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin', 'X-Requested-With'],
    exposedHeaders: ['Content-Length', 'X-Request-Id'],
};

app.use(cors(corsOptions));

app.use((req, res, next) => {
    if (req.method === 'OPTIONS') {
        res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
        res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, Origin, X-Requested-With');
        res.header('Access-Control-Allow-Credentials', 'true');
        return res.sendStatus(200);
    }
    next();
});

app.use((req, res, next) => {
    console.log(`[REQ] ${req.method} ${req.url}`);
    if (req.headers.authorization) {
        console.log('[AUTH] Authorization header present');
    }
    next();
});

const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: process.env.NODE_ENV === 'production' ? 300 : 5000,
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) => process.env.NODE_ENV !== 'production' && isLocalRequest(req),
    handler: (req, res) => {
        res.status(429).json({
            success: false,
            message: 'Too many requests. Please wait a moment and try again.',
        });
    },
});
app.use('/api', limiter);

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(logger.requestLogger());

// ============================================
// DATABASE CONNECTION
// ============================================
let db = null;
let server = null;

async function initializeDatabase() {
    try {
        db = await connectMongo();
        app.locals.db = db;
        app.locals.mysqlPool = mysqlPool;
        logger.success('Databases initialized successfully');
    } catch (error) {
        db = null;
        app.locals.db = null;
        app.locals.mysqlPool = mysqlPool;
        logger.error('MongoDB initialization failed; continuing with MySQL-only mode', error);
    }
}

const databaseReady = initializeDatabase();

// ============================================
// ROUTES
// ============================================
const authRoutes = require('./routes/auth');
const hybridRoutes = require('./routes/hybrid');
const bookingRoutes = require('./routes/bookings');
const adminRoutes = require('./routes/admin');
const chatRoutes = require('./routes/chat');
const mlRoutes = require('./routes/ml');

app.use('/api/auth', authRoutes);
app.use('/api', hybridRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/ml', mlRoutes);

// ============================================
// HEALTH CHECK
// ============================================
app.get('/api/health', async (req, res) => {
    let mysqlStatus = 'disconnected';
    let mongoStatus = 'disconnected';
    const issues = [];

    try {
        await mysqlPool.execute('SELECT 1');
        mysqlStatus = 'connected';
    } catch (error) {
        issues.push(`mysql: ${error.message}`);
    }

    try {
        if (db) {
            await db.command({ ping: 1 });
            mongoStatus = 'connected';
        } else {
            issues.push('mongodb: not initialized');
        }
    } catch (error) {
        issues.push(`mongodb: ${error.message}`);
    }

    const isHealthy = mysqlStatus === 'connected' && mongoStatus === 'connected';
    const httpStatus = isHealthy ? 200 : 503;

    res.status(httpStatus).json({
        status: isHealthy ? 'OK' : 'DEGRADED',
        message: isHealthy
            ? 'Explore Lesotho API is running'
            : 'Explore Lesotho API is running with reduced services',
        mongodb: mongoStatus,
        mysql: mysqlStatus,
        timestamp: new Date(),
        environment: process.env.NODE_ENV || 'development',
        issues,
    });
});

app.get('/api/health/mysql', async (req, res) => {
    try {
        await mysqlPool.execute('SELECT 1');
        res.json({
            status: 'OK',
            message: 'MySQL is connected',
            mysql: 'connected',
            timestamp: new Date(),
            environment: process.env.NODE_ENV || 'development',
        });
    } catch (error) {
        res.status(500).json({
            status: 'ERROR',
            mysql: 'disconnected',
            error: error.message,
        });
    }
});

// ============================================
// ERROR HANDLING MIDDLEWARE
// ============================================
app.use((req, res) => {
    res.status(404).json({ error: 'Route not found' });
});

app.use((err, req, res, next) => {
    logger.error('Unhandled error', err);
    res.status(500).json({
        error: 'Internal server error',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined,
    });
});

// ============================================
// START SERVER
// ============================================
async function startServer() {
    await databaseReady;

    server = app.listen(PORT, () => {
        logger.success(`
=================================
Explore Lesotho API Server
=================================
Port: ${PORT}
Environment: ${process.env.NODE_ENV || 'development'}
MongoDB: ${db ? 'connected' : 'disconnected'}
MySQL: connected
CORS: Enabled for localhost development
=================================
        `);
    });

    return server;
}

if (require.main === module) {
    startServer().catch((error) => {
        logger.error('Failed to start server', error);
        process.exit(1);
    });
}

process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    if (server) {
        server.close(() => {
            logger.info('Process terminated');
        });
    } else {
        logger.info('Process terminated');
    }
});

module.exports = app;
module.exports.startServer = startServer;
module.exports.databaseReady = databaseReady;
