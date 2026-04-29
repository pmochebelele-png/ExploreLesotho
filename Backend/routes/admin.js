const express = require('express');
const { ObjectId } = require('mongodb');
const router = express.Router();
const { mysqlPool, getMongoDb } = require('../config/databases');
const { authenticateToken } = require('../middleware/auth');

const normalizeReview = (review) => ({
    id: review._id.toString(),
    listingId: review.listingId?.toString() ?? review.listing_id?.toString() ?? '',
    listingTitle: review.listingTitle ?? review.listing_title ?? 'Unknown Listing',
    bookingId: review.bookingId?.toString() ?? review.booking_id?.toString() ?? '',
    userId: review.userId?.toString() ?? review.user_id?.toString() ?? '',
    userName: review.userName ?? review.user_name ?? review.authorName ?? 'Anonymous',
    userAvatar: review.userAvatar ?? review.user_avatar,
    rating: parseFloat(review.rating ?? 0),
    comment: review.comment ?? '',
    images: Array.isArray(review.images) ? review.images : [],
    createdAt: review.createdAt ?? review.created_at ?? new Date().toISOString(),
    updatedAt: review.updatedAt ?? review.updated_at,
    vendorReply: review.vendorReply ?? review.vendor_reply,
    vendorReplyAt: review.vendorReplyAt ?? review.vendor_reply_at,
    isVerifiedPurchase: review.isVerifiedPurchase ?? review.is_verified_purchase ?? true,
    helpfulCount: review.helpfulCount ?? review.helpful_count ?? 0,
    reportedBy: review.reportedBy ?? review.reported_by ?? [],
    status: review.status ?? 'approved'
});

const requireAdmin = (req, res, next) => {
    if (req.user?.role !== 'admin') {
        return res.status(403).json({ success: false, message: 'Admin access required' });
    }
    next();
};

let cultureTablesReady = false;
let cultureTablesInFlight = null;
async function ensureCultureDirectoryTables() {
    if (cultureTablesReady) return;
    if (cultureTablesInFlight) return cultureTablesInFlight;

    cultureTablesInFlight = (async () => {
        await mysqlPool.execute(`
            CREATE TABLE IF NOT EXISTS culture_subcategories (
                subcategory_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(120) NOT NULL,
                slug VARCHAR(120) NOT NULL UNIQUE,
                icon VARCHAR(80) NULL,
                color VARCHAR(24) NULL,
                sort_order INT NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);

        await mysqlPool.execute(`
            CREATE TABLE IF NOT EXISTS culture_vendors (
                vendor_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(180) NOT NULL,
                product_range TEXT NULL,
                contacts_json TEXT NULL,
                location VARCHAR(180) NULL,
                source_document VARCHAR(180) NULL,
                linked_vendor_id BIGINT NULL,
                linked_vendor_user_id BIGINT NULL,
                claimed_at TIMESTAMP NULL DEFAULT NULL,
                status ENUM('active', 'inactive') NOT NULL DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uq_culture_vendor_name_location (name, location)
            )
        `);

        await mysqlPool.execute(`
            CREATE TABLE IF NOT EXISTS culture_vendor_subcategories (
                vendor_id BIGINT NOT NULL,
                subcategory_id BIGINT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (vendor_id, subcategory_id),
                CONSTRAINT fk_culture_vendor_sub_vendor
                    FOREIGN KEY (vendor_id) REFERENCES culture_vendors(vendor_id)
                    ON DELETE CASCADE,
                CONSTRAINT fk_culture_vendor_sub_subcategory
                    FOREIGN KEY (subcategory_id) REFERENCES culture_subcategories(subcategory_id)
                    ON DELETE CASCADE
            )
        `);

        const claimColumns = [
            { name: 'linked_vendor_id', definition: 'BIGINT NULL' },
            { name: 'linked_vendor_user_id', definition: 'BIGINT NULL' },
            { name: 'claimed_at', definition: 'TIMESTAMP NULL DEFAULT NULL' },
        ];

        for (const column of claimColumns) {
            const [columnRows] = await mysqlPool.execute(
                `SELECT COUNT(*) AS count
                 FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME = 'culture_vendors'
                   AND COLUMN_NAME = ?`,
                [column.name]
            );

            if ((columnRows[0]?.count ?? 0) === 0) {
                await mysqlPool.execute(
                    `ALTER TABLE culture_vendors ADD COLUMN ${column.name} ${column.definition}`
                );
            }
        }

        cultureTablesReady = true;
    })();

    try {
        await cultureTablesInFlight;
    } finally {
        cultureTablesInFlight = null;
    }
}

router.get('/stats', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();

        const [userCountRows] = await mysqlPool.execute(
            'SELECT COUNT(*) AS totalUsers FROM users'
        );
        const [vendorCountRows] = await mysqlPool.execute(
            'SELECT COUNT(*) AS totalVendors FROM vendors'
        );
        const [bookingStatsRows] = await mysqlPool.execute(`
            SELECT
                COUNT(*) AS totalBookings,
                SUM(CASE WHEN status != 'cancelled' THEN 1 ELSE 0 END) AS activeBookings,
                SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelledBookings,
                IFNULL(SUM(CASE WHEN status != 'cancelled' THEN total_price ELSE 0 END), 0) AS bookingRevenue
            FROM bookings
        `);
        const [eventTicketRevenueRows] = await mysqlPool.execute(`
            SELECT
                COUNT(*) AS totalTicketOrders,
                IFNULL(SUM(CASE
                    WHEN status = 'confirmed' AND payment_status = 'paid'
                    THEN total_amount
                    ELSE 0
                END), 0) AS eventTicketRevenue
            FROM event_ticket_orders
        `);
        const [pendingVendorRows] = await mysqlPool.execute(
            "SELECT COUNT(*) AS pendingVendors FROM vendors WHERE verified = 0 OR status = 'pending'"
        );

        const bookingRevenue = parseFloat(bookingStatsRows[0].bookingRevenue || 0);
        const eventTicketRevenue = parseFloat(
            eventTicketRevenueRows[0].eventTicketRevenue || 0
        );
        const totalRevenue = bookingRevenue + eventTicketRevenue;

        res.json({
            success: true,
            stats: {
                totalUsers: userCountRows[0].totalUsers,
                totalVendors: vendorCountRows[0].totalVendors,
                totalBookings: bookingStatsRows[0].totalBookings,
                activeBookings: Number(bookingStatsRows[0].activeBookings || 0),
                cancelledBookings: Number(bookingStatsRows[0].cancelledBookings || 0),
                totalRevenue,
                bookingRevenue,
                eventTicketRevenue,
                totalTicketOrders: Number(eventTicketRevenueRows[0].totalTicketOrders || 0),
                pendingVendors: pendingVendorRows[0].pendingVendors,
                pendingReviews: 0
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/users/all', authenticateToken, async (req, res) => {
    try {
        const [users] = await mysqlPool.execute(`
            SELECT
                u.user_id,
                u.full_name,
                u.email,
                u.role,
                COALESCE(u.phone, '') AS phone,
                0 AS suspended,
                v.vendor_id,
                v.verified,
                v.business_name,
                v.status AS vendor_status
            FROM users u
            LEFT JOIN vendors v ON u.user_id = v.user_id
            ORDER BY u.created_at DESC
        `);

        res.json({ success: true, users });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/users/:id/suspend', authenticateToken, async (req, res) => {
    try {
        const userId = req.params.id;
        const suspended = req.body?.suspended == true ? 1 : 0;

        const [columns] = await mysqlPool.execute(`
            SELECT COUNT(*) AS hasColumn
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'users'
              AND COLUMN_NAME = 'suspended'
        `);

        if (columns[0].hasColumn === 0) {
            return res.status(400).json({
                success: false,
                message: 'User suspension is not available in the current schema.'
            });
        }

        await mysqlPool.execute(
            'UPDATE users SET suspended = ? WHERE user_id = ?',
            [suspended, userId]
        );

        res.json({
            success: true,
            message: suspended ? 'User suspended.' : 'User activated.'
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.delete('/users/:id', authenticateToken, async (req, res) => {
    try {
        const userId = req.params.id;
        await mysqlPool.execute('DELETE FROM users WHERE user_id = ?', [userId]);
        res.json({ success: true, message: 'User removed from system.' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/vendors/all', authenticateToken, async (req, res) => {
    try {
        const [vendors] = await mysqlPool.execute(`
            SELECT
                v.vendor_id,
                v.user_id,
                v.business_name,
                v.business_email,
                v.business_phone,
                v.business_type,
                v.business_address,
                v.verified,
                v.status,
                v.created_at AS joinedAt,
                u.full_name,
                u.email
            FROM vendors v
            INNER JOIN users u ON v.user_id = u.user_id
            ORDER BY v.created_at DESC
        `);

        res.json({ success: true, vendors });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/vendors/:id/verify', authenticateToken, async (req, res) => {
    try {
        const id = req.params.id;
        await mysqlPool.execute(
            `UPDATE vendors
             SET verified = 1, status = 'active'
             WHERE vendor_id = ? OR user_id = ?`,
            [id, id]
        );
        res.json({ success: true, message: 'Vendor verified and approved.' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/vendors/:id/reject', authenticateToken, async (req, res) => {
    try {
        const id = req.params.id;
        await mysqlPool.execute(
            `UPDATE vendors
             SET verified = 0, status = 'rejected'
             WHERE vendor_id = ? OR user_id = ?`,
            [id, id]
        );
        res.json({ success: true, message: 'Vendor rejected.' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/reviews', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();
        const reviews = await db.collection('reviews').find({}).sort({ createdAt: -1, created_at: -1 }).toArray();
        res.json({
            success: true,
            reviews: reviews.map(normalizeReview)
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// ==================== EVENT MANAGEMENT ROUTES ====================
let eventColumnsReady = false;
let eventColumnsInFlight = null;
let eventTicketTablesReady = false;
let eventTicketTablesInFlight = null;

const cleanText = (value) => {
    if (typeof value !== 'string') return null;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
};

const cleanUrl = (value) => {
    const text = cleanText(value);
    if (!text) return null;
    if (text.startsWith('http://') || text.startsWith('https://')) {
        return text;
    }
    return `https://${text}`;
};

const normalizeDateTimeForMysql = (value) => {
    if (!value) return null;

    if (value instanceof Date && !Number.isNaN(value.getTime())) {
        return value.toISOString().slice(0, 19).replace('T', ' ');
    }

    if (typeof value === 'string') {
        const trimmed = value.trim();
        if (!trimmed) return null;

        const parsed = new Date(trimmed);
        if (!Number.isNaN(parsed.getTime())) {
            return parsed.toISOString().slice(0, 19).replace('T', ' ');
        }

        return trimmed.replace('T', ' ').replace('Z', '');
    }

    return null;
};

async function ensureEventColumns() {
    if (eventColumnsReady) return;
    if (eventColumnsInFlight) return eventColumnsInFlight;

    eventColumnsInFlight = (async () => {
        const requiredColumns = [
            { name: 'organizer_name', definition: 'VARCHAR(255) NULL' },
            { name: 'organizer_email', definition: 'VARCHAR(255) NULL' },
            { name: 'organizer_phone', definition: 'VARCHAR(80) NULL' },
            { name: 'organizer_website', definition: 'VARCHAR(500) NULL' },
            { name: 'ticket_url', definition: 'VARCHAR(500) NULL' }
        ];

        for (const column of requiredColumns) {
            const [rows] = await mysqlPool.execute(
                `SELECT COUNT(*) AS count
                 FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME = 'events'
                   AND COLUMN_NAME = ?`,
                [column.name]
            );

            if ((rows[0]?.count ?? 0) === 0) {
                await mysqlPool.execute(
                    `ALTER TABLE events ADD COLUMN ${column.name} ${column.definition}`
                );
            }
        }

        eventColumnsReady = true;
    })();

    try {
        await eventColumnsInFlight;
    } finally {
        eventColumnsInFlight = null;
    }
}

async function ensureEventTicketTables() {
    if (eventTicketTablesReady) return;
    if (eventTicketTablesInFlight) return eventTicketTablesInFlight;

    eventTicketTablesInFlight = (async () => {
        await mysqlPool.execute(`
            CREATE TABLE IF NOT EXISTS event_ticket_orders (
                order_id BIGINT AUTO_INCREMENT PRIMARY KEY,
                event_id BIGINT NOT NULL,
                user_id BIGINT NOT NULL,
                quantity INT NOT NULL,
                total_amount DECIMAL(10,2) NULL,
                service_fee DECIMAL(10,2) NULL,
                payment_id VARCHAR(120) NULL,
                payment_status VARCHAR(40) NULL,
                payment_method VARCHAR(60) NULL,
                status ENUM('confirmed', 'cancelled') NOT NULL DEFAULT 'confirmed',
                purchased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_event_ticket_orders_event (event_id),
                INDEX idx_event_ticket_orders_user (user_id)
            )
        `);

        const requiredColumns = [
            { name: 'total_amount', definition: 'DECIMAL(10,2) NULL' },
            { name: 'service_fee', definition: 'DECIMAL(10,2) NULL' },
            { name: 'payment_id', definition: 'VARCHAR(120) NULL' },
            { name: 'payment_status', definition: 'VARCHAR(40) NULL' },
            { name: 'payment_method', definition: 'VARCHAR(60) NULL' },
        ];

        for (const column of requiredColumns) {
            const [rows] = await mysqlPool.execute(
                `SELECT COUNT(*) AS count
                 FROM INFORMATION_SCHEMA.COLUMNS
                 WHERE TABLE_SCHEMA = DATABASE()
                   AND TABLE_NAME = 'event_ticket_orders'
                   AND COLUMN_NAME = ?`,
                [column.name]
            );

            if ((rows[0]?.count ?? 0) === 0) {
                await mysqlPool.execute(
                    `ALTER TABLE event_ticket_orders ADD COLUMN ${column.name} ${column.definition}`
                );
            }
        }

        eventTicketTablesReady = true;
    })();

    try {
        await eventTicketTablesInFlight;
    } finally {
        eventTicketTablesInFlight = null;
    }
}

async function loadEventById(eventId) {
    await ensureEventTicketTables();
    const [events] = await mysqlPool.execute(
        `SELECT
            e.event_id,
            e.vendor_id,
            e.title,
            e.description,
            e.location,
            e.start_datetime,
            e.end_datetime,
            e.image_url,
            e.price,
            e.category,
            e.status,
            e.max_capacity,
            e.organizer_name,
            e.organizer_email,
            e.organizer_phone,
            e.organizer_website,
            e.ticket_url,
            COALESCE(SUM(CASE WHEN eto.status = 'confirmed' THEN eto.quantity ELSE 0 END), 0) AS tickets_sold,
            CASE
                WHEN e.max_capacity IS NULL THEN NULL
                ELSE GREATEST(e.max_capacity - COALESCE(SUM(CASE WHEN eto.status = 'confirmed' THEN eto.quantity ELSE 0 END), 0), 0)
            END AS tickets_remaining,
            e.created_at,
            e.updated_at,
            u.full_name AS vendor_name,
            v.business_name AS vendor_business_name,
            COALESCE(NULLIF(e.organizer_name, ''), v.business_name) AS organizer
         FROM events e
         LEFT JOIN users u ON e.vendor_id = u.user_id
         LEFT JOIN vendors v ON e.vendor_id = v.user_id
         LEFT JOIN event_ticket_orders eto ON eto.event_id = e.event_id
         WHERE e.event_id = ?
         GROUP BY
            e.event_id, e.vendor_id, e.title, e.description, e.location,
            e.start_datetime, e.end_datetime, e.image_url, e.price, e.category,
            e.status, e.max_capacity, e.organizer_name, e.organizer_email,
            e.organizer_phone, e.organizer_website, e.ticket_url, e.created_at,
            e.updated_at, u.full_name, v.business_name`,
        [eventId]
    );

    return events[0] ?? null;
}

async function canManageEvent(eventId, user) {
    if (!user) return false;
    if (user.role === 'admin') return true;
    const event = await loadEventById(eventId);
    if (!event) return false;
    const currentUserId = user.user_id || user.userId;
    return Number(event.vendor_id) === Number(currentUserId);
}

router.get('/events', async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();
        const { upcoming, vendor_id, category, status } = req.query;

        let query = `
            SELECT
                e.event_id,
                e.vendor_id,
                e.title,
                e.description,
                e.location,
                e.start_datetime,
                e.end_datetime,
                e.image_url,
                e.price,
                e.category,
                e.status,
                e.max_capacity,
                e.organizer_name,
                e.organizer_email,
                e.organizer_phone,
                e.organizer_website,
                e.ticket_url,
                COALESCE(SUM(CASE WHEN eto.status = 'confirmed' THEN eto.quantity ELSE 0 END), 0) AS tickets_sold,
                CASE
                    WHEN e.max_capacity IS NULL THEN NULL
                    ELSE GREATEST(e.max_capacity - COALESCE(SUM(CASE WHEN eto.status = 'confirmed' THEN eto.quantity ELSE 0 END), 0), 0)
                END AS tickets_remaining,
                e.created_at,
                e.updated_at,
                u.full_name AS vendor_name,
                v.business_name AS vendor_business_name,
                COALESCE(NULLIF(e.organizer_name, ''), v.business_name) AS organizer
            FROM events e
            LEFT JOIN users u ON e.vendor_id = u.user_id
            LEFT JOIN vendors v ON e.vendor_id = v.user_id
            LEFT JOIN event_ticket_orders eto ON eto.event_id = e.event_id
            WHERE 1=1
        `;
        const params = [];

        if (upcoming === 'true') {
            query += ` AND e.start_datetime > NOW() AND e.status != 'cancelled'`;
        }
        if (vendor_id) {
            query += ` AND e.vendor_id = ?`;
            params.push(vendor_id);
        }
        if (category) {
            query += ` AND e.category = ?`;
            params.push(category);
        }
        if (status) {
            query += ` AND e.status = ?`;
            params.push(status);
        }

        query += ` GROUP BY
                e.event_id, e.vendor_id, e.title, e.description, e.location,
                e.start_datetime, e.end_datetime, e.image_url, e.price, e.category,
                e.status, e.max_capacity, e.organizer_name, e.organizer_email,
                e.organizer_phone, e.organizer_website, e.ticket_url, e.created_at,
                e.updated_at, u.full_name, v.business_name
            ORDER BY e.start_datetime ASC`;
        const [events] = await mysqlPool.execute(query, params);
        res.json({ success: true, events });
    } catch (error) {
        console.error('Error fetching events:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/events/:id', async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();
        const event = await loadEventById(req.params.id);

        if (!event) {
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        res.json({ success: true, event });
    } catch (error) {
        console.error('Error fetching event:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/events', authenticateToken, async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();
        const {
            title,
            description,
            location,
            start_datetime,
            end_datetime,
            image_url,
            price,
            category,
            max_capacity,
            organizer_name,
            organizer_email,
            organizer_phone,
            organizer_website,
            ticket_url
        } = req.body;

        const targetUserId = req.user.user_id || req.user.userId;
        if (!targetUserId) {
            return res.status(401).json({
                success: false,
                message: 'User ID not found. Please login again.'
            });
        }

        if (!cleanText(title) || !cleanText(description) || !cleanText(location) || !start_datetime || !end_datetime) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields: title, description, location, start_datetime, end_datetime'
            });
        }

        const [result] = await mysqlPool.execute(
            `INSERT INTO events
            (vendor_id, title, description, location, start_datetime, end_datetime,
             image_url, price, category, max_capacity, organizer_name, organizer_email,
             organizer_phone, organizer_website, ticket_url, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'upcoming', NOW(), NOW())`,
            [
                targetUserId,
                cleanText(title),
                cleanText(description),
                cleanText(location),
                normalizeDateTimeForMysql(start_datetime),
                normalizeDateTimeForMysql(end_datetime),
                cleanUrl(image_url),
                Number(price) || 0,
                cleanText(category),
                max_capacity ? parseInt(max_capacity, 10) : null,
                cleanText(organizer_name),
                cleanText(organizer_email),
                cleanText(organizer_phone),
                cleanUrl(organizer_website),
                cleanUrl(ticket_url)
            ]
        );

        res.status(201).json({
            success: true,
            message: 'Event created successfully',
            event_id: result.insertId
        });
    } catch (error) {
        console.error('Error creating event:', error);
        res.status(500).json({ success: false, message: error.message });
    }
});

router.put('/events/:id', authenticateToken, async (req, res) => {
    const eventId = req.params.id;
    const {
        title,
        description,
        location,
        start_datetime,
        end_datetime,
        image_url,
        price,
        category,
        status,
        max_capacity,
        organizer_name,
        organizer_email,
        organizer_phone,
        organizer_website,
        ticket_url
    } = req.body;

    try {
        await ensureEventColumns();
        await ensureEventTicketTables();
        const isOwner = await canManageEvent(eventId, req.user);
        if (!isOwner) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        await mysqlPool.execute(
            `UPDATE events SET
                title = ?, description = ?, location = ?,
                start_datetime = ?, end_datetime = ?, image_url = ?,
                price = ?, category = ?, status = ?, max_capacity = ?,
                organizer_name = ?, organizer_email = ?, organizer_phone = ?,
                organizer_website = ?, ticket_url = ?,
                updated_at = NOW()
            WHERE event_id = ?`,
            [
                cleanText(title),
                cleanText(description),
                cleanText(location),
                normalizeDateTimeForMysql(start_datetime),
                normalizeDateTimeForMysql(end_datetime),
                cleanUrl(image_url),
                Number(price) || 0,
                cleanText(category),
                cleanText(status) || 'upcoming',
                max_capacity ? parseInt(max_capacity, 10) : null,
                cleanText(organizer_name),
                cleanText(organizer_email),
                cleanText(organizer_phone),
                cleanUrl(organizer_website),
                cleanUrl(ticket_url),
                eventId
            ]
        );

        res.json({ success: true, message: 'Event updated successfully' });
    } catch (error) {
        console.error('Error updating event:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

router.delete('/events/:id', authenticateToken, async (req, res) => {
    const eventId = req.params.id;

    try {
        await ensureEventColumns();
        await ensureEventTicketTables();
        const isOwner = await canManageEvent(eventId, req.user);
        if (!isOwner) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        await mysqlPool.execute('DELETE FROM events WHERE event_id = ?', [eventId]);
        res.json({ success: true, message: 'Event deleted successfully' });
    } catch (error) {
        console.error('Error deleting event:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ==================== CULTURE DIRECTORY REVIEW (ADMIN) ====================
router.get('/culture/subcategories', authenticateToken, requireAdmin, async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const [rows] = await mysqlPool.execute(`
            SELECT subcategory_id, name, slug, icon, color, sort_order
            FROM culture_subcategories
            ORDER BY sort_order ASC, name ASC
        `);
        res.json({
            success: true,
            subcategories: rows.map((row) => ({
                id: row.subcategory_id?.toString(),
                name: row.name,
                slug: row.slug,
                icon: row.icon,
                color: row.color,
                sortOrder: Number(row.sort_order ?? 0),
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/culture/vendors', authenticateToken, requireAdmin, async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const search = req.query.search?.toString().trim().toLowerCase() || '';
        const status = req.query.status?.toString().trim().toLowerCase() || '';
        const subcategory = req.query.subcategory?.toString().trim() || '';
        const params = [];
        let where = 'WHERE 1=1';

        if (status === 'active' || status === 'inactive') {
            where += ' AND cv.status = ?';
            params.push(status);
        }
        if (subcategory) {
            where += ' AND cs.slug = ?';
            params.push(subcategory);
        }
        if (search) {
            where += `
                AND (
                    LOWER(cv.name) LIKE ?
                    OR LOWER(COALESCE(cv.product_range, '')) LIKE ?
                    OR LOWER(COALESCE(cv.location, '')) LIKE ?
                )
            `;
            const pattern = `%${search}%`;
            params.push(pattern, pattern, pattern);
        }

        const [rows] = await mysqlPool.execute(
            `
            SELECT
                cv.vendor_id,
                cv.name,
                cv.product_range,
                cv.contacts_json,
                cv.location,
                cv.status,
                cv.source_document,
                cv.linked_vendor_id,
                cv.linked_vendor_user_id,
                cv.claimed_at,
                cv.updated_at,
                GROUP_CONCAT(DISTINCT cs.name ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_names,
                GROUP_CONCAT(DISTINCT cs.slug ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_slugs
            FROM culture_vendors cv
            LEFT JOIN culture_vendor_subcategories cvs ON cvs.vendor_id = cv.vendor_id
            LEFT JOIN culture_subcategories cs ON cs.subcategory_id = cvs.subcategory_id
            ${where}
            GROUP BY
                cv.vendor_id, cv.name, cv.product_range, cv.contacts_json, cv.location,
                cv.status, cv.source_document, cv.linked_vendor_id, cv.linked_vendor_user_id,
                cv.claimed_at, cv.updated_at
            ORDER BY cv.updated_at DESC, cv.vendor_id DESC
            `,
            params
        );

        const vendors = rows.map((row) => {
            let contacts = [];
            try {
                contacts = row.contacts_json ? JSON.parse(row.contacts_json) : [];
            } catch {
                contacts = [];
            }
            return {
                id: row.vendor_id?.toString(),
                name: row.name ?? '',
                productRange: row.product_range ?? '',
                contacts,
                location: row.location ?? '',
                status: row.status ?? 'active',
                sourceDocument: row.source_document ?? null,
                updatedAt: row.updated_at,
                linkedVendorId: row.linked_vendor_id?.toString() ?? null,
                linkedVendorUserId: row.linked_vendor_user_id?.toString() ?? null,
                claimedAt: row.claimed_at ?? null,
                isClaimed: row.linked_vendor_id != null,
                subcategories: row.subcategory_names
                    ? row.subcategory_names.toString().split('|').filter(Boolean)
                    : [],
                subcategorySlugs: row.subcategory_slugs
                    ? row.subcategory_slugs.toString().split('|').filter(Boolean)
                    : [],
            };
        });

        res.json({ success: true, vendors });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/culture/vendors/:id', authenticateToken, requireAdmin, async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const vendorId = req.params.id;
        const {
            name,
            productRange,
            location,
            contacts,
            status,
            subcategorySlugs
        } = req.body ?? {};

        const normalizedStatus =
            status === 'inactive' ? 'inactive' : 'active';
        let normalizedContacts = [];
        if (Array.isArray(contacts)) {
            normalizedContacts = contacts
                .map((item) => item?.toString().trim())
                .filter((item) => item);
        } else if (typeof contacts === 'string') {
            normalizedContacts = contacts
                .split(/[,\n]/)
                .map((item) => item.trim())
                .filter((item) => item);
        }

        await mysqlPool.execute(
            `
            UPDATE culture_vendors
            SET name = ?,
                product_range = ?,
                location = ?,
                contacts_json = ?,
                status = ?
            WHERE vendor_id = ?
            `,
            [
                name?.toString().trim() || '',
                productRange?.toString().trim() || null,
                location?.toString().trim() || null,
                JSON.stringify(normalizedContacts),
                normalizedStatus,
                vendorId
            ]
        );

        if (Array.isArray(subcategorySlugs)) {
            await mysqlPool.execute(
                'DELETE FROM culture_vendor_subcategories WHERE vendor_id = ?',
                [vendorId]
            );

            for (const slug of subcategorySlugs) {
                const [subRows] = await mysqlPool.execute(
                    'SELECT subcategory_id FROM culture_subcategories WHERE slug = ? LIMIT 1',
                    [slug]
                );
                if (!subRows.length) continue;
                await mysqlPool.execute(
                    `
                    INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
                    VALUES (?, ?)
                    `,
                    [vendorId, subRows[0].subcategory_id]
                );
            }
        }

        res.json({ success: true, message: 'Culture vendor updated' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});
module.exports = router;
