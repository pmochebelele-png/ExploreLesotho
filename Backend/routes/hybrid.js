// routes/hybrid.js
const express = require('express');
const router = express.Router();
const { ObjectId } = require('mongodb');
const { mysqlPool, getMongoDb } = require('../config/databases');
const { authenticateToken } = require('../middleware/auth');

const normalizeCategoryForDb = (category = '') => {
    const normalized = category.toString().trim().toLowerCase();
    const map = {
        accommodation: 'accommodation',
        tour: 'tour',
        experience: 'experience',
        adventure: 'adventure',
        transport: 'transport',
        restaurant: 'restaurant',
        culture: 'cultural',
        cultural: 'cultural'
    };
    return map[normalized] || 'accommodation';
};

const formatCategoryForUi = (category = '') => {
    const normalized = category.toString().trim().toLowerCase();
    const map = {
        accommodation: 'Accommodation',
        tour: 'Tour',
        experience: 'Experience',
        adventure: 'Adventure',
        transport: 'Transport',
        restaurant: 'Restaurant',
        cultural: 'Culture'
    };
    return map[normalized] || 'Accommodation';
};

const normalizePriceUnitForDb = (priceUnit = '') => {
    const normalized = priceUnit.toString().trim().toLowerCase();
    const map = {
        '/night': 'per_night',
        '/hour': 'per_hour',
        '/person': 'per_person',
        '/entry': 'fixed',
        '/group': 'fixed',
        fixed: 'fixed',
        per_night: 'per_night',
        per_hour: 'per_hour',
        per_person: 'per_person'
    };
    return map[normalized] || 'per_night';
};

const formatPriceUnitForUi = (priceUnit = '') => {
    const normalized = priceUnit.toString().trim().toLowerCase();
    const map = {
        per_night: '/night',
        per_hour: '/hour',
        per_person: '/person',
        fixed: ''
    };
    return map[normalized] ?? '/night';
};

const mapListingRow = (row) => ({
    id: row.listing_id?.toString() ?? '',
    title: row.title ?? '',
    description: row.description ?? '',
    category: formatCategoryForUi(row.category),
    price: parseFloat(row.price ?? 0),
    priceUnit: formatPriceUnitForUi(row.price_unit),
    location: row.location ?? '',
    district: row.district,
    rating: row.average_rating != null ? parseFloat(row.average_rating) : null,
    reviewCount: row.review_count != null ? Number(row.review_count) : 0,
    imageUrl: row.featured_image ?? null,
    isFeatured: false,
    isAvailable: (row.status ?? 'active') === 'active',
    vendorId: row.user_id?.toString() ?? row.vendor_id?.toString(),
    vendorName: row.business_name ?? row.vendor_name ?? '',
    vendorPhone: row.business_phone ?? null,
    vendorEmail: row.business_email ?? row.email ?? null,
    vendorWebsite: null,
    vendorFacebook: row.facebook ?? null,
    vendorInstagram: row.instagram ?? null,
    vendorWhatsapp: row.whatsapp ?? null,
    images: Array.isArray(row.images) ? row.images : [],
    additionalDetails: row.additional_details && typeof row.additional_details === 'object'
        ? row.additional_details
        : null,
});

const getListingMediaCollection = () => {
    const db = getMongoDb();
    return db ? db.collection('listing_media') : null;
};

const enrichListingsWithMedia = async (rows) => {
    const collection = getListingMediaCollection();
    if (!collection || rows.length === 0) {
        return rows.map((row) => mapListingRow(row));
    }

    const mediaRows = await collection
        .find({ listing_id: { $in: rows.map((row) => Number(row.listing_id)) } })
        .toArray();

    const mediaMap = new Map(mediaRows.map((media) => [
        String(media.listing_id),
        {
            images: Array.isArray(media.images) ? media.images : [],
            additionalDetails: media.additionalDetails && typeof media.additionalDetails === 'object'
                ? media.additionalDetails
                : null,
        }
    ]));

    return rows.map((row) => {
        const media = mediaMap.get(String(row.listing_id)) ?? {};
        const images = media.images ?? [];
        return mapListingRow({
            ...row,
            images,
            additional_details: media.additionalDetails ?? null,
            featured_image: images[0] ?? row.featured_image ?? null,
        });
    });
};

const normalizeImagesPayload = (images) => {
    if (!images) {
        return [];
    }

    let payload = images;
    if (typeof payload === 'string') {
        const trimmed = payload.trim();
        if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
            try {
                const parsed = JSON.parse(trimmed);
                payload = parsed;
            } catch {
                payload = [trimmed];
            }
        } else {
            payload = [trimmed];
        }
    }

    if (!Array.isArray(payload)) {
        return [];
    }

    return payload
        .map((image) => (typeof image === 'string' ? image.trim() : ''))
        .filter((image) => image.length > 0);
};

const saveListingMedia = async (listingId, images = [], additionalDetails = null) => {
    const collection = getListingMediaCollection();
    if (!collection) {
        return [];
    }

    const normalizedImages = normalizeImagesPayload(images);
    const normalizedDetails =
        additionalDetails && typeof additionalDetails === 'object'
            ? additionalDetails
            : null;

    await collection.updateOne(
        { listing_id: Number(listingId) },
        {
            $set: {
                listing_id: Number(listingId),
                images: normalizedImages,
                additionalDetails: normalizedDetails,
                updated_at: new Date(),
            },
            $setOnInsert: {
                created_at: new Date(),
            },
        },
        { upsert: true }
    );

    return normalizedImages;
};

const resolveActorId = (user = {}) => {
    return user.userId ?? user.user_id ?? user.id ?? user.sub ?? null;
};

const getVendorForActor = async (user) => {
    const actorId = resolveActorId(user);
    const actorEmail = user?.email?.toString().trim() || null;
    if (actorId == null) {
        if (!actorEmail) {
            return null;
        }
    }
    const [vendors] = await mysqlPool.execute(
        `
        SELECT
            vendor_id, user_id, business_name, business_phone, business_email,
            facebook, instagram, whatsapp, verified
        FROM vendors
        WHERE user_id = ? OR vendor_id = ? OR LOWER(TRIM(business_email)) = LOWER(TRIM(?))
        LIMIT 1
        `,
        [actorId, actorId, actorEmail]
    );
    return vendors[0] ?? null;
};

const canManageEvent = async (eventId, user) => {
    const actorId = resolveActorId(user);
    const vendor = await getVendorForActor(user);
    if (actorId == null && !vendor) {
        return false;
    }

    const [rows] = await mysqlPool.execute(
        `SELECT e.event_id
         FROM events e
         WHERE e.event_id = ?
           AND (
               e.vendor_id = ?
               OR e.vendor_id = ?
               OR e.vendor_id = ?
           )
         LIMIT 1`,
        [
            eventId,
            actorId,
            vendor?.user_id ?? actorId,
            vendor?.vendor_id ?? actorId
        ]
    );

    return rows.length > 0;
};

let eventColumnsReady = false;
let eventColumnsInFlight = null;
let eventTicketTablesReady = false;
let eventTicketTablesInFlight = null;

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
            { name: 'currency', definition: 'VARCHAR(12) NULL' },
            { name: 'buyer_phone', definition: 'VARCHAR(40) NULL' },
            { name: 'receipt_number', definition: 'VARCHAR(80) NULL' },
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
            COALESCE(SUM(CASE WHEN eto.status = 'confirmed' AND eto.payment_status = 'paid' THEN eto.quantity ELSE 0 END), 0) AS tickets_sold,
            CASE
                WHEN e.max_capacity IS NULL THEN NULL
                ELSE GREATEST(e.max_capacity - COALESCE(SUM(CASE WHEN eto.status = 'confirmed' AND eto.payment_status = 'paid' THEN eto.quantity ELSE 0 END), 0), 0)
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

let ensureCultureTablesPromise = null;
const ensureCultureDirectoryTables = async () => {
    if (!ensureCultureTablesPromise) {
        ensureCultureTablesPromise = (async () => {
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

            const defaultSubcategories = [
                { name: 'Crafts', slug: 'crafts', icon: 'handyman', color: '#8D6E63', sort: 1 },
                { name: 'Music', slug: 'music', icon: 'music_note', color: '#6A1B9A', sort: 2 },
                { name: 'Dance', slug: 'dance', icon: 'nightlife', color: '#E91E63', sort: 3 },
                { name: 'Art', slug: 'art', icon: 'palette', color: '#3949AB', sort: 4 },
                { name: 'Food Heritage', slug: 'food-heritage', icon: 'restaurant', color: '#F57C00', sort: 5 },
                { name: 'Storytelling', slug: 'storytelling', icon: 'menu_book', color: '#546E7A', sort: 6 },
                { name: 'History', slug: 'history', icon: 'history_edu', color: '#00796B', sort: 7 },
                { name: 'Traditional Wear', slug: 'traditional-wear', icon: 'checkroom', color: '#00838F', sort: 8 },
                { name: 'Architecture', slug: 'architecture', icon: 'architecture', color: '#1E88E5', sort: 9 },
                { name: 'Spiritual Heritage', slug: 'spiritual-heritage', icon: 'temple_buddhist', color: '#43A047', sort: 10 },
                { name: 'Festival', slug: 'festival', icon: 'celebration', color: '#FB8C00', sort: 11 },
            ];

            for (const sub of defaultSubcategories) {
                await mysqlPool.execute(
                    `INSERT IGNORE INTO culture_subcategories (name, slug, icon, color, sort_order)
                     VALUES (?, ?, ?, ?, ?)`,
                    [sub.name, sub.slug, sub.icon, sub.color, sub.sort]
                );
            }

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
        })();
    }
    await ensureCultureTablesPromise;
};

const normalizeCultureSubtypeSlug = (value = '') => {
    const normalized = value.toString().trim().toLowerCase();
    const map = {
        crafts: 'crafts',
        craft: 'crafts',
        music: 'music',
        dance: 'dance',
        art: 'art',
        'food heritage': 'food-heritage',
        food: 'food-heritage',
        storytelling: 'storytelling',
        stories: 'storytelling',
        history: 'history',
        'traditional wear': 'traditional-wear',
        clothing: 'traditional-wear',
        attire: 'traditional-wear',
        architecture: 'architecture',
        'spiritual heritage': 'spiritual-heritage',
        spiritual: 'spiritual-heritage',
        festival: 'festival',
    };
    return map[normalized] || null;
};

const inferCultureSubtypeSlug = (additionalDetails, title, description) => {
    const rawCultureType = additionalDetails?.cultureType?.toString() ?? '';
    const rawHeritageFocus = additionalDetails?.heritageFocus?.toString() ?? '';
    const normalizedType = rawCultureType.replace(/[[\]"]/g, '').trim();
    const directSlug =
        normalizeCultureSubtypeSlug(normalizedType) ||
        normalizeCultureSubtypeSlug(rawHeritageFocus.split(',')[0]);
    if (directSlug) return directSlug;

    const text = `${title ?? ''} ${description ?? ''}`.toLowerCase();
    if (text.includes('festival')) return 'festival';
    if (text.includes('music')) return 'music';
    if (text.includes('dance')) return 'dance';
    if (text.includes('art')) return 'art';
    if (text.includes('craft')) return 'crafts';
    return 'crafts';
};

const syncCultureDirectoryFromListing = async ({
    category,
    title,
    description,
    location,
    additionalDetails,
    vendor
}) => {
    if (normalizeCategoryForDb(category) !== 'cultural') {
        return;
    }

    await ensureCultureDirectoryTables();

    const subtypeSlug = inferCultureSubtypeSlug(additionalDetails, title, description);
    const contacts = [
        vendor.business_phone,
        vendor.whatsapp,
        vendor.business_email
    ]
        .map((v) => v?.toString().trim())
        .filter((v) => v);

    const [vendorResult] = await mysqlPool.execute(
        `
        INSERT INTO culture_vendors (name, product_range, contacts_json, location, source_document, status)
        VALUES (?, ?, ?, ?, 'listing-sync', 'active')
        ON DUPLICATE KEY UPDATE
            product_range = VALUES(product_range),
            contacts_json = VALUES(contacts_json),
            status = 'active',
            vendor_id = LAST_INSERT_ID(vendor_id)
        `,
        [
            vendor.business_name,
            description || title || '',
            JSON.stringify(contacts),
            location || null
        ]
    );

    const cultureVendorId = Number(vendorResult.insertId);
    const [subcategoryRows] = await mysqlPool.execute(
        'SELECT subcategory_id FROM culture_subcategories WHERE slug = ? LIMIT 1',
        [subtypeSlug]
    );

    if (!subcategoryRows.length) return;

    await mysqlPool.execute(
        `
        INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
        VALUES (?, ?)
        `,
        [cultureVendorId, subcategoryRows[0].subcategory_id]
    );
};

// ============================================
// GET APPROVED/ACTIVE LISTINGS FOR TOURISTS
// ============================================
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
                COALESCE(SUM(CASE WHEN eto.status = 'confirmed' AND eto.payment_status = 'paid' THEN eto.quantity ELSE 0 END), 0) AS tickets_sold,
                CASE
                    WHEN e.max_capacity IS NULL THEN NULL
                    ELSE GREATEST(e.max_capacity - COALESCE(SUM(CASE WHEN eto.status = 'confirmed' AND eto.payment_status = 'paid' THEN eto.quantity ELSE 0 END), 0), 0)
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
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/events/:id/ticket-orders', authenticateToken, async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();

        const eventId = Number(req.params.id);
        if (!Number.isFinite(eventId) || eventId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid event id' });
        }

        const isOwner = await canManageEvent(eventId, req.user);
        if (!isOwner) {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        const [rows] = await mysqlPool.execute(
            `SELECT
                eto.order_id,
                eto.event_id,
                eto.user_id,
                eto.quantity,
                eto.total_amount,
                eto.service_fee,
                eto.payment_id,
                eto.payment_status,
                eto.payment_method,
                eto.currency,
                eto.buyer_phone,
                eto.receipt_number,
                eto.status,
                eto.purchased_at,
                eto.updated_at,
                u.full_name AS buyer_name,
                u.email AS buyer_email
             FROM event_ticket_orders eto
             LEFT JOIN users u ON u.user_id = eto.user_id
             WHERE eto.event_id = ?
               AND eto.payment_status = 'paid'
             ORDER BY eto.purchased_at DESC, eto.order_id DESC`,
            [eventId]
        );

        return res.json({
            success: true,
            orders: rows.map((row) => ({
                orderId: row.order_id?.toString() ?? '',
                eventId: row.event_id?.toString() ?? '',
                buyerUserId: row.user_id?.toString() ?? '',
                buyerName: row.buyer_name ?? 'Unknown Buyer',
                buyerEmail: row.buyer_email ?? '',
                quantity: Number(row.quantity ?? 0),
                totalAmount: Number(row.total_amount ?? 0),
                serviceFee: Number(row.service_fee ?? 0),
                paymentId: row.payment_id ?? '',
                paymentStatus: row.payment_status ?? '',
                paymentMethod: row.payment_method ?? '',
                currency: row.currency ?? 'LSL',
                buyerPhone: row.buyer_phone ?? '',
                receiptNumber: row.receipt_number ?? '',
                status: row.status ?? 'confirmed',
                purchasedAt: row.purchased_at,
                updatedAt: row.updated_at,
            })),
        });
    } catch (error) {
        return res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/events/tickets/my', authenticateToken, async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();

        const userId = Number(req.user.user_id || req.user.userId);
        if (!Number.isFinite(userId) || userId <= 0) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        const [rows] = await mysqlPool.execute(
            `SELECT
                eto.order_id,
                eto.event_id,
                eto.user_id,
                eto.quantity,
                eto.total_amount,
                eto.service_fee,
                eto.payment_id,
                eto.payment_status,
                eto.payment_method,
                eto.currency,
                eto.buyer_phone,
                eto.receipt_number,
                eto.status,
                eto.purchased_at,
                eto.updated_at,
                e.title AS event_title,
                e.location AS event_location,
                e.price AS ticket_price,
                e.start_datetime,
                e.end_datetime,
                e.image_url,
                e.category,
                e.vendor_id,
                COALESCE(NULLIF(e.organizer_name, ''), v.business_name) AS organizer,
                v.business_name AS vendor_business_name
             FROM event_ticket_orders eto
             INNER JOIN events e ON e.event_id = eto.event_id
             LEFT JOIN vendors v ON v.user_id = e.vendor_id
             WHERE eto.user_id = ?
               AND eto.payment_status = 'paid'
             ORDER BY eto.purchased_at DESC, eto.order_id DESC`,
            [userId]
        );

        return res.json({
            success: true,
            orders: rows.map((row) => ({
                orderId: row.order_id?.toString() ?? '',
                eventId: row.event_id?.toString() ?? '',
                userId: row.user_id?.toString() ?? '',
                quantity: Number(row.quantity ?? 0),
                totalAmount: Number(row.total_amount ?? 0),
                serviceFee: Number(row.service_fee ?? 0),
                subtotal: Number(
                    (
                        Number(row.total_amount ?? 0) -
                        Number(row.service_fee ?? 0)
                    ).toFixed(2)
                ),
                paymentId: row.payment_id ?? '',
                paymentStatus: row.payment_status ?? '',
                paymentMethod: row.payment_method ?? '',
                currency: row.currency ?? 'LSL',
                buyerPhone: row.buyer_phone ?? '',
                receiptNumber: row.receipt_number ?? '',
                status: row.status ?? 'confirmed',
                purchasedAt: row.purchased_at,
                updatedAt: row.updated_at,
                event: {
                    eventId: row.event_id?.toString() ?? '',
                    title: row.event_title ?? '',
                    location: row.event_location ?? '',
                    price: Number(row.ticket_price ?? 0),
                    startDateTime: row.start_datetime,
                    endDateTime: row.end_datetime,
                    imageUrl: row.image_url ?? '',
                    category: row.category ?? '',
                    vendorId: row.vendor_id?.toString() ?? '',
                    organizer: row.organizer ?? row.vendor_business_name ?? '',
                },
            })),
        });
    } catch (error) {
        return res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/events/:id/tickets/purchase', authenticateToken, async (req, res) => {
    try {
        await ensureEventColumns();
        await ensureEventTicketTables();

        const eventId = Number(req.params.id);
        const userId = Number(req.user.user_id || req.user.userId);
        const quantity = Number.parseInt(req.body?.quantity, 10);
        const paymentId = req.body?.paymentId?.toString().trim();
        const paymentStatus = req.body?.paymentStatus?.toString().trim().toLowerCase();
        const paymentMethod = req.body?.paymentMethod?.toString().trim() || null;
        const totalAmount = Number(req.body?.totalAmount ?? 0);
        const serviceFee = Number(req.body?.serviceFee ?? 0);
        const currency = req.body?.currency?.toString().trim().toUpperCase() || 'LSL';
        const buyerPhone = req.body?.buyerPhone?.toString().trim() || null;

        if (!Number.isFinite(eventId) || eventId <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid event id' });
        }

        if (!Number.isFinite(userId) || userId <= 0) {
            return res.status(401).json({ success: false, message: 'Unauthorized' });
        }

        if (!Number.isFinite(quantity) || quantity <= 0) {
            return res.status(400).json({ success: false, message: 'Quantity must be at least 1' });
        }

        if (quantity > 20) {
            return res.status(400).json({
                success: false,
                message: 'You can only buy up to 20 tickets in one payment.',
            });
        }

        if (!paymentId || paymentStatus !== 'paid') {
            return res.status(400).json({
                success: false,
                message: 'A completed ticket payment is required first.',
            });
        }

        const [existingOrders] = await mysqlPool.execute(
            `SELECT order_id
             FROM event_ticket_orders
             WHERE event_id = ?
               AND payment_id = ?
               AND payment_status = 'paid'
             LIMIT 1`,
            [eventId, paymentId]
        );

        if (existingOrders.length > 0) {
            const refreshedEvent = await loadEventById(eventId);
            return res.status(200).json({
                success: true,
                message: 'Tickets already recorded for this payment.',
                orderId: String(existingOrders[0].order_id),
                event: refreshedEvent,
            });
        }

        const event = await loadEventById(eventId);
        if (!event) {
            return res.status(404).json({ success: false, message: 'Event not found' });
        }

        if (event.status === 'cancelled' || event.status === 'ended') {
            return res.status(400).json({ success: false, message: 'Tickets are not available for this event' });
        }

        if (event.max_capacity == null) {
            return res.status(400).json({
                success: false,
                message: 'This event does not have managed ticket allocation yet.'
            });
        }

        const ticketsRemaining = Number(event.tickets_remaining ?? 0);
        if (quantity > ticketsRemaining) {
            return res.status(400).json({
                success: false,
                message: `Only ${ticketsRemaining} ticket${ticketsRemaining === 1 ? '' : 's'} left.`,
                ticketsRemaining,
            });
        }

        const expectedSubtotal = Number(event.price ?? 0) * quantity;
        const expectedServiceFee = Number((expectedSubtotal * 0.05).toFixed(2));
        const expectedTotal = Number((expectedSubtotal + expectedServiceFee).toFixed(2));

        if (Math.abs(totalAmount - expectedTotal) > 0.01) {
            return res.status(400).json({
                success: false,
                message: 'Ticket payment total does not match the event price.',
            });
        }

        if (Math.abs(serviceFee - expectedServiceFee) > 0.01) {
            return res.status(400).json({
                success: false,
                message: 'Ticket payment service fee is invalid.',
            });
        }

        const receiptNumber = `EVT-${eventId}-${Date.now()}`;
        const [insertResult] = await mysqlPool.execute(
            `INSERT INTO event_ticket_orders (
                event_id, user_id, quantity, total_amount, service_fee,
                payment_id, payment_status, payment_method, currency,
                buyer_phone, receipt_number, status
             )
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed')`,
            [
                eventId,
                userId,
                quantity,
                totalAmount,
                serviceFee,
                paymentId,
                paymentStatus,
                paymentMethod,
                currency,
                buyerPhone,
                receiptNumber
            ]
        );

        const refreshedEvent = await loadEventById(eventId);
        return res.status(201).json({
            success: true,
            message: 'Tickets purchased successfully',
            orderId: String(insertResult.insertId),
            receiptNumber,
            event: refreshedEvent,
        });
    } catch (error) {
        return res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/listings', async (req, res) => {
    try {
        const [rows] = await mysqlPool.execute(`
            SELECT
                l.listing_id,
                l.title,
                l.description,
                l.category,
                l.price,
                l.price_unit,
                l.location,
                l.district,
                l.featured_image,
                l.status,
                l.vendor_id,
                l.created_at,
                v.user_id,
                v.business_name,
                v.business_phone,
                v.business_email,
                v.facebook,
                v.instagram,
                v.whatsapp,
                COALESCE(v.verified, 0) AS verified,
                COUNT(r.review_id) AS review_count,
                AVG(r.rating) AS average_rating
            FROM listings l
            INNER JOIN vendors v ON l.vendor_id = v.vendor_id
            LEFT JOIN reviews r ON r.listing_id = l.listing_id
            WHERE l.status = 'active'
              AND v.verified = 1
            GROUP BY
                l.listing_id, l.title, l.description, l.category, l.price,
                l.price_unit, l.location, l.district, l.status, l.vendor_id,
                l.created_at, l.featured_image, v.user_id, v.business_name,
                v.business_phone, v.business_email, v.facebook,
                v.instagram, v.whatsapp, v.verified
            ORDER BY l.created_at DESC, l.listing_id DESC
        `);

        res.json({
            success: true,
            listings: await enrichListingsWithMedia(rows)
        });
    } catch (error) {
        console.error('❌ Failed to fetch listings:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// GET LISTINGS FOR A VENDOR
// ============================================
router.get('/listings/vendor/:userId', authenticateToken, async (req, res) => {
    try {
        const { userId } = req.params;
        const [rows] = await mysqlPool.execute(`
            SELECT
                l.listing_id,
                l.title,
                l.description,
                l.category,
                l.price,
                l.price_unit,
                l.location,
                l.district,
                l.featured_image,
                l.status,
                l.vendor_id,
                l.created_at,
                v.user_id,
                v.business_name,
                v.business_phone,
                v.business_email,
                v.facebook,
                v.instagram,
                v.whatsapp
            FROM listings l
            INNER JOIN vendors v ON l.vendor_id = v.vendor_id
            WHERE v.user_id = ?
            ORDER BY l.created_at DESC, l.listing_id DESC
        `, [userId]);

        res.json({
            success: true,
            listings: await enrichListingsWithMedia(rows)
        });
    } catch (error) {
        console.error('❌ Failed to fetch vendor listings:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// UPDATE VENDOR SOCIAL LINKS
// ============================================
router.patch('/vendors/social-links', authenticateToken, async (req, res) => {
    try {
        const {
            business_phone,
            business_email,
            facebook,
            instagram,
            whatsapp
        } = req.body ?? {};

        const userId = req.user.userId ?? req.user.user_id;
        if (!userId) {
            return res.status(401).json({
                success: false,
                message: 'Unauthorized'
            });
        }

        const normalize = (value) => {
            if (typeof value !== 'string') return null;
            const trimmed = value.trim();
            return trimmed.length === 0 ? null : trimmed;
        };

        await mysqlPool.execute(
            `UPDATE vendors
             SET business_phone = ?,
                 business_email = ?,
                 facebook = ?,
                 instagram = ?,
                 whatsapp = ?
             WHERE user_id = ?`,
            [
                normalize(business_phone),
                normalize(business_email),
                normalize(facebook),
                normalize(instagram),
                normalize(whatsapp),
                userId
            ]
        );

        const [vendors] = await mysqlPool.execute(
            `SELECT user_id, business_name, business_phone, business_email, facebook, instagram, whatsapp
             FROM vendors
             WHERE user_id = ?
             LIMIT 1`,
            [userId]
        );

        if (vendors.length == 0) {
            return res.status(404).json({
                success: false,
                message: 'Vendor profile not found'
            });
        }

        res.json({
            success: true,
            message: 'Social links updated successfully',
            vendor: vendors[0]
        });
    } catch (error) {
        console.error('❌ Failed to update vendor social links:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// CREATE LISTING
// ============================================
router.post('/listings', authenticateToken, async (req, res) => {
    try {
        const {
            title,
            description,
            category,
            price,
            priceUnit,
            location,
            district,
            images,
            additionalDetails
        } = req.body;

        if (!title || !description || !category || price == null || !location) {
            return res.status(400).json({
                success: false,
                message: 'Missing required listing fields'
            });
        }

        const vendor = await getVendorForActor(req.user);
        if (!vendor) {
            return res.status(403).json({
                success: false,
                message: 'Vendor profile not found'
            });
        }

        if (!(vendor.verified === 1 || vendor.verified === true)) {
            return res.status(403).json({
                success: false,
                message: 'Vendor must be approved before adding listings'
            });
        }

        const normalizedImages = normalizeImagesPayload(images);
        
        // Store only HTTP URLs in featured_image, not base64 (too large for MySQL)
        const featuredImageForDb = normalizedImages[0]?.startsWith('http')
            ? normalizedImages[0]
            : null;
        const normalizedPriceUnit = normalizePriceUnitForDb(priceUnit);

        const [result] = await mysqlPool.execute(`
            INSERT INTO listings (
                vendor_id, title, description, category, price, price_unit, location, district, featured_image, status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
        `, [
            vendor.vendor_id,
            title,
            description,
            normalizeCategoryForDb(category),
            price,
            normalizedPriceUnit,
            location,
            district || null,
            featuredImageForDb
        ]);

        await saveListingMedia(result.insertId, normalizedImages, additionalDetails);
        await syncCultureDirectoryFromListing({
            category,
            title,
            description,
            location,
            additionalDetails,
            vendor
        });

        const createdListing = mapListingRow({
            listing_id: result.insertId,
            title,
            description,
            category: normalizeCategoryForDb(category),
            price,
            price_unit: normalizedPriceUnit,
            location,
            district,
            status: 'active',
            vendor_id: vendor.vendor_id,
            user_id: vendor.user_id,
            business_name: vendor.business_name,
            business_phone: vendor.business_phone,
            business_email: vendor.business_email,
            facebook: vendor.facebook,
            instagram: vendor.instagram,
            whatsapp: vendor.whatsapp,
            review_count: 0,
            average_rating: null,
            featured_image: normalizedImages[0] ?? null,
            images: normalizedImages,
            additional_details: additionalDetails
        });

        res.status(201).json({
            success: true,
            listing: createdListing
        });
    } catch (error) {
        console.error('❌ Failed to create listing:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// UPDATE LISTING
// ============================================
router.put('/listings/:id', authenticateToken, async (req, res) => {
    try {
        const listingId = req.params.id;
        const {
            title,
            description,
            category,
            price,
            priceUnit,
            location,
            district,
            images,
            additionalDetails
        } = req.body;

        const vendor = await getVendorForActor(req.user);
        if (!vendor) {
            return res.status(403).json({ success: false, message: 'Vendor profile not found' });
        }

        const normalizedImages = normalizeImagesPayload(images);
        
        // Store only HTTP URLs in featured_image, not base64 (too large for MySQL)
        const featuredImageForDb = normalizedImages[0]?.startsWith('http')
            ? normalizedImages[0]
            : null;
        const normalizedPriceUnit = normalizePriceUnitForDb(priceUnit);

        await mysqlPool.execute(`
            UPDATE listings
            SET title = ?, description = ?, category = ?, price = ?, price_unit = ?, location = ?, district = ?, featured_image = ?
            WHERE listing_id = ? AND vendor_id = ?
        `, [
            title,
            description,
            normalizeCategoryForDb(category),
            price,
            normalizedPriceUnit,
            location,
            district || null,
            featuredImageForDb,
            listingId,
            vendor.vendor_id
        ]);

        await saveListingMedia(listingId, normalizedImages, additionalDetails);
        await syncCultureDirectoryFromListing({
            category,
            title,
            description,
            location,
            additionalDetails,
            vendor
        });

        res.json({
            success: true,
            listing: mapListingRow({
                listing_id: listingId,
                title,
                description,
                category: normalizeCategoryForDb(category),
                price,
                price_unit: normalizedPriceUnit,
                location,
                district,
                status: 'active',
                vendor_id: vendor.vendor_id,
                user_id: vendor.user_id,
                business_name: vendor.business_name,
                business_phone: vendor.business_phone,
                business_email: vendor.business_email,
                facebook: vendor.facebook,
                instagram: vendor.instagram,
                whatsapp: vendor.whatsapp,
                review_count: 0,
                average_rating: null,
                featured_image: normalizedImages[0] ?? null,
                images: normalizedImages,
                additional_details: additionalDetails
            })
        });
    } catch (error) {
        console.error('❌ Failed to update listing:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// DELETE LISTING
// ============================================
router.delete('/listings/:id', authenticateToken, async (req, res) => {
    try {
        const listingId = req.params.id;
        const actorId = resolveActorId(req.user);
        const vendor = await getVendorForActor(req.user);
        if (!vendor) {
            return res.status(403).json({
                success: false,
                message: 'Vendor profile not found for this account'
            });
        }

        const [ownerRows] = await mysqlPool.execute(
            `
            SELECT l.vendor_id, v.user_id
            FROM listings l
            LEFT JOIN vendors v ON v.vendor_id = l.vendor_id
            WHERE l.listing_id = ?
            LIMIT 1
            `,
            [listingId]
        );

        if (!ownerRows.length) {
            return res.status(404).json({
                success: false,
                message: 'Listing not found'
            });
        }

        const ownerVendorId = Number(ownerRows[0].vendor_id);
        const ownerUserId = Number(ownerRows[0].user_id);
        const actorIdNum = Number(actorId);
        const canDeleteByVendor = ownerVendorId === Number(vendor.vendor_id);
        const canDeleteByUser = Number.isFinite(actorIdNum) && ownerUserId === actorIdNum;

        if (!canDeleteByVendor && !canDeleteByUser) {
            return res.status(403).json({
                success: false,
                message: 'You can only delete your own listing'
            });
        }

        await mysqlPool.execute(
            'DELETE FROM listings WHERE listing_id = ?',
            [listingId]
        );

        const collection = getListingMediaCollection();
        if (collection) {
            await collection.deleteOne({ listing_id: Number(listingId) });
        }

        res.json({ success: true, message: 'Listing deleted' });
    } catch (error) {
        console.error('❌ Failed to delete listing:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// GET COMPLETE LISTING - FIXED FOR YOUR DATA
// ============================================
router.get('/listings/:id/complete', async (req, res) => {
    try {
        const db = getMongoDb();
        const listingId = parseInt(req.params.id);
        
        console.log('🔍 Fetching listing ID:', listingId);

        // 1. SIMPLE QUERY FIRST - Get listing without joins
        const [listing] = await mysqlPool.execute(
            'SELECT * FROM listings WHERE listing_id = ?',
            [listingId]
        );
        
        if (!listing || listing.length === 0) {
            return res.status(404).json({ 
                error: 'Listing not found',
                message: `No listing with ID ${listingId} exists`
            });
        }

        // 2. Get vendor info separately
        let vendor = { business_name: 'Unknown', verified: false };
        if (listing[0].vendor_id) {
            try {
                const [vendorData] = await mysqlPool.execute(
                    `SELECT v.*, u.email, u.full_name 
                     FROM vendors v 
                     LEFT JOIN users u ON v.user_id = u.user_id 
                     WHERE v.vendor_id = ?`,
                    [listing[0].vendor_id]
                );
                if (vendorData.length > 0) {
                    vendor = vendorData[0];
                }
            } catch (vendorError) {
                console.log('⚠️ Vendor query failed:', vendorError.message);
            }
        }

        // 3. Get reviews
        let reviews = [];
        try {
            const [reviewRows] = await mysqlPool.execute(
                `SELECT r.*, u.full_name as tourist_name 
                 FROM reviews r 
                 LEFT JOIN users u ON r.tourist_id = u.user_id 
                 WHERE r.listing_id = ? 
                 ORDER BY r.created_at DESC`,
                [listingId]
            );
            reviews = reviewRows || [];
        } catch (reviewError) {
            console.log('⚠️ Reviews query failed:', reviewError.message);
        }

        const listingMediaCollection = getListingMediaCollection();
        let listingImages = [];
        if (listingMediaCollection) {
            const media = await listingMediaCollection.findOne({ listing_id: Number(listingId) });
            listingImages = Array.isArray(media?.images) ? media.images : [];
        }

        // 4. Get photos from MongoDB
        const reviewsWithPhotos = await Promise.all(reviews.map(async (review) => {
            try {
                if (!db) {
                    return { ...review, photos: [] };
                }
                const media = await db.collection('reviews_media')
                    .findOne({ review_id: review.review_id });
                return {
                    ...review,
                    photos: media?.images || []
                };
            } catch (mongoError) {
                return { ...review, photos: [] };
            }
        }));

        // 5. Get availability
        let availability = [];
        try {
            const [availRows] = await mysqlPool.execute(
                `SELECT available_date, status, price_override 
                 FROM availability 
                 WHERE listing_id = ? 
                 AND available_date >= CURDATE() 
                 ORDER BY available_date 
                 LIMIT 30`,
                [listingId]
            );
            availability = availRows || [];
        } catch (availError) {
            console.log('⚠️ Availability query failed:', availError.message);
        }

        // 6. Get view count from MongoDB
        let views = 0;
        try {
            if (!db) {
                throw new Error('MongoDB not connected');
            }
            const [viewStats] = await db.collection('listing_views')
                .aggregate([
                    { $match: { listingId: listingId } },
                    { $group: { _id: null, count: { $sum: 1 } } }
                ]).toArray();
            views = viewStats?.count || 0;
        } catch (mongoError) {
            console.log('⚠️ MongoDB view count error:', mongoError.message);
        }

        // 7. Send response
        res.json({
            success: true,
            listing: {
                ...listing[0],
                images: listingImages,
                imageUrl: listingImages[0] ?? listing[0].featured_image ?? null,
                business_name: vendor.business_name,
                vendor_verified: vendor.verified || false,
                vendor_email: vendor.business_email || vendor.email || '',
                business_phone: vendor.business_phone || '',
                facebook: vendor.facebook || '',
                instagram: vendor.instagram || '',
                whatsapp: vendor.whatsapp || '',
                average_rating: reviews.length > 0 
                    ? (reviews.reduce((acc, r) => acc + (r.rating || 0), 0) / reviews.length).toFixed(1)
                    : 0,
                total_reviews: reviews.length,
                total_views: views
            },
            reviews: reviewsWithPhotos,
            availability: availability.map(a => ({
                date: a.available_date,
                status: a.status || 'available',
                price: a.price_override || listing[0].price
            }))
        });

    } catch (error) {
        console.error('❌ Server error:', error);
        res.status(500).json({ 
            error: 'Internal server error',
            message: error.message 
        });
    }
});

// ============================================
// TEST ENDPOINT - Check MySQL connection
// ============================================
router.get('/test/mysql', async (req, res) => {
    try {
        // Test basic query
        const [result] = await mysqlPool.execute('SELECT 1+1 as test');
        
        // Get listing count
        const [listingCount] = await mysqlPool.execute('SELECT COUNT(*) as count FROM listings');
        
        // Get sample listings
        const [listings] = await mysqlPool.execute(
            'SELECT listing_id, title, category, price FROM listings LIMIT 5'
        );
        
        res.json({
            success: true,
            connection: '✅ MySQL connected',
            test_query: result[0].test,
            listing_count: listingCount[0].count,
            sample_listings: listings,
            database: 'explore_lesotho'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            connection: '❌ MySQL error',
            error: error.message
        });
    }
});

// ============================================
// REVIEWS - REAL DATA ONLY
// ============================================
router.get('/reviews/listing/:listingId', async (req, res) => {
    try {
        const db = getMongoDb();
        const listingId = req.params.listingId.toString();
        const numericListingId = Number(listingId);
        const reviews = await db.collection('reviews')
            .find({
                $and: [
                    {
                        $or: Number.isFinite(numericListingId)
                            ? [{ listingId }, { listingId: numericListingId }, { listing_id: numericListingId }, { listing_id: listingId }]
                            : [{ listingId }, { listing_id: listingId }]
                    },
                    {
                        $or: [
                            { status: 'approved' },
                            { status: { $exists: false } }
                        ]
                    }
                ]
            })
            .sort({ createdAt: -1, updatedAt: -1 })
            .toArray();

        res.json({
            success: true,
            reviews: reviews.map((review) => ({
                id: review._id.toString(),
                listingId: review.listingId,
                listingTitle: review.listingTitle,
                bookingId: review.bookingId,
                userId: review.userId,
                userName: review.userName,
                userAvatar: review.userAvatar,
                rating: Number(review.rating ?? 0),
                comment: review.comment ?? '',
                images: Array.isArray(review.images) ? review.images : [],
                createdAt: review.createdAt ?? new Date(),
                updatedAt: review.updatedAt,
                vendorReply: review.vendorReply,
                vendorReplyAt: review.vendorReplyAt,
                isVerifiedPurchase: review.isVerifiedPurchase !== false,
                helpfulCount: Number(review.helpfulCount ?? 0),
                reportedBy: Array.isArray(review.reportedBy) ? review.reportedBy : [],
                status: review.status ?? 'approved',
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/reviews/vendor', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();
        if (!db) {
            return res.status(500).json({ success: false, error: 'MongoDB not available' });
        }

        const actorId = resolveActorId(req.user);
        const vendor = await getVendorForActor(req.user);
        if (actorId == null && !vendor) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const [listingRows] = await mysqlPool.execute(
            `SELECT l.listing_id, l.title
             FROM listings l
             INNER JOIN vendors v ON v.vendor_id = l.vendor_id
             WHERE v.user_id = ? OR v.vendor_id = ? OR v.vendor_id = ? OR v.user_id = ?`,
            [actorId, actorId, vendor?.vendor_id ?? actorId, vendor?.user_id ?? actorId]
        );

        if (!listingRows.length) {
            return res.json({ success: true, reviews: [] });
        }

        const listingIds = listingRows
            .map((row) => row.listing_id?.toString())
            .filter(Boolean);
        const listingTitleMap = new Map(
            listingRows.map((row) => [row.listing_id?.toString(), row.title ?? 'Unknown Listing'])
        );

        const reviews = await db
            .collection('reviews')
            .find({ listingId: { $in: listingIds } })
            .sort({ createdAt: -1, updatedAt: -1 })
            .toArray();

        res.json({
            success: true,
            reviews: reviews.map((review) => ({
                id: review._id.toString(),
                listingId: review.listingId,
                listingTitle:
                    review.listingTitle ??
                    listingTitleMap.get(review.listingId?.toString()) ??
                    'Unknown Listing',
                bookingId: review.bookingId,
                userId: review.userId,
                userName: review.userName,
                userAvatar: review.userAvatar,
                rating: Number(review.rating ?? 0),
                comment: review.comment ?? '',
                images: Array.isArray(review.images) ? review.images : [],
                createdAt: review.createdAt ?? new Date(),
                updatedAt: review.updatedAt,
                vendorReply: review.vendorReply,
                vendorReplyAt: review.vendorReplyAt,
                isVerifiedPurchase: review.isVerifiedPurchase !== false,
                helpfulCount: Number(review.helpfulCount ?? 0),
                reportedBy: Array.isArray(review.reportedBy) ? review.reportedBy : [],
                status: review.status ?? 'pending',
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.post('/reviews', authenticateToken, async (req, res) => {
    try {
        const { listingId, listingTitle, bookingId, rating, comment, images } = req.body;
        const actorId = resolveActorId(req.user);
        const currentUserId = actorId != null ? String(actorId) : null;

        if (!currentUserId) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        if (!listingId || !bookingId || rating == null || !comment?.toString().trim()) {
            return res.status(400).json({ success: false, error: 'Missing required review fields' });
        }

        const [bookings] = await mysqlPool.execute(
            `SELECT b.booking_id, b.listing_id, b.status, b.check_out, u.full_name
             FROM bookings b
             INNER JOIN users u ON u.user_id = b.tourist_id
             WHERE b.booking_id = ? AND b.tourist_id = ? AND b.listing_id = ?`,
            [bookingId, currentUserId, listingId]
        );

        if (bookings.length === 0) {
            return res.status(403).json({ success: false, error: 'Booking not found for this user' });
        }

        const booking = bookings[0];
        const checkOutDate = booking.check_out ? new Date(booking.check_out) : null;
        const canReviewPastConfirmedBooking =
            booking.status === 'confirmed' &&
            checkOutDate instanceof Date &&
            !Number.isNaN(checkOutDate.getTime()) &&
            checkOutDate < new Date();

        if (booking.status !== 'completed' && !canReviewPastConfirmedBooking) {
            return res.status(400).json({ success: false, error: 'Only completed bookings can be reviewed' });
        }

        const db = getMongoDb();
        const existingReview = await db.collection('reviews').findOne({
            bookingId: bookingId.toString(),
            userId: currentUserId,
        });

        if (existingReview) {
            return res.status(400).json({ success: false, error: 'You have already reviewed this booking' });
        }

        const now = new Date();
        const reviewDoc = {
            listingId: listingId.toString(),
            listingTitle: listingTitle?.toString() ?? '',
            bookingId: bookingId.toString(),
            userId: currentUserId,
            userName: booking.full_name ?? 'Anonymous',
            rating: Number(rating),
            comment: comment.toString().trim(),
            images: Array.isArray(images) ? images : [],
            createdAt: now,
            updatedAt: now,
            isVerifiedPurchase: true,
            helpfulCount: 0,
            reportedBy: [],
            status: 'approved',
        };

        const result = await db.collection('reviews').insertOne(reviewDoc);

        res.status(201).json({
            success: true,
            review: {
                ...reviewDoc,
                id: result.insertedId.toString(),
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/reviews/:id/helpful', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();
        const reviewId = req.params.id;
        const actorId = resolveActorId(req.user);
        const currentUserId = actorId != null ? String(actorId) : null;
        if (!currentUserId) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }
        const objectId = new ObjectId(reviewId);

        const review = await db.collection('reviews').findOne({ _id: objectId });
        if (!review) {
            return res.status(404).json({ success: false, error: 'Review not found' });
        }

        const helpfulBy = Array.isArray(review.helpfulBy) ? review.helpfulBy : [];
        if (helpfulBy.includes(currentUserId)) {
            return res.json({ success: true, helpfulCount: Number(review.helpfulCount ?? 0) });
        }

        const helpfulCount = Number(review.helpfulCount ?? 0) + 1;
        await db.collection('reviews').updateOne(
            { _id: objectId },
            {
                $set: { helpfulCount, updatedAt: new Date() },
                $addToSet: { helpfulBy: currentUserId },
            }
        );

        res.json({ success: true, helpfulCount });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/reviews/:id/reply', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();
        const reviewId = req.params.id;
        const actorId = resolveActorId(req.user);
        const currentUserId = actorId != null ? String(actorId) : null;
        if (!currentUserId) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }
        const reply = req.body.reply?.toString().trim();

        if (!reply) {
            return res.status(400).json({ success: false, error: 'Reply is required' });
        }

        const objectId = new ObjectId(reviewId);
        const review = await db.collection('reviews').findOne({ _id: objectId });

        if (!review) {
            return res.status(404).json({ success: false, error: 'Review not found' });
        }

        const [vendors] = await mysqlPool.execute(
            `SELECT v.vendor_id
             FROM vendors v
             INNER JOIN listings l ON l.vendor_id = v.vendor_id
             WHERE v.user_id = ? AND l.listing_id = ?
             LIMIT 1`,
            [currentUserId, review.listingId]
        );

        if (vendors.length === 0) {
            return res.status(403).json({ success: false, error: 'You cannot reply to this review' });
        }

        const now = new Date();
        await db.collection('reviews').updateOne(
            { _id: objectId },
            {
                $set: {
                    vendorReply: reply,
                    vendorReplyAt: now,
                    updatedAt: now,
                },
            }
        );

        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.delete('/reviews/:id', authenticateToken, async (req, res) => {
    try {
        const db = getMongoDb();
        const reviewId = req.params.id;
        const actorId = resolveActorId(req.user);
        const currentUserId = actorId != null ? String(actorId) : null;
        if (!currentUserId && req.user.role !== 'admin') {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }
        const objectId = new ObjectId(reviewId);

        const review = await db.collection('reviews').findOne({ _id: objectId });
        if (!review) {
            return res.status(404).json({ success: false, error: 'Review not found' });
        }

        if (req.user.role !== 'admin') {
            const [vendors] = await mysqlPool.execute(
                `SELECT v.vendor_id
                 FROM vendors v
                 INNER JOIN listings l ON l.vendor_id = v.vendor_id
                 WHERE v.user_id = ? AND l.listing_id = ?
                 LIMIT 1`,
                [currentUserId, review.listingId]
            );

            if (vendors.length === 0) {
                return res.status(403).json({ success: false, error: 'You cannot delete this review' });
            }
        }

        await db.collection('reviews').deleteOne({ _id: objectId });
        res.json({ success: true, message: 'Review deleted' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// ============================================
// CULTURE DIRECTORY (MTICC)
// ============================================
router.get('/culture/subcategories', async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const [rows] = await mysqlPool.execute(`
            SELECT
                cs.subcategory_id,
                cs.name,
                cs.slug,
                cs.icon,
                cs.color,
                cs.sort_order,
                COUNT(DISTINCT CASE WHEN cv.status = 'active' THEN cv.vendor_id END) AS vendor_count
            FROM culture_subcategories cs
            LEFT JOIN culture_vendor_subcategories cvs
                ON cvs.subcategory_id = cs.subcategory_id
            LEFT JOIN culture_vendors cv
                ON cv.vendor_id = cvs.vendor_id
            GROUP BY
                cs.subcategory_id, cs.name, cs.slug, cs.icon, cs.color, cs.sort_order
            ORDER BY cs.sort_order ASC, cs.name ASC
        `);

        res.json({
            success: true,
            subcategories: rows.map((row) => ({
                id: row.subcategory_id?.toString(),
                name: row.name,
                slug: row.slug,
                icon: row.icon,
                color: row.color,
                vendorCount: Number(row.vendor_count ?? 0),
            })),
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/culture/vendors', async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const subcategory = req.query.subcategory?.toString().trim() || '';
        const search = req.query.search?.toString().trim().toLowerCase() || '';
        const params = [];
        let where = `WHERE cv.status = 'active'`;

        if (subcategory) {
            where += ` AND cs.slug = ?`;
            params.push(subcategory);
        }

        if (search) {
            where += ` AND (
                LOWER(cv.name) LIKE ?
                OR LOWER(COALESCE(cv.product_range, '')) LIKE ?
            )`;
            const pattern = `%${search}%`;
            params.push(pattern, pattern);
        }

        const [rows] = await mysqlPool.execute(
            `
            SELECT
                cv.vendor_id,
                cv.name,
                cv.product_range,
                cv.contacts_json,
                cv.location,
                cv.source_document,
                cv.linked_vendor_id,
                cv.linked_vendor_user_id,
                cv.claimed_at,
                GROUP_CONCAT(DISTINCT cs.name ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_names,
                GROUP_CONCAT(DISTINCT cs.slug ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_slugs,
                MAX(l.listing_id) AS linked_listing_id
            FROM culture_vendors cv
            LEFT JOIN culture_vendor_subcategories cvs ON cvs.vendor_id = cv.vendor_id
            LEFT JOIN culture_subcategories cs ON cs.subcategory_id = cvs.subcategory_id
            LEFT JOIN vendors v
                ON v.vendor_id = cv.linked_vendor_id
                OR (
                    cv.linked_vendor_id IS NULL
                    AND LOWER(TRIM(v.business_name)) = LOWER(TRIM(cv.name))
                )
            LEFT JOIN listings l
                ON l.vendor_id = v.vendor_id
               AND l.status = 'active'
               AND l.category = 'cultural'
            ${where}
            GROUP BY
                cv.vendor_id, cv.name, cv.product_range, cv.contacts_json, cv.location, cv.source_document,
                cv.linked_vendor_id, cv.linked_vendor_user_id, cv.claimed_at
            ORDER BY cv.name ASC
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
                location: row.location ?? '',
                contacts,
                subcategories: row.subcategory_names
                    ? row.subcategory_names.toString().split('|').filter(Boolean)
                    : [],
                subcategorySlugs: row.subcategory_slugs
                    ? row.subcategory_slugs.toString().split('|').filter(Boolean)
                    : [],
                linkedListingId: row.linked_listing_id?.toString() ?? null,
                linkedVendorId: row.linked_vendor_id?.toString() ?? null,
                linkedVendorUserId: row.linked_vendor_user_id?.toString() ?? null,
                claimedAt: row.claimed_at ?? null,
                isClaimed: row.linked_vendor_id != null,
                sourceDocument: row.source_document ?? null,
            };
        });

        res.json({ success: true, vendors });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/culture/vendors/:id', async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const vendorId = req.params.id;
        const [rows] = await mysqlPool.execute(
            `
            SELECT
                cv.vendor_id,
                cv.name,
                cv.product_range,
                cv.contacts_json,
                cv.location,
                cv.source_document,
                cv.linked_vendor_id,
                cv.linked_vendor_user_id,
                cv.claimed_at,
                GROUP_CONCAT(DISTINCT cs.name ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_names,
                GROUP_CONCAT(DISTINCT cs.slug ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_slugs,
                MAX(l.listing_id) AS linked_listing_id
            FROM culture_vendors cv
            LEFT JOIN culture_vendor_subcategories cvs ON cvs.vendor_id = cv.vendor_id
            LEFT JOIN culture_subcategories cs ON cs.subcategory_id = cvs.subcategory_id
            LEFT JOIN vendors v
                ON v.vendor_id = cv.linked_vendor_id
                OR (
                    cv.linked_vendor_id IS NULL
                    AND LOWER(TRIM(v.business_name)) = LOWER(TRIM(cv.name))
                )
            LEFT JOIN listings l
                ON l.vendor_id = v.vendor_id
               AND l.status = 'active'
               AND l.category = 'cultural'
            WHERE cv.vendor_id = ?
            GROUP BY
                cv.vendor_id, cv.name, cv.product_range, cv.contacts_json, cv.location, cv.source_document,
                cv.linked_vendor_id, cv.linked_vendor_user_id, cv.claimed_at
            LIMIT 1
            `,
            [vendorId]
        );

        if (!rows.length) {
            return res.status(404).json({ success: false, error: 'Culture vendor not found' });
        }

        const row = rows[0];
        let contacts = [];
        try {
            contacts = row.contacts_json ? JSON.parse(row.contacts_json) : [];
        } catch {
            contacts = [];
        }

        res.json({
            success: true,
            vendor: {
                id: row.vendor_id?.toString(),
                name: row.name ?? '',
                productRange: row.product_range ?? '',
                location: row.location ?? '',
                contacts,
                subcategories: row.subcategory_names
                    ? row.subcategory_names.toString().split('|').filter(Boolean)
                    : [],
                subcategorySlugs: row.subcategory_slugs
                    ? row.subcategory_slugs.toString().split('|').filter(Boolean)
                    : [],
                linkedListingId: row.linked_listing_id?.toString() ?? null,
                linkedVendorId: row.linked_vendor_id?.toString() ?? null,
                linkedVendorUserId: row.linked_vendor_user_id?.toString() ?? null,
                claimedAt: row.claimed_at ?? null,
                isClaimed: row.linked_vendor_id != null,
                sourceDocument: row.source_document ?? null,
            },
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

router.get('/culture/vendors/claimed/me', authenticateToken, async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const actorId = resolveActorId(req.user);
        if (actorId == null) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const [rows] = await mysqlPool.execute(
            `
            SELECT
                cv.vendor_id,
                cv.name,
                cv.product_range,
                cv.contacts_json,
                cv.location,
                cv.source_document,
                cv.linked_vendor_id,
                cv.linked_vendor_user_id,
                cv.claimed_at,
                GROUP_CONCAT(DISTINCT cs.name ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_names,
                GROUP_CONCAT(DISTINCT cs.slug ORDER BY cs.sort_order ASC SEPARATOR '|') AS subcategory_slugs,
                MAX(l.listing_id) AS linked_listing_id
            FROM culture_vendors cv
            LEFT JOIN culture_vendor_subcategories cvs ON cvs.vendor_id = cv.vendor_id
            LEFT JOIN culture_subcategories cs ON cs.subcategory_id = cvs.subcategory_id
            LEFT JOIN listings l
                ON l.vendor_id = cv.linked_vendor_id
               AND l.status = 'active'
               AND l.category = 'cultural'
            WHERE cv.linked_vendor_user_id = ? OR cv.linked_vendor_id = ?
            GROUP BY
                cv.vendor_id, cv.name, cv.product_range, cv.contacts_json, cv.location,
                cv.source_document, cv.linked_vendor_id, cv.linked_vendor_user_id, cv.claimed_at
            ORDER BY cv.vendor_id DESC
            LIMIT 1
            `,
            [actorId, actorId]
        );

        if (!rows.length) {
            return res.json({ success: true, vendor: null });
        }

        const row = rows[0];
        let contacts = [];
        try {
            contacts = row.contacts_json ? JSON.parse(row.contacts_json) : [];
        } catch {
            contacts = [];
        }

        return res.json({
            success: true,
            vendor: {
                id: row.vendor_id?.toString(),
                name: row.name ?? '',
                productRange: row.product_range ?? '',
                location: row.location ?? '',
                contacts,
                subcategories: row.subcategory_names
                    ? row.subcategory_names.toString().split('|').filter(Boolean)
                    : [],
                subcategorySlugs: row.subcategory_slugs
                    ? row.subcategory_slugs.toString().split('|').filter(Boolean)
                    : [],
                linkedListingId: row.linked_listing_id?.toString() ?? null,
                linkedVendorId: row.linked_vendor_id?.toString() ?? null,
                linkedVendorUserId: row.linked_vendor_user_id?.toString() ?? null,
                claimedAt: row.claimed_at ?? null,
                isClaimed: row.linked_vendor_id != null,
                sourceDocument: row.source_document ?? null,
            },
        });
    } catch (error) {
        return res.status(500).json({ success: false, error: error.message });
    }
});

router.patch('/culture/vendors/claimed/me', authenticateToken, async (req, res) => {
    try {
        await ensureCultureDirectoryTables();
        const actorId = resolveActorId(req.user);
        if (actorId == null) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const [matches] = await mysqlPool.execute(
            `SELECT vendor_id FROM culture_vendors
             WHERE linked_vendor_user_id = ? OR linked_vendor_id = ?
             ORDER BY vendor_id DESC
             LIMIT 1`,
            [actorId, actorId]
        );

        if (!matches.length) {
            return res.status(404).json({
                success: false,
                message: 'No claimed culture profile found for this vendor.'
            });
        }

        const {
            name,
            productRange,
            location,
            contacts,
            subcategorySlugs
        } = req.body ?? {};

        let normalizedContacts = [];
        if (Array.isArray(contacts)) {
            normalizedContacts = contacts
                .map((item) => item?.toString().trim())
                .filter(Boolean);
        } else if (typeof contacts === 'string') {
            normalizedContacts = contacts
                .split(/[,\n]/)
                .map((item) => item.trim())
                .filter(Boolean);
        }

        const cultureVendorId = matches[0].vendor_id;
        await mysqlPool.execute(
            `
            UPDATE culture_vendors
            SET name = ?,
                product_range = ?,
                location = ?,
                contacts_json = ?,
                updated_at = NOW()
            WHERE vendor_id = ?
            `,
            [
                name?.toString().trim() || '',
                productRange?.toString().trim() || null,
                location?.toString().trim() || null,
                JSON.stringify(normalizedContacts),
                cultureVendorId
            ]
        );

        if (Array.isArray(subcategorySlugs)) {
            await mysqlPool.execute(
                'DELETE FROM culture_vendor_subcategories WHERE vendor_id = ?',
                [cultureVendorId]
            );

            for (const slug of subcategorySlugs) {
                const [subRows] = await mysqlPool.execute(
                    'SELECT subcategory_id FROM culture_subcategories WHERE slug = ? LIMIT 1',
                    [slug]
                );
                if (!subRows.length) continue;
                await mysqlPool.execute(
                    `INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
                     VALUES (?, ?)`,
                    [cultureVendorId, subRows[0].subcategory_id]
                );
            }
        }

        return res.json({ success: true, message: 'Claimed culture profile updated.' });
    } catch (error) {
        return res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
