/* eslint-disable no-console */
require('dotenv').config();
const { mysqlPool, connectMongo } = require('../config/databases');

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
    const rawType = (additionalDetails?.cultureType ?? '')
        .toString()
        .replace(/[[\]"]/g, '')
        .trim();
    const rawFocus = (additionalDetails?.heritageFocus ?? '')
        .toString()
        .replace(/[[\]"]/g, '')
        .trim();

    const direct = normalizeCultureSubtypeSlug(rawType) ||
        normalizeCultureSubtypeSlug(rawFocus.split(',')[0]);
    if (direct) return direct;

    const text = `${title ?? ''} ${description ?? ''}`.toLowerCase();
    if (text.includes('festival')) return 'festival';
    if (text.includes('music')) return 'music';
    if (text.includes('dance')) return 'dance';
    if (text.includes('art')) return 'art';
    if (text.includes('craft')) return 'crafts';
    return 'crafts';
};

async function ensureTables() {
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
}

async function main() {
    let mongo = null;
    try {
        await ensureTables();
        mongo = await connectMongo();

        const [rows] = await mysqlPool.execute(`
            SELECT
                l.listing_id,
                l.title,
                l.description,
                l.location,
                v.business_name,
                v.business_phone,
                v.business_email,
                v.whatsapp
            FROM listings l
            INNER JOIN vendors v ON v.vendor_id = l.vendor_id
            WHERE l.status = 'active'
              AND l.category = 'cultural'
        `);

        if (!rows.length) {
            console.log('No active cultural listings found.');
            return;
        }

        const mediaCollection = mongo.collection('listing_media');
        let synced = 0;

        for (const row of rows) {
            const media = await mediaCollection.findOne({ listing_id: Number(row.listing_id) });
            const additionalDetails = media?.additionalDetails || {};
            const subtypeSlug = inferCultureSubtypeSlug(
                additionalDetails,
                row.title,
                row.description
            );

            const contacts = [
                row.business_phone,
                row.whatsapp,
                row.business_email
            ]
                .map((v) => v?.toString().trim())
                .filter((v) => v);

            const [vendorResult] = await mysqlPool.execute(
                `
                INSERT INTO culture_vendors (name, product_range, contacts_json, location, source_document, status)
                VALUES (?, ?, ?, ?, 'listing-backfill', 'active')
                ON DUPLICATE KEY UPDATE
                    product_range = VALUES(product_range),
                    contacts_json = VALUES(contacts_json),
                    status = 'active',
                    vendor_id = LAST_INSERT_ID(vendor_id)
                `,
                [
                    row.business_name,
                    row.description || row.title || '',
                    JSON.stringify(contacts),
                    row.location || null
                ]
            );

            const cultureVendorId = Number(vendorResult.insertId);
            const [subcategoryRows] = await mysqlPool.execute(
                'SELECT subcategory_id FROM culture_subcategories WHERE slug = ? LIMIT 1',
                [subtypeSlug]
            );

            if (subcategoryRows.length) {
                await mysqlPool.execute(
                    `
                    INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
                    VALUES (?, ?)
                    `,
                    [cultureVendorId, subcategoryRows[0].subcategory_id]
                );
                synced += 1;
            }
        }

        console.log(`Backfill complete. Synced listing links: ${synced}`);
    } catch (error) {
        console.error('Backfill failed:', error.message);
        process.exitCode = 1;
    } finally {
        await mysqlPool.end();
    }
}

main();
