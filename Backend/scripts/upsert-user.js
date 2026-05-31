require('dotenv').config();
const bcrypt = require('bcryptjs');
const { mysqlPool } = require('../config/databases');

const VALID_ROLES = new Set(['tourist', 'vendor', 'admin']);

async function main() {
    const [email, password, fullName = 'Explore Lesotho User', role = 'admin'] = process.argv.slice(2);

    if (!email || !password) {
        throw new Error('Usage: node scripts/upsert-user.js <email> <password> [full-name] [tourist|vendor|admin]');
    }

    if (!VALID_ROLES.has(role)) {
        throw new Error(`Invalid role "${role}". Use tourist, vendor, or admin.`);
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const [existing] = await mysqlPool.execute(
        'SELECT user_id FROM users WHERE email = ? LIMIT 1',
        [email]
    );

    if (existing.length) {
        await mysqlPool.execute(
            `UPDATE users
             SET full_name = ?, password_hash = ?, role = ?, is_verified = 1, updated_at = NOW()
             WHERE email = ?`,
            [fullName, passwordHash, role, email]
        );
        console.log(`Updated ${role} login for ${email}`);
    } else {
        await mysqlPool.execute(
            `INSERT INTO users (email, password_hash, full_name, role, is_verified, created_at, updated_at)
             VALUES (?, ?, ?, ?, 1, NOW(), NOW())`,
            [email, passwordHash, fullName, role]
        );
        console.log(`Created ${role} login for ${email}`);
    }

    await mysqlPool.end();
}

main().catch(async (error) => {
    console.error('User setup failed:', error.message);
    await mysqlPool.end().catch(() => {});
    process.exit(1);
});
