const express = require('express');
const router = express.Router();
const { mysqlPool, getMongoDb } = require('../config/databases');
const { authenticateToken } = require('../middleware/auth');

const normalizeCategory = (value = '') => {
    const normalized = value.toString().trim().toLowerCase();
    if (normalized === 'cultural') return 'culture';
    return normalized || 'accommodation';
};

const parseSpecialRequests = (rawValue) => {
    if (rawValue == null) return null;
    if (typeof rawValue === 'object') return rawValue;
    if (typeof rawValue !== 'string') return { notes: String(rawValue) };

    const trimmed = rawValue.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
            const parsed = JSON.parse(trimmed);
            if (parsed && typeof parsed === 'object') {
                return parsed;
            }
        } catch (_) {
            return { notes: trimmed };
        }
    }
    return { notes: trimmed };
};

const mapBookingRow = (row) => {
    const totalPrice = Number(row.total_price ?? 0);
    const serviceFee = Number(row.commission_amount ?? totalPrice * 0.05);
    const grandTotal = totalPrice + serviceFee;
    const specialRequests = parseSpecialRequests(row.special_requests) ?? {};
    if (!specialRequests.category && row.listing_category) {
        specialRequests.category = normalizeCategory(row.listing_category);
    }

    return {
        id: row.booking_id?.toString() ?? '',
        bookingReference: row.booking_reference ?? '',
        listingId: row.listing_id?.toString() ?? '',
        listingTitle: row.listing_title ?? '',
        vendorId: row.vendor_user_id?.toString() ?? row.vendor_id?.toString() ?? '',
        vendorName: row.vendor_name ?? '',
        userId: row.tourist_id?.toString() ?? '',
        userName: row.tourist_name ?? '',
        checkIn: row.check_in,
        checkOut: row.check_out,
        guests: Number(row.guests ?? 1),
        pricePerNight: Number(row.price_per_night ?? 0),
        totalPrice: totalPrice,
        serviceFee: serviceFee,
        grandTotal: grandTotal,
        currency: row.currency ?? 'LSL',
        status: row.status ?? 'pending',
        paymentId: row.booking_reference ?? '',
        paymentStatus: row.payment_status ?? 'paid',
        specialRequests:
            Object.keys(specialRequests).length > 0 ? specialRequests : null,
        addOns: null,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        cancellationReason: row.cancellation_reason,
        cancelledAt: row.cancelled_at,
        completedAt: row.completed_at ?? null,
        canReview: (row.status === 'completed'),
    };
};

async function getMysqlUserId(connection, req) {
    if (req.user.userId != null) {
        return Number(req.user.userId);
    }

    const [userRows] = await connection.execute(
        'SELECT user_id FROM users WHERE email = ?',
        [req.user.email]
    );

    if (userRows.length === 0) {
        return null;
    }

    return Number(userRows[0].user_id);
}

// Create booking after successful payment
router.post('/', authenticateToken, async (req, res) => {
    const connection = await mysqlPool.getConnection();

    try {
        await connection.beginTransaction();
        const db = getMongoDb();

        const mysqlUserId = await getMysqlUserId(connection, req);
        if (!mysqlUserId) {
            return res.status(400).json({
                success: false,
                error: 'User not found in MySQL. Please contact support.'
            });
        }

        const {
            listing_id,
            check_in,
            check_out,
            guests,
            total_price,
            service_fee,
            special_requests,
            payment_id,
            payment_status,
        } = req.body;

        if (!listing_id || !check_in || !check_out || !guests || total_price == null) {
            return res.status(400).json({
                success: false,
                error: 'Missing required fields',
            });
        }

        const [listingRows] = await connection.execute(`
            SELECT
                l.listing_id,
                l.title,
                l.category,
                l.vendor_id,
                l.price,
                l.status,
                v.user_id AS vendor_user_id,
                v.business_name AS vendor_name
            FROM listings l
            INNER JOIN vendors v ON l.vendor_id = v.vendor_id
            WHERE l.listing_id = ? AND l.status = 'active'
            LIMIT 1
        `, [listing_id]);

        if (listingRows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Listing not found or not available',
            });
        }

        const listing = listingRows[0];

        const [availability] = await connection.execute(`
            SELECT available_date
            FROM availability
            WHERE listing_id = ?
              AND available_date BETWEEN ? AND ?
              AND status = 'booked'
        `, [listing_id, check_in, check_out]);

        if (availability.length > 0) {
            return res.status(400).json({
                success: false,
                error: 'Selected dates are not fully available',
                booked_dates: availability.map((a) => a.available_date),
            });
        }

        const timestamp = Date.now().toString().slice(-8);
        const random = Math.floor(Math.random() * 1000);
        const bookingRef = `BKG-${timestamp}-${random}`;
        const commissionAmount = Number(service_fee ?? Number(total_price) * 0.05);
        const netAmount = Number(total_price) - commissionAmount;

        const [result] = await connection.execute(`
            INSERT INTO bookings (
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
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, NOW())
        `, [
            bookingRef,
            mysqlUserId,
            listing_id,
            check_in,
            check_out,
            guests,
            total_price,
            commissionAmount,
            netAmount,
            special_requests || null,
            payment_status || 'paid',
        ]);

        await connection.execute(`
            UPDATE availability
            SET status = 'booked'
            WHERE listing_id = ?
              AND available_date BETWEEN ? AND ?
        `, [listing_id, check_in, check_out]);

        const bookingId = result.insertId;

        const [touristRows] = await connection.execute(
            'SELECT full_name FROM users WHERE user_id = ? LIMIT 1',
            [mysqlUserId]
        );

        await connection.commit();

        if (db) {
            await db.collection('offline_sync_queue').insertOne({
                booking_id: bookingId,
                booking_reference: bookingRef,
                mysql_user_id: mysqlUserId,
                action: 'create_booking',
                status: 'pending',
                created_at: new Date(),
                metadata: {
                    listing_id,
                    check_in,
                    check_out,
                    guests,
                    total_price,
                    payment_id: payment_id || bookingRef,
                }
            });

            await db.collection('user_analytics').insertOne({
                user_id: mysqlUserId,
                event_type: 'booking_created',
                booking_id: bookingId,
                listing_id,
                amount: total_price,
                timestamp: new Date()
            });
        }

        const booking = mapBookingRow({
            booking_id: bookingId,
            booking_reference: bookingRef,
            listing_id: listing.listing_id,
            listing_title: listing.title,
            listing_category: listing.category,
            vendor_id: listing.vendor_id,
            vendor_user_id: listing.vendor_user_id,
            vendor_name: listing.vendor_name,
            tourist_id: mysqlUserId,
            tourist_name: touristRows[0]?.full_name ?? '',
            check_in,
            check_out,
            guests,
            price_per_night: listing.price,
            total_price,
            commission_amount: commissionAmount,
            status: 'pending',
            payment_status: payment_status || 'paid',
            special_requests: special_requests || null,
            created_at: new Date().toISOString(),
        });

        res.status(201).json({
            success: true,
            message: 'Booking created successfully and is awaiting vendor approval',
            booking,
        });
    } catch (error) {
        await connection.rollback();
        console.error('Booking error:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to create booking',
            details: error.message,
        });
    } finally {
        connection.release();
    }
});

router.get('/user', authenticateToken, async (req, res) => {
    try {
        const mysqlUserId = Number(req.user.userId);

        const [rows] = await mysqlPool.execute(`
            SELECT
                b.*,
                l.title AS listing_title,
                l.category AS listing_category,
                l.price AS price_per_night,
                v.vendor_id,
                v.user_id AS vendor_user_id,
                v.business_name AS vendor_name,
                u.full_name AS tourist_name
            FROM bookings b
            INNER JOIN listings l ON b.listing_id = l.listing_id
            INNER JOIN vendors v ON l.vendor_id = v.vendor_id
            INNER JOIN users u ON b.tourist_id = u.user_id
            WHERE b.tourist_id = ?
            ORDER BY b.created_at DESC, b.booking_id DESC
        `, [mysqlUserId]);

        res.json({
            success: true,
            bookings: rows.map(mapBookingRow),
        });
    } catch (error) {
        console.error('Failed to load user bookings:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/vendor', authenticateToken, async (req, res) => {
    try {
        const [vendorRows] = await mysqlPool.execute(
            'SELECT vendor_id, user_id, business_name FROM vendors WHERE user_id = ? LIMIT 1',
            [req.user.userId]
        );

        if (vendorRows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Vendor profile not found',
            });
        }

        const vendor = vendorRows[0];

        const [rows] = await mysqlPool.execute(`
            SELECT
                b.*,
                l.title AS listing_title,
                l.category AS listing_category,
                l.price AS price_per_night,
                ? AS vendor_user_id,
                ? AS vendor_name,
                u.full_name AS tourist_name
            FROM bookings b
            INNER JOIN listings l ON b.listing_id = l.listing_id
            INNER JOIN users u ON b.tourist_id = u.user_id
            WHERE l.vendor_id = ?
            ORDER BY b.created_at DESC, b.booking_id DESC
        `, [vendor.user_id, vendor.business_name, vendor.vendor_id]);

        res.json({
            success: true,
            bookings: rows.map((row) => mapBookingRow({
                ...row,
                vendor_id: vendor.vendor_id,
            })),
        });
    } catch (error) {
        console.error('Failed to load vendor bookings:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/:bookingId/cancel', authenticateToken, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const { reason } = req.body;

        const [result] = await mysqlPool.execute(`
            UPDATE bookings
            SET status = 'cancelled',
                payment_status = 'refunded',
                cancellation_reason = ?,
                cancelled_at = NOW()
            WHERE booking_id = ? AND tourist_id = ?
        `, [reason || null, bookingId, req.user.userId]);

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                error: 'Booking not found',
            });
        }

        res.json({
            success: true,
            message: 'Booking cancelled',
        });
    } catch (error) {
        console.error('Failed to cancel booking:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/:bookingId/status', authenticateToken, async (req, res) => {
    try {
        const { bookingId } = req.params;
        const { status, reason } = req.body;

        const allowedStatuses = new Set(['pending', 'confirmed', 'completed', 'cancelled']);
        if (!allowedStatuses.has(status)) {
            return res.status(400).json({
                success: false,
                error: 'Invalid status',
            });
        }

        const [vendorRows] = await mysqlPool.execute(
            'SELECT vendor_id FROM vendors WHERE user_id = ? LIMIT 1',
            [req.user.userId]
        );

        if (vendorRows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Vendor profile not found',
            });
        }

        const trimmedReason =
            typeof reason === 'string' && reason.trim().length > 0
                ? reason.trim()
                : null;
        const isCancelled = status === 'cancelled';

        const [result] = await mysqlPool.execute(`
            UPDATE bookings b
            INNER JOIN listings l ON b.listing_id = l.listing_id
            SET b.status = ?,
                b.cancellation_reason = CASE WHEN ? THEN ? ELSE b.cancellation_reason END,
                b.cancelled_at = CASE WHEN ? THEN NOW() ELSE b.cancelled_at END,
                b.payment_status = CASE WHEN ? THEN 'refunded' ELSE b.payment_status END,
                b.updated_at = NOW()
            WHERE b.booking_id = ? AND l.vendor_id = ?
        `, [
            status,
            isCancelled ? 1 : 0,
            trimmedReason ?? 'Rejected by vendor',
            isCancelled ? 1 : 0,
            isCancelled ? 1 : 0,
            bookingId,
            vendorRows[0].vendor_id,
        ]);

        if (result.affectedRows === 0) {
            return res.status(404).json({
                success: false,
                error: 'Booking not found',
            });
        }

        res.json({
            success: true,
            message: isCancelled
                ? 'Booking rejected by vendor'
                : 'Booking status updated',
        });
    } catch (error) {
        console.error('Failed to update booking status:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
