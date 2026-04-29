/* eslint-disable no-console */
require('dotenv').config();
const { mysqlPool } = require('../config/databases');

function normalizeText(value) {
  return (value ?? '').toString().trim();
}

function uniqueList(values) {
  return [...new Set(values.filter(Boolean))];
}

function mergeTextParts(...values) {
  return uniqueList(
    values
      .flatMap((value) => normalizeText(value).split('|'))
      .map((part) => part.trim())
  ).join(' | ') || null;
}

function parseContacts(rawValue) {
  if (!rawValue) return [];

  try {
    const parsed = JSON.parse(rawValue);
    if (Array.isArray(parsed)) {
      return uniqueList(parsed.map((value) => normalizeText(value)));
    }
  } catch (_) {
    // Ignore invalid JSON and fall back to a plain-text split.
  }

  return uniqueList(
    rawValue
      .toString()
      .split(/[,\n|]/)
      .map((value) => normalizeText(value))
  );
}

async function run() {
  const connection = await mysqlPool.getConnection();
  try {
    await connection.beginTransaction();

    const [dupes] = await connection.execute(`
      SELECT
        LOWER(TRIM(name)) AS norm_name,
        LOWER(TRIM(COALESCE(location, ''))) AS norm_location,
        MIN(vendor_id) AS keep_id,
        GROUP_CONCAT(vendor_id ORDER BY vendor_id ASC) AS all_ids,
        COUNT(*) AS total
      FROM culture_vendors
      GROUP BY norm_name, norm_location
      HAVING COUNT(*) > 1
    `);

    for (const row of dupes) {
      const keepId = Number(row.keep_id);
      const ids = (row.all_ids || '')
        .split(',')
        .map((id) => Number(id))
        .filter((id) => id && id !== keepId);

      if (ids.length === 0) continue;

      const [vendorRows] = await connection.execute(
        `
        SELECT vendor_id, product_range, contacts_json, location, source_document, status
        FROM culture_vendors
        WHERE vendor_id IN (${[keepId, ...ids].map(() => '?').join(',')})
        ORDER BY vendor_id ASC
        `,
        [keepId, ...ids]
      );

      const mergedProductRange = mergeTextParts(
        ...vendorRows.map((vendor) => vendor.product_range)
      );
      const mergedContacts = uniqueList(
        vendorRows.flatMap((vendor) => parseContacts(vendor.contacts_json))
      );
      const mergedLocation =
        vendorRows.map((vendor) => normalizeText(vendor.location)).find(Boolean) || null;
      const mergedSourceDocument = uniqueList(
        vendorRows.map((vendor) => normalizeText(vendor.source_document))
      ).join(' | ') || null;
      const mergedStatus = vendorRows.some((vendor) => vendor.status === 'active')
        ? 'active'
        : 'inactive';

      await connection.execute(
        `
        INSERT IGNORE INTO culture_vendor_subcategories (vendor_id, subcategory_id)
        SELECT ?, subcategory_id
        FROM culture_vendor_subcategories
        WHERE vendor_id IN (${ids.map(() => '?').join(',')})
        `,
        [keepId, ...ids]
      );

      await connection.execute(
        `
        UPDATE culture_vendors
        SET product_range = ?,
            contacts_json = ?,
            location = ?,
            source_document = ?,
            status = ?
        WHERE vendor_id = ?
        `,
        [
          mergedProductRange,
          JSON.stringify(mergedContacts),
          mergedLocation,
          mergedSourceDocument,
          mergedStatus,
          keepId,
        ]
      );

      await connection.execute(
        `DELETE FROM culture_vendor_subcategories
         WHERE vendor_id IN (${ids.map(() => '?').join(',')})`,
        ids
      );

      await connection.execute(
        `DELETE FROM culture_vendors
         WHERE vendor_id IN (${ids.map(() => '?').join(',')})`,
        ids
      );
    }

    await connection.commit();
    console.log(`✅ Dedupe complete. Groups processed: ${dupes.length}`);
  } catch (error) {
    await connection.rollback();
    console.error('❌ Dedupe failed:', error.message);
    process.exitCode = 1;
  } finally {
    connection.release();
    await mysqlPool.end();
  }
}

run();
