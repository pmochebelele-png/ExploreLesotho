/* eslint-disable no-console */
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });
const fs = require('fs');
const { mysqlPool } = require('../config/databases');

const DEFAULT_DATA_PATH = path.join(__dirname, 'nala_vendors.json');
const SOURCE_DOCUMENT = 'Nala Vendor Data (1).pdf';

const DEFAULT_SUBCATEGORIES = [
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

const CATEGORY_RULES = [
  {
    slug: 'traditional-wear',
    patterns: [
      'clothing', 'couture', 'fabric', 'fashion', 'style', 'styles', 'knitting',
      'knit', 'crochet', 'croched', 'hair accessories', 'accessories', 'bold couture',
    ],
  },
  {
    slug: 'art',
    patterns: [
      'art', 'arts', 'gallery', 'paint', 'painting', 'draw', 'drawing', 'portrait',
      'design', 'bonono',
    ],
  },
  {
    slug: 'crafts',
    patterns: [
      'craft', 'handy', 'handmade', 'bead', 'beads', 'jewel', 'jewellery', 'jewelry',
      'handicraft', 'decor', 'reuse', 'recycle', 'ecobrick', 'plastic', 'fabrication',
      'crochet', 'croched', 'mushroom', 'beekeeping',
    ],
  },
  {
    slug: 'food-heritage',
    patterns: ['food', 'cook', 'kitchen', 'pheha', 'mushroom', 'beekeeping', 'honey'],
  },
  {
    slug: 'music',
    patterns: ['beat', 'beats', 'music', 'production', 'productions'],
  },
];

const PRODUCT_LABEL_RULES = [
  { label: 'Clothing and fashion', patterns: ['clothing', 'couture', 'fashion', 'styles', 'fabric'] },
  { label: 'Knitted and crochet goods', patterns: ['knitting', 'knit', 'crochet', 'croched'] },
  { label: 'Jewellery and accessories', patterns: ['jewel', 'jewellery', 'jewelry', 'bead', 'beads', 'accessories'] },
  { label: 'Arts and paintings', patterns: ['art', 'arts', 'gallery', 'paint', 'drawing', 'bonono'] },
  { label: 'Crafts and handmade decor', patterns: ['craft', 'handmade', 'handy', 'decor', 'handicraft'] },
  { label: 'Recycling and eco products', patterns: ['ecobrick', 'recycle', 'reuse', 'plastic'] },
  { label: 'Beauty and personal care', patterns: ['skincare', 'hair'] },
  { label: 'Home decor and landscaping', patterns: ['decor', 'landscaping'] },
  { label: 'Food products', patterns: ['food', 'pheha', 'mushroom', 'honey', 'beekeeping'] },
  { label: 'Creative production services', patterns: ['production', 'productions', 'infinite'] },
];

const normalize = (value) => (value ?? '').toString().replace(/\s+/g, ' ').trim();
const lower = (value) => normalize(value).toLowerCase();
const uniqueList = (values) => [...new Set(values.filter(Boolean))];

function titleCase(value) {
  const text = normalize(value);
  if (!text) return '';
  if (/[a-z]/.test(text) && /[A-Z]/.test(text.slice(1))) return text;
  return text
    .toLowerCase()
    .replace(/\b\w/g, (match) => match.toUpperCase());
}

function normalizeBusinessName(value) {
  const text = normalize(value);
  if (!text) return '';
  return text
    .replace(/\s*\(\s*pty\s*\)\s*ltd/gi, ' (Pty) Ltd')
    .replace(/\s*pty\s*ltd/gi, ' Pty Ltd')
    .replace(/\s+/g, ' ')
    .trim();
}

function inferSubcategorySlugs(businessName) {
  const text = lower(businessName);
  const matched = CATEGORY_RULES
    .filter((rule) => rule.patterns.some((pattern) => text.includes(pattern)))
    .map((rule) => rule.slug);

  return matched.length ? uniqueList(matched) : ['crafts'];
}

function inferProductRange(businessName) {
  const text = lower(businessName);
  const labels = PRODUCT_LABEL_RULES
    .filter((rule) => rule.patterns.some((pattern) => text.includes(pattern)))
    .map((rule) => rule.label);

  if (labels.length) {
    return uniqueList(labels).join(' | ');
  }

  return 'Cultural products and services';
}

function buildContacts(fullName) {
  const ownerName = titleCase(fullName);
  return ownerName ? [`Owner: ${ownerName}`] : [];
}

async function ensureCultureTables() {
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

  for (const sub of DEFAULT_SUBCATEGORIES) {
    await mysqlPool.execute(
      `INSERT IGNORE INTO culture_subcategories (name, slug, icon, color, sort_order)
       VALUES (?, ?, ?, ?, ?)`,
      [sub.name, sub.slug, sub.icon, sub.color, sub.sort]
    );
  }
}

async function run() {
  const dataPath = process.argv[2] || DEFAULT_DATA_PATH;
  if (!fs.existsSync(dataPath)) {
    console.error(`❌ Data file not found: ${dataPath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(dataPath, 'utf8');
  const rows = JSON.parse(raw);
  if (!Array.isArray(rows) || rows.length === 0) {
    console.error('❌ Data file is empty or invalid.');
    process.exit(1);
  }

  await ensureCultureTables();

  for (const row of rows) {
    const fullName = normalize(row.fullName);
    const businessName = normalizeBusinessName(row.businessName);
    if (!businessName) continue;

    const productRange = inferProductRange(businessName);
    const contacts = buildContacts(fullName);

    const [result] = await mysqlPool.execute(
      `INSERT INTO culture_vendors (name, product_range, contacts_json, location, source_document, status)
       VALUES (?, ?, ?, ?, ?, 'active')
       ON DUPLICATE KEY UPDATE
         product_range = VALUES(product_range),
         contacts_json = VALUES(contacts_json),
         location = VALUES(location),
         source_document = VALUES(source_document),
         status = 'active'`,
      [businessName, productRange, JSON.stringify(contacts), null, SOURCE_DOCUMENT]
    );

    const vendorId = result.insertId || null;
    const [vendorRows] = vendorId
      ? [[{ vendor_id: vendorId }]]
      : await mysqlPool.execute(
          'SELECT vendor_id FROM culture_vendors WHERE name = ? LIMIT 1',
          [businessName]
        );

    if (!vendorRows.length) continue;

    const vendorDbId = vendorRows[0].vendor_id;
    await mysqlPool.execute(
      'DELETE FROM culture_vendor_subcategories WHERE vendor_id = ?',
      [vendorDbId]
    );

    for (const subSlug of inferSubcategorySlugs(businessName)) {
      const [subRows] = await mysqlPool.execute(
        'SELECT subcategory_id FROM culture_subcategories WHERE slug = ? LIMIT 1',
        [subSlug]
      );
      if (!subRows.length) continue;

      await mysqlPool.execute(
        `INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
         VALUES (?, ?)`,
        [vendorDbId, subRows[0].subcategory_id]
      );
    }
  }

  console.log(`✅ Imported ${rows.length} Nala vendors`);
  await mysqlPool.end();
}

run().catch((error) => {
  console.error('❌ Import failed:', error.message);
  process.exit(1);
});
