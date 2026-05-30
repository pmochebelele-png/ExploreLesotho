const express = require('express');
const { mysqlPool } = require('../config/databases');
const { authenticateToken } = require('../middleware/auth');
const paymentGateway = require('../services/paymentGateway');

const router = express.Router();
const COMMISSION_RATE = Number(process.env.PLATFORM_COMMISSION_RATE || 0.05);

let paymentTablesReady = false;
let paymentTablesInFlight = null;

async function ensurePaymentTables() {
    if (paymentTablesReady) return;
    if (paymentTablesInFlight) return paymentTablesInFlight;

    paymentTablesInFlight = (async () => {
        await mysqlPool.execute(`
            CREATE TABLE IF NOT EXISTS payment_transactions (
                payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                reference VARCHAR(80) NOT NULL UNIQUE,
                provider VARCHAR(40) NOT NULL,
                provider_reference VARCHAR(160) NULL,
                purpose VARCHAR(40) NOT NULL,
                related_id VARCHAR(80) NULL,
                user_id BIGINT NULL,
                amount DECIMAL(12,2) NOT NULL,
                service_fee DECIMAL(12,2) NOT NULL DEFAULT 0,
                vendor_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
                currency VARCHAR(10) NOT NULL DEFAULT 'LSL',
                method VARCHAR(40) NULL,
                customer_phone VARCHAR(40) NULL,
                status VARCHAR(40) NOT NULL DEFAULT 'pending',
                metadata JSON NULL,
                provider_payload JSON NULL,
                paid_at TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_payment_transactions_user (user_id),
                INDEX idx_payment_transactions_status (status),
                INDEX idx_payment_transactions_purpose (purpose)
            )
        `);
        paymentTablesReady = true;
    })();

    try {
        await paymentTablesInFlight;
    } finally {
        paymentTablesInFlight = null;
    }
}

const toNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const createReference = (prefix) =>
    `${prefix}-${Date.now()}-${Math.floor(Math.random() * 10000)}`;

async function loadEvent(eventId) {
    const [rows] = await mysqlPool.execute(
        `SELECT
            e.event_id,
            e.title,
            e.price,
            e.max_capacity,
            e.status,
            COALESCE(SUM(CASE WHEN eto.status = 'confirmed' AND eto.payment_status = 'paid' THEN eto.quantity ELSE 0 END), 0) AS tickets_sold
         FROM events e
         LEFT JOIN event_ticket_orders eto ON eto.event_id = e.event_id
         WHERE e.event_id = ?
         GROUP BY e.event_id, e.title, e.price, e.max_capacity, e.status
         LIMIT 1`,
        [eventId]
    );
    return rows[0] || null;
}

async function createTicketOrderFromPayment(connection, payment) {
    const metadata = typeof payment.metadata === 'string'
        ? JSON.parse(payment.metadata || '{}')
        : payment.metadata || {};
    if (payment.purpose !== 'event_ticket') return null;

    const eventId = Number(metadata.eventId);
    const quantity = Number(metadata.quantity);
    if (!Number.isFinite(eventId) || !Number.isFinite(quantity)) return null;

    const [existing] = await connection.execute(
        `SELECT order_id FROM event_ticket_orders WHERE payment_id = ? LIMIT 1`,
        [payment.reference]
    );
    if (existing.length > 0) return existing[0].order_id;

    const receiptNumber = `EVT-${eventId}-${Date.now()}`;
    const [result] = await connection.execute(
        `INSERT INTO event_ticket_orders (
            event_id, user_id, quantity, total_amount, service_fee,
            payment_id, payment_status, payment_method, currency,
            buyer_phone, receipt_number, status
         )
         VALUES (?, ?, ?, ?, ?, ?, 'paid', ?, ?, ?, ?, 'confirmed')`,
        [
            eventId,
            payment.user_id,
            quantity,
            payment.amount,
            payment.service_fee,
            payment.reference,
            payment.method,
            payment.currency,
            payment.customer_phone,
            receiptNumber,
        ]
    );
    return result.insertId;
}

async function createBookingFromPayment(connection, payment) {
    if (payment.purpose !== 'booking') return null;
    const metadata = typeof payment.metadata === 'string'
        ? JSON.parse(payment.metadata || '{}')
        : payment.metadata || {};
    const intent = metadata.bookingIntent || {};
    const listingId = intent.listingId || intent.listing_id;
    if (!listingId || !payment.user_id) return null;

    const [existing] = await connection.execute(
        `SELECT booking_id FROM bookings WHERE booking_reference = ? LIMIT 1`,
        [payment.reference]
    );
    if (existing.length > 0) return existing[0].booking_id;

    const [listingRows] = await connection.execute(
        `SELECT
            l.listing_id,
            l.title,
            l.vendor_id,
            v.user_id AS vendor_user_id
         FROM listings l
         INNER JOIN vendors v ON l.vendor_id = v.vendor_id
         WHERE l.listing_id = ? AND l.status = 'active'
         LIMIT 1`,
        [listingId]
    );
    if (listingRows.length === 0) {
        throw new Error('Listing not found or not available for paid booking.');
    }

    const checkIn = String(intent.checkIn || '').split('T')[0];
    const checkOut = String(intent.checkOut || '').split('T')[0];
    const guests = Number(intent.guests || 1);
    const specialRequestMap = {
        notes: intent.specialRequests?.notes || '',
        category: intent.category || metadata.bookingDetails?.category || 'Accommodation',
        meta: intent.bookingMeta || {},
    };

    const [result] = await connection.execute(
        `INSERT INTO bookings (
            booking_reference,
            tourist_id,
            listing_id,
            check_in,
            check_out,
            guests,
            total_price,
            commission_amount,
            net_amount,
            special_requests,
            status,
            payment_status,
            created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'paid', NOW())`,
        [
            payment.reference,
            payment.user_id,
            listingId,
            checkIn,
            checkOut,
            guests,
            payment.vendor_amount,
            payment.service_fee,
            payment.vendor_amount,
            JSON.stringify(specialRequestMap),
        ]
    );

    await connection.execute(
        `UPDATE availability
         SET status = 'booked'
         WHERE listing_id = ?
           AND available_date BETWEEN ? AND ?`,
        [listingId, checkIn, checkOut]
    );

    return result.insertId;
}

router.post('/initiate', authenticateToken, async (req, res) => {
    try {
        await ensurePaymentTables();

        const purpose = String(req.body.purpose || '').trim();
        const method = String(req.body.method || '').trim().toLowerCase();
        const phone = String(req.body.phone || '').trim();
        const currency = String(req.body.currency || 'LSL').trim().toUpperCase();
        const metadata = req.body.metadata && typeof req.body.metadata === 'object'
            ? req.body.metadata
            : {};
        let amount = toNumber(req.body.amount);
        let serviceFee = toNumber(req.body.serviceFee);
        let relatedId = req.body.relatedId?.toString() || null;
        let description = req.body.description?.toString() || 'Explore Lesotho payment';

        if (!['booking', 'event_ticket', 'vendor_registration'].includes(purpose)) {
            return res.status(400).json({ success: false, error: 'Invalid payment purpose' });
        }

        if (!method) {
            return res.status(400).json({ success: false, error: 'Payment method is required' });
        }

        if ((method === 'mpesa' || method === 'ecocash') && phone.length < 8) {
            return res.status(400).json({ success: false, error: 'A valid mobile money phone number is required' });
        }

        if (purpose === 'event_ticket') {
            const eventId = Number(metadata.eventId || relatedId);
            const quantity = Number(metadata.quantity);
            if (!Number.isFinite(eventId) || !Number.isFinite(quantity) || quantity <= 0) {
                return res.status(400).json({ success: false, error: 'Event ticket payment requires eventId and quantity' });
            }
            const event = await loadEvent(eventId);
            if (!event) return res.status(404).json({ success: false, error: 'Event not found' });
            if (event.status === 'cancelled' || event.status === 'ended') {
                return res.status(400).json({ success: false, error: 'Tickets are not available for this event' });
            }
            const maxCapacity = Number(event.max_capacity);
            const sold = Number(event.tickets_sold || 0);
            const remaining = Number.isFinite(maxCapacity) ? Math.max(maxCapacity - sold, 0) : 0;
            if (quantity > remaining) {
                return res.status(400).json({ success: false, error: `Only ${remaining} ticket(s) left`, remaining });
            }
            const subtotal = Number(event.price || 0) * quantity;
            serviceFee = Number((subtotal * COMMISSION_RATE).toFixed(2));
            amount = Number((subtotal + serviceFee).toFixed(2));
            relatedId = String(eventId);
            description = `${event.title} ticket x ${quantity}`;
            metadata.eventId = eventId;
            metadata.quantity = quantity;
            metadata.subtotal = subtotal;
        }

        if (amount <= 0) {
            return res.status(400).json({ success: false, error: 'Payment amount must be greater than zero' });
        }

        const vendorAmount = Number((amount - serviceFee).toFixed(2));
        const reference = createReference(purpose === 'event_ticket' ? 'EVT-PAY' : 'PAY');
        const callbackUrl =
            process.env.PAYMENT_CALLBACK_URL ||
            `${req.protocol}://${req.get('host')}/api/payments/callback`;

        const gatewayResult = await paymentGateway.initiatePayment({
            amount,
            currency,
            phone,
            reference,
            description,
            callbackUrl,
            method,
        });

        if (gatewayResult.configured === false) {
            return res.status(503).json({ success: false, ...gatewayResult });
        }

        await mysqlPool.execute(
            `INSERT INTO payment_transactions (
                reference, provider, provider_reference, purpose, related_id, user_id,
                amount, service_fee, vendor_amount, currency, method,
                customer_phone, status, metadata, provider_payload
             ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                reference,
                gatewayResult.provider,
                gatewayResult.providerReference || null,
                purpose,
                relatedId,
                req.user.userId || req.user.user_id || null,
                amount,
                serviceFee,
                vendorAmount,
                currency,
                method,
                phone || null,
                gatewayResult.status === 'paid' ? 'paid' : 'pending',
                JSON.stringify(metadata),
                JSON.stringify(gatewayResult.raw || gatewayResult),
            ]
        );

        res.status(201).json({
            success: true,
            status: gatewayResult.status === 'paid' ? 'paid' : 'pending',
            paymentReference: reference,
            provider: gatewayResult.provider,
            providerReference: gatewayResult.providerReference,
            amount,
            serviceFee,
            vendorAmount,
            currency,
            customerMessage: gatewayResult.customerMessage,
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/:reference/status', authenticateToken, async (req, res) => {
    try {
        await ensurePaymentTables();
        const [rows] = await mysqlPool.execute(
            `SELECT reference, provider, provider_reference, purpose, related_id, amount,
                    service_fee, vendor_amount, currency, method, status, paid_at, created_at
             FROM payment_transactions
             WHERE reference = ? AND (user_id = ? OR ? = 'admin')
             LIMIT 1`,
            [req.params.reference, req.user.userId || req.user.user_id, req.user.role]
        );
        if (rows.length === 0) return res.status(404).json({ success: false, error: 'Payment not found' });
        res.json({ success: true, payment: rows[0] });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/callback', async (req, res) => {
    const connection = await mysqlPool.getConnection();
    try {
        await ensurePaymentTables();
        const callback = paymentGateway.normalizeCallback(req.body || {});
        if (!callback.reference) {
            return res.status(400).json({ success: false, error: 'Missing payment reference' });
        }

        await connection.beginTransaction();
        const [rows] = await connection.execute(
            `SELECT * FROM payment_transactions WHERE reference = ? FOR UPDATE`,
            [callback.reference]
        );
        if (rows.length === 0) {
            await connection.rollback();
            return res.status(404).json({ success: false, error: 'Payment not found' });
        }

        const payment = rows[0];
        await connection.execute(
            `UPDATE payment_transactions
             SET status = ?, provider_reference = COALESCE(?, provider_reference),
                 provider_payload = ?, paid_at = CASE WHEN ? = 'paid' THEN NOW() ELSE paid_at END
             WHERE reference = ?`,
            [
                callback.status,
                callback.providerReference || null,
                JSON.stringify(callback.raw),
                callback.status,
                callback.reference,
            ]
        );

        let recordId = null;
        if (callback.status === 'paid') {
            recordId = await createTicketOrderFromPayment(connection, {
                ...payment,
                status: 'paid',
                provider_reference: callback.providerReference || payment.provider_reference,
            });
            if (!recordId) {
                recordId = await createBookingFromPayment(connection, {
                    ...payment,
                    status: 'paid',
                    provider_reference: callback.providerReference || payment.provider_reference,
                });
            }
        }

        await connection.commit();
        res.json({ success: true, status: callback.status, recordId });
    } catch (error) {
        await connection.rollback();
        res.status(500).json({ success: false, error: error.message });
    } finally {
        connection.release();
    }
});

router.get('/finance/summary', authenticateToken, async (req, res) => {
    try {
        if (req.user.role !== 'admin') {
            return res.status(403).json({ success: false, error: 'Admin access required' });
        }
        await ensurePaymentTables();
        const [rows] = await mysqlPool.execute(`
            SELECT
                COUNT(*) AS transactions,
                COALESCE(SUM(amount), 0) AS gross_amount,
                COALESCE(SUM(service_fee), 0) AS platform_earnings,
                COALESCE(SUM(vendor_amount), 0) AS vendor_payouts,
                COALESCE(SUM(CASE WHEN purpose = 'event_ticket' THEN JSON_EXTRACT(metadata, '$.quantity') ELSE 0 END), 0) AS tickets_sold
            FROM payment_transactions
            WHERE status = 'paid'
        `);
        const summary = rows[0] || {};
        const gross = Number(summary.gross_amount || 0);
        const platform = Number(summary.platform_earnings || 0);
        res.json({
            success: true,
            summary: {
                transactions: Number(summary.transactions || 0),
                grossAmount: gross,
                platformEarnings: platform,
                vendorPayouts: Number(summary.vendor_payouts || 0),
                ticketsSold: Number(summary.tickets_sold || 0),
                platformPercentage: gross > 0 ? Number(((platform / gross) * 100).toFixed(2)) : 0,
                commissionRate: COMMISSION_RATE,
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
