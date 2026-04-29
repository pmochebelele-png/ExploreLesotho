const express = require('express');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

const ML_SERVICE_BASE_URL = (
    process.env.ML_SERVICE_URL ||
    'http://127.0.0.1:5001/api/ml'
).replace(/\/+$/, '');

const requireAdmin = (req, res, next) => {
    if (req.user?.role !== 'admin') {
        return res.status(403).json({
            success: false,
            message: 'Admin access required',
        });
    }

    next();
};

async function forwardMlRequest(req, res, path, { method = 'GET', body } = {}) {
    try {
        const queryString = req.originalUrl.includes('?')
            ? req.originalUrl.slice(req.originalUrl.indexOf('?'))
            : '';
        const url = `${ML_SERVICE_BASE_URL}${path}${queryString}`;

        const response = await fetch(url, {
            method,
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
            body: body ? JSON.stringify(body) : undefined,
        });

        const text = await response.text();
        let payload = null;

        try {
            payload = text ? JSON.parse(text) : {};
        } catch (parseError) {
            payload = {
                success: false,
                message: 'ML service returned a non-JSON response',
                raw: text,
            };
        }

        return res.status(response.status).json(payload);
    } catch (error) {
        return res.status(503).json({
            success: false,
            message: 'ML service is unavailable',
            details: error.message,
            serviceUrl: ML_SERVICE_BASE_URL,
        });
    }
}

router.get('/health', async (req, res) => {
    try {
        const response = await fetch(`${ML_SERVICE_BASE_URL}/health`, {
            headers: { Accept: 'application/json' },
        });

        const text = await response.text();
        let payload = {};

        try {
            payload = text ? JSON.parse(text) : {};
        } catch (parseError) {
            payload = {
                success: false,
                message: 'ML health endpoint returned non-JSON',
                raw: text,
            };
        }

        return res.status(response.status).json({
            success: response.ok,
            mlServiceUrl: ML_SERVICE_BASE_URL,
            ...payload,
        });
    } catch (error) {
        return res.status(503).json({
            success: false,
            message: 'ML service is unavailable',
            details: error.message,
            mlServiceUrl: ML_SERVICE_BASE_URL,
        });
    }
});

router.get('/dashboard', authenticateToken, async (req, res) => {
    await forwardMlRequest(req, res, '/dashboard');
});

router.get('/forecast', async (req, res) => {
    await forwardMlRequest(req, res, '/forecast');
});

router.get('/culture/locations', async (req, res) => {
    await forwardMlRequest(req, res, '/culture/locations');
});

router.get('/hotspots', async (req, res) => {
    await forwardMlRequest(req, res, '/hotspots');
});

router.get('/ltdc/overview', async (req, res) => {
    await forwardMlRequest(req, res, '/ltdc/overview');
});

router.get('/ltdc/trends', async (req, res) => {
    await forwardMlRequest(req, res, '/ltdc/trends');
});

router.get('/ltdc/insights', async (req, res) => {
    await forwardMlRequest(req, res, '/ltdc/insights');
});

router.post('/sentiment', async (req, res) => {
    await forwardMlRequest(req, res, '/sentiment', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/recommend', async (req, res) => {
    await forwardMlRequest(req, res, '/recommend', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/culture/recommendations', async (req, res) => {
    await forwardMlRequest(req, res, '/culture/recommendations', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/recommendations', async (req, res) => {
    await forwardMlRequest(req, res, '/recommendations', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/reviews/analyze', async (req, res) => {
    await forwardMlRequest(req, res, '/reviews/analyze', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/analyze-sentiment', async (req, res) => {
    await forwardMlRequest(req, res, '/analyze-sentiment', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/verify-pdf', async (req, res) => {
    await forwardMlRequest(req, res, '/verify_pdf', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/ltdc/knowledge', async (req, res) => {
    await forwardMlRequest(req, res, '/ltdc/knowledge', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/check-user', async (req, res) => {
    await forwardMlRequest(req, res, '/check_user', {
        method: 'POST',
        body: req.body,
    });
});

router.post('/register-vendor', authenticateToken, requireAdmin, async (req, res) => {
    await forwardMlRequest(req, res, '/register_vendor', {
        method: 'POST',
        body: req.body,
    });
});

module.exports = router;
