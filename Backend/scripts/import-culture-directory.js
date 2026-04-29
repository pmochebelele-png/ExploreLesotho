/* eslint-disable no-console */
require('dotenv').config();
const path = require('path');
const { execFileSync } = require('child_process');
const { mysqlPool } = require('../config/databases');

const DEFAULT_DOC_PATH = process.argv[2] || 'F:\\MTICC DATABASE.docx';

const SUBCATEGORIES = [
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

const HEADER_LINES = new Set([
    'NAME AND SURNAME',
    'PRODUCT RANGE',
    'ITEMS PICTURE',
    'CONTACTS',
    'LOCATION',
]);

const LOCATION_KEYWORDS = [
    'MASERU',
    'MOKOTLONG',
    'BOTHA-BOTHE',
    'THETSANE',
    'LITHABANENG',
    'NONKOZI',
    'MOHLAKENG',
    'TEYATEYANENG',
    'HASLESO',
    'HATSOLO',
    'JUJU CENTRE',
    'PIM KNITWEAR',
    'MARSHAL ART',
    'LIKHAMETSI CRAFTS',
    'ICRAFT',
    'TY',
];

const PRODUCT_HINTS = [
    'jewellery', 'jewelry', 'earrings', 'bracelets', 'necklace', 'bags', 'bag',
    'basket', 'baskets', 'painting', 'paintings', 'drawing', 'drawings', 'art',
    'craft', 'wool', 'clay', 'leather', 'wood', 'table mat', 'mats', 'rugs',
    'sebelisoa', 'seshoshoe', 'sesheshoe', 'mokorotlo', 'mekorotlo', 'products',
    'production', 'garments', 'caps', 'hats', 'shirts', 'sweater', 'vase',
    'sculpture', 'sculptures',
];

const CATEGORY_RULES = [
    {
        slug: 'traditional-wear',
        patterns: [
            'seshoeshoe', 'garment', 'clothing', 'dress', 'attire', 't-shirt',
            't shirts', 'jackets', 'sweater', 'caps', 'likatiba', 'basotho hats',
            'hat', 'hats', 'mokorotlo', 'mekorotlo', 'wool',
        ],
    },
    {
        slug: 'art',
        patterns: [
            'painting', 'paintings', 'drawing', 'drawings', 'portrait', 'framed',
            'acrylic', 'art', 'comic book', 'sculpture', 'sculptures', 'landscape',
        ],
    },
    {
        slug: 'crafts',
        patterns: [
            'jewellery', 'jewelry', 'bead', 'earrings', 'bracelets', 'necklace',
            'basket', 'baskets', 'weaving', 'woven', 'leather', 'pottery', 'clay',
            'wood', 'craft', 'souvenir', 'bags', 'bag', 'belts', 'mat', 'mats',
            'rugs', 'table mats', 'wire',
        ],
    },
    { slug: 'music', patterns: ['music', 'instrument', 'song', 'choir'] },
    { slug: 'dance', patterns: ['dance', 'motjeko'] },
    { slug: 'food-heritage', patterns: ['food', 'dish', 'cooking', 'cuisine'] },
    { slug: 'storytelling', patterns: ['story', 'stories', 'narrative', 'tale'] },
    { slug: 'history', patterns: ['history', 'historic', 'heritage', 'moshoeshoe'] },
    { slug: 'architecture', patterns: ['architecture', 'building', 'structure'] },
    { slug: 'spiritual-heritage', patterns: ['spiritual', 'church', 'faith', 'temple'] },
    { slug: 'festival', patterns: ['festival', 'celebration', 'mokete'] },
];

function normalizeText(value) {
    return (value ?? '').toString().replace(/\s+/g, ' ').trim();
}

function uniqueList(values) {
    return [...new Set(values.filter(Boolean))];
}

function cleanProductText(value) {
    const text = normalizeText(value);
    if (!text) return '';
    return text
        .replace(/\s*\|\s*/g, ' | ')
        .replace(/[;|]+$/g, '')
        .trim();
}

function normalizeName(value) {
    return normalizeText(value)
        .replace(/\s{2,}/g, ' ')
        .replace(/\b(Mr|Mrs|Ms|Dr)\.?\s+/gi, '')
        .trim();
}

function mergeProductRanges(...values) {
    return uniqueList(
        values
            .flatMap((value) => cleanProductText(value).split('|'))
            .map((part) => part.trim())
    ).join(' | ');
}

function extractDocumentLines(docxPath) {
    const workspace = path.join(process.cwd(), 'tmp_mticc_import');
    const script = [
        `$doc = '${docxPath.replace(/'/g, "''")}'`,
        `$tmp = '${workspace.replace(/'/g, "''")}'`,
        'if (!(Test-Path $doc)) { throw "Document not found: $doc" }',
        'if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }',
        'New-Item -ItemType Directory -Path $tmp | Out-Null',
        'Copy-Item $doc "$tmp\\mticc.zip"',
        'Expand-Archive -Path "$tmp\\mticc.zip" -DestinationPath "$tmp\\unzipped" -Force',
        '[xml]$d = Get-Content -Raw "$tmp\\unzipped\\word\\document.xml"',
        '$ns = New-Object System.Xml.XmlNamespaceManager($d.NameTable)',
        '$ns.AddNamespace("w","http://schemas.openxmlformats.org/wordprocessingml/2006/main")',
        '$paras = $d.SelectNodes("//w:p",$ns)',
        '$lines = @()',
        'foreach ($p in $paras) {',
        '  $txtNodes = $p.SelectNodes(".//w:t",$ns)',
        '  $line = ""',
        '  foreach ($t in $txtNodes) { $line += $t.InnerText }',
        '  if ($line.Trim().Length -gt 0) { $lines += $line.Trim() }',
        '}',
        '$lines -join "`n"',
    ].join('; ');

    const output = execFileSync('powershell', ['-NoProfile', '-Command', script], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
    });
    return output
        .split(/\r?\n/)
        .map((line) => normalizeText(line))
        .filter((line) => line.length > 0)
        .filter((line) => !HEADER_LINES.has(line.toUpperCase()));
}

function hasAnyDigit(line) {
    return /\d/.test(line);
}

function isContactLine(line) {
    if (!hasAnyDigit(line)) return false;
    const digits = line.replace(/\D/g, '');
    return digits.length >= 7;
}

function extractContacts(line) {
    const matches = line.match(/\+?\d[\d\s/()-]{5,}\d/g) || [];
    const normalized = matches
        .map((v) => normalizeText(v))
        .filter((v) => v.length > 0);
    return [...new Set(normalized)];
}

function looksLikeLocation(line) {
    const upper = line.toUpperCase();
    if (LOCATION_KEYWORDS.some((token) => upper.includes(token))) return true;
    if (line.split(/\s+/).length <= 3 && /^[A-Za-z\s-]+$/.test(line) && upper === line) {
        return true;
    }
    return false;
}

function looksLikeName(line) {
    if (isContactLine(line)) return false;
    if (hasAnyDigit(line)) return false;
    if (line.length < 4) return false;
    if (looksLikeLocation(line)) return false;
    const normalized = line.toLowerCase();
    if (line.includes(',') && PRODUCT_HINTS.some((hint) => normalized.includes(hint))) {
        return false;
    }
    const tokens = line.split(/\s+/);
    if (tokens.length === 1 && line.length > 24) return false;
    const productLike = PRODUCT_HINTS.filter((hint) => normalized.includes(hint)).length;
    if (productLike >= 2) return false;
    if (!/^[A-Za-z.'\-\s&]+$/.test(line)) return false;
    return true;
}

function classifySubcategories(text) {
    const content = text.toLowerCase();
    const matched = new Set();
    for (const rule of CATEGORY_RULES) {
        if (rule.patterns.some((pattern) => content.includes(pattern))) {
            matched.add(rule.slug);
        }
    }
    if (matched.size === 0) {
        matched.add('crafts');
    }
    return [...matched];
}

function parseVendors(lines) {
    const vendors = [];
    let current = null;

    const finalizeCurrent = () => {
        if (!current || !current.name || current.products.length === 0) return;
        vendors.push({
            name: current.name,
            productRange: mergeProductRanges(...current.products),
            contacts: uniqueList(current.contacts),
            location: current.location || null,
            subcategorySlugs: classifySubcategories(
                `${current.products.join(' ')} ${current.name}`
            ),
        });
    };

    for (const line of lines) {
        if (!current) {
            if (looksLikeName(line)) {
                current = { name: normalizeName(line), products: [], contacts: [], location: null };
            }
            continue;
        }

        if (looksLikeName(line) &&
            (current.products.length > 0 || current.contacts.length > 0 || current.location)) {
            finalizeCurrent();
            current = { name: normalizeName(line), products: [], contacts: [], location: null };
            continue;
        }

        if (isContactLine(line)) {
            current.contacts.push(...extractContacts(line));
            continue;
        }

        if (!current.location && looksLikeLocation(line) && current.products.length > 0) {
            current.location = normalizeText(line);
            continue;
        }

        current.products.push(cleanProductText(line));
    }

    finalizeCurrent();
    const deduped = new Map();
    for (const vendor of vendors) {
        const key = `${vendor.name.toLowerCase()}::${(vendor.location || '').toLowerCase()}`;
        if (!deduped.has(key)) {
            deduped.set(key, vendor);
            continue;
        }
        const existing = deduped.get(key);
        const mergedProducts = mergeProductRanges(existing.productRange, vendor.productRange);
        deduped.set(key, {
            ...existing,
            productRange: mergedProducts,
            contacts: uniqueList([...(existing.contacts || []), ...(vendor.contacts || [])]),
            subcategorySlugs: uniqueList([...(existing.subcategorySlugs || []), ...(vendor.subcategorySlugs || [])])
        });
    }
    return [...deduped.values()].filter((vendor) => vendor.productRange);
}

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

async function seedSubcategories() {
    for (const item of SUBCATEGORIES) {
        await mysqlPool.execute(
            `
            INSERT INTO culture_subcategories (name, slug, icon, color, sort_order)
            VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                name = VALUES(name),
                icon = VALUES(icon),
                color = VALUES(color),
                sort_order = VALUES(sort_order)
            `,
            [item.name, item.slug, item.icon, item.color, item.sort]
        );
    }
}

async function subcategoryMap() {
    const [rows] = await mysqlPool.execute(
        'SELECT subcategory_id, slug FROM culture_subcategories'
    );
    return new Map(rows.map((row) => [row.slug, row.subcategory_id]));
}

async function importVendors(vendors) {
    const map = await subcategoryMap();
    let inserted = 0;
    let linked = 0;

    for (const vendor of vendors) {
        const sourceDocument = path.basename(DEFAULT_DOC_PATH);
        const [result] = await mysqlPool.execute(
            `
            INSERT INTO culture_vendors (name, product_range, contacts_json, location, source_document, status)
            VALUES (?, ?, ?, ?, ?, 'active')
            ON DUPLICATE KEY UPDATE
                product_range = VALUES(product_range),
                contacts_json = VALUES(contacts_json),
                location = VALUES(location),
                source_document = VALUES(source_document),
                status = 'active',
                vendor_id = LAST_INSERT_ID(vendor_id)
            `,
            [
                normalizeName(vendor.name),
                cleanProductText(vendor.productRange),
                JSON.stringify(vendor.contacts),
                normalizeText(vendor.location) || null,
                sourceDocument,
            ]
        );

        const vendorId = Number(result.insertId);
        inserted += 1;
        await mysqlPool.execute(
            'DELETE FROM culture_vendor_subcategories WHERE vendor_id = ?',
            [vendorId]
        );

        for (const slug of vendor.subcategorySlugs) {
            const subcategoryId = map.get(slug);
            if (!subcategoryId) continue;
            await mysqlPool.execute(
                `
                INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
                VALUES (?, ?)
                `,
                [vendorId, subcategoryId]
            );
            linked += 1;
        }
    }

    return { inserted, linked };
}

async function main() {
    try {
        console.log(`Reading culture source document: ${DEFAULT_DOC_PATH}`);
        const lines = extractDocumentLines(DEFAULT_DOC_PATH);
        const vendors = parseVendors(lines);

        console.log(`Parsed ${vendors.length} culture vendor entries.`);
        if (vendors.length === 0) {
            throw new Error('No vendor rows parsed from document');
        }

        await ensureTables();
        await seedSubcategories();
        const summary = await importVendors(vendors);

        console.log('Culture import complete.');
        console.log(`Vendors imported/upserted: ${summary.inserted}`);
        console.log(`Vendor-subcategory links created: ${summary.linked}`);
    } catch (error) {
        console.error('Culture import failed:', error.message);
        process.exitCode = 1;
    } finally {
        await mysqlPool.end();
    }
}

main();
