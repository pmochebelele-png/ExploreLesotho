// controllers/bookingController.js
const { mysqlPool, getMongoDb } = require('../config/databases');
const { validateBooking, validateDates } = require('../utils/validators');
const logger = require('../utils/logger');

// Create new booking
const createBooking = async (req, res) => {
    const connection = await mysqlPool.getConnection();
    try {
        await connection.beginTransaction();
        const db = getMongoDb();

        // Get MySQL user_id using email from token
        const [userRows] = await connection.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [req.user.email]
        );

        if (userRows.length === 0) {
            return res.status(400).json({ 
                error: 'User not found in MySQL. Please contact support.' 
            });
        }

        const mysqlUserId = userRows[0].user_id;
        const { listing_id, check_in, check_out, guests, total_price, special_requests } = req.body;

        // Validate input
        const errors = validateBooking({ listing_id, check_in, check_out, guests, total_price });
        if (errors.length > 0) {
            return res.status(400).json({ errors });
        }

        if (!validateDates(check_in, check_out)) {
            return res.status(400).json({ 
                error: 'Invalid dates. Check-out must be after check-in and dates must be in the future' 
            });
        }

        // Check if listing exists
        const [listing] = await connection.execute(
            'SELECT * FROM listings WHERE listing_id = ? AND status = "active"',
            [listing_id]
        );

        if (listing.length === 0) {
            return res.status(404).json({ error: 'Listing not found or not available' });
        }

        // Check availability
        const [availability] = await connection.execute(`
            SELECT available_date FROM availability 
            WHERE listing_id = ? 
            AND available_date BETWEEN ? AND ?
            AND status = 'booked'
        `, [listing_id, check_in, check_out]);

        if (availability.length > 0) {
            return res.status(400).json({ 
                error: 'Selected dates are not fully available',
                booked_dates: availability.map(a => a.available_date)
            });
        }

        // Generate booking reference
        const timestamp = Date.now().toString().slice(-8);
        const random = Math.floor(Math.random() * 1000);
        const bookingRef = `BKG-${timestamp}-${random}`;

        // Insert into MySQL
        const [result] = await connection.execute(`
            INSERT INTO bookings (
                booking_reference, tourist_id, listing_id, 
                check_in, check_out, guests, total_price, status,
                special_requests, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'confirmed', ?, NOW())
        `, [
            bookingRef,
            mysqlUserId,
            listing_id,
            check_in,
            check_out,
            guests,
            total_price,
            special_requests || null
        ]);

        const bookingId = result.insertId;

        // Update availability
        await connection.execute(`
            UPDATE availability 
            SET status = 'booked' 
            WHERE listing_id = ? 
            AND available_date BETWEEN ? AND ?
        `, [listing_id, check_in, check_out]);

        await connection.commit();

        // Store in MongoDB
        await db.collection('offline_sync_queue').insertOne({
            booking_id: bookingId,
            booking_reference: bookingRef,
            mongo_user_id: req.user.userId,
            mysql_user_id: mysqlUserId,
            action: 'create_booking',
            status: 'pending',
            created_at: new Date(),
            metadata: { listing_id, check_in, check_out, guests, total_price }
        });

        // Track analytics
        await db.collection('user_analytics').insertOne({
            user_id: req.user.userId,
            event_type: 'booking_created',
            booking_id: bookingId,
            listing_id,
            amount: total_price,
            timestamp: new Date()
        });

        logger.info(`Booking created: ${bookingRef} for user ${mysqlUserId}`);

        res.status(201).json({
            success: true,
            message: 'Booking created successfully',
            booking: {
                id: bookingId,
                reference: bookingRef,
                listing: {
                    id: listing[0].listing_id,
                    title: listing[0].title
                },
                check_in,
                check_out,
                guests,
                total_price,
                status: 'confirmed'
            }
        });

    } catch (error) {
        await connection.rollback();
        logger.error('Booking creation failed', error);
        res.status(500).json({ 
            error: 'Failed to create booking',
            details: error.message 
        });
    } finally {
        connection.release();
    }
};

// Get user bookings
const getUserBookings = async (req, res) => {
    try {
        // Get MySQL user_id from email
        const [userRows] = await mysqlPool.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [req.user.email]
        );

        if (userRows.length === 0) {
            return res.status(400).json({ error: 'User not found' });
        }

        const mysqlUserId = userRows[0].user_id;

        // Verify authorization
        if (mysqlUserId != req.params.userId && req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }

        // Get bookings
        const [bookings] = await mysqlPool.execute(`
            SELECT 
                b.*,
                l.title as listing_title,
                l.location,
                l.category,
                v.business_name as vendor_name,
                v.verified as vendor_verified
            FROM bookings b
            JOIN listings l ON b.listing_id = l.listing_id
            JOIN vendors v ON l.vendor_id = v.vendor_id
            WHERE b.tourist_id = ?
            ORDER BY b.created_at DESC
        `, [mysqlUserId]);

        // Calculate summary
        const summary = {
            total: bookings.length,
            total_spent: bookings.reduce((sum, b) => sum + parseFloat(b.total_price), 0),
            upcoming: bookings.filter(b => 
                new Date(b.check_in) > new Date() && b.status === 'confirmed'
            ).length,
            completed: bookings.filter(b => b.status === 'completed').length,
            cancelled: bookings.filter(b => b.status === 'cancelled').length
        };

        res.json({
            success: true,
            summary,
            count: bookings.length,
            bookings
        });

    } catch (error) {
        logger.error('Failed to fetch user bookings', error);
        res.status(500).json({ error: error.message });
    }
};

// Cancel booking
const cancelBooking = async (req, res) => {
    const connection = await mysqlPool.getConnection();
    try {
        await connection.beginTransaction();
        const db = getMongoDb();

        // Get booking details
        const [booking] = await connection.execute(`
            SELECT b.*, l.vendor_id 
            FROM bookings b
            JOIN listings l ON b.listing_id = l.listing_id
            WHERE b.booking_id = ?
        `, [req.params.bookingId]);

        if (booking.length === 0) {
            return res.status(404).json({ error: 'Booking not found' });
        }

        // Check authorization
        const [userRows] = await mysqlPool.execute(
            'SELECT user_id FROM users WHERE email = ?',
            [req.user.email]
        );

        const mysqlUserId = userRows[0]?.user_id;

        if (mysqlUserId != booking[0].tourist_id && 
            mysqlUserId != booking[0].vendor_id && 
            req.user.role !== 'admin') {
            return res.status(403).json({ error: 'Unauthorized' });
        }

        // Check if cancellable
        if (booking[0].status === 'cancelled') {
            return res.status(400).json({ error: 'Booking already cancelled' });
        }
        if (booking[0].status === 'completed') {
            return res.status(400).json({ error: 'Cannot cancel completed booking' });
        }

        // Update booking status
        await connection.execute(`
            UPDATE bookings 
            SET status = 'cancelled',
                cancellation_reason = ?,
                cancelled_at = NOW()
            WHERE booking_id = ?
        `, [req.body.reason || 'Cancelled by user', req.params.bookingId]);

        // Free up availability
        await connection.execute(`
            UPDATE availability 
            SET status = 'available' 
            WHERE listing_id = ? 
            AND available_date BETWEEN ? AND ?
        `, [booking[0].listing_id, booking[0].check_in, booking[0].check_out]);

        await connection.commit();

        // Track cancellation
        await db.collection('user_analytics').insertOne({
            user_id: req.user.userId,
            event_type: 'booking_cancelled',
            booking_id: parseInt(req.params.bookingId),
            timestamp: new Date()
        });

        logger.info(`Booking cancelled: ${req.params.bookingId}`);

        res.json({
            success: true,
            message: 'Booking cancelled successfully',
            booking_id: req.params.bookingId,
            status: 'cancelled'
        });

    } catch (error) {
        await connection.rollback();
        logger.error('Cancellation failed', error);
        res.status(500).json({ error: error.message });
    } finally {
        connection.release();
    }
};

module.exports = {
    createBooking,
    getUserBookings,
    cancelBooking
};