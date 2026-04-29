// utils/logger.js
const fs = require('fs');
const path = require('path');

class Logger {
    constructor() {
        this.logDir = path.join(__dirname, '../logs');
        if (!fs.existsSync(this.logDir)) {
            fs.mkdirSync(this.logDir);
        }
    }

    // Get current timestamp
    getTimestamp() {
        return new Date().toISOString();
    }

    // Get today's log file
    getLogFile() {
        const date = new Date().toISOString().split('T')[0];
        return path.join(this.logDir, `${date}.log`);
    }

    // Write to log file
    writeToFile(level, message, data = {}) {
        const logEntry = {
            timestamp: this.getTimestamp(),
            level,
            message,
            ...data
        };

        const logFile = this.getLogFile();
        fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
    }

    // Info level
    info(message, data = {}) {
        console.log(`\x1b[36m[INFO]\x1b[0m ${this.getTimestamp()} - ${message}`, data);
        this.writeToFile('INFO', message, data);
    }

    // Success level (custom green)
    success(message, data = {}) {
        console.log(`\x1b[32m[SUCCESS]\x1b[0m ${this.getTimestamp()} - ${message}`, data);
        this.writeToFile('SUCCESS', message, data);
    }

    // Warning level
    warn(message, data = {}) {
        console.log(`\x1b[33m[WARN]\x1b[0m ${this.getTimestamp()} - ${message}`, data);
        this.writeToFile('WARN', message, data);
    }

    // Error level
    error(message, error = {}) {
        console.error(`\x1b[31m[ERROR]\x1b[0m ${this.getTimestamp()} - ${message}`, {
            message: error.message,
            stack: error.stack
        });
        this.writeToFile('ERROR', message, {
            error: error.message,
            stack: error.stack
        });
    }

    // Debug level (only in development)
    debug(message, data = {}) {
        if (process.env.NODE_ENV === 'development') {
            console.log(`\x1b[35m[DEBUG]\x1b[0m ${this.getTimestamp()} - ${message}`, data);
            this.writeToFile('DEBUG', message, data);
        }
    }

    // API request logger middleware
    requestLogger() {
        return (req, res, next) => {
            const start = Date.now();
            res.on('finish', () => {
                const duration = Date.now() - start;
                this.info(`${req.method} ${req.originalUrl} - ${res.statusCode} - ${duration}ms`, {
                    method: req.method,
                    url: req.originalUrl,
                    status: res.statusCode,
                    duration,
                    ip: req.ip,
                    user: req.user?.email || 'anonymous'
                });
            });
            next();
        };
    }
}

module.exports = new Logger();