require('dotenv').config();

const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL || '';
if (
  !/^postgres(?:ql)?:\/\//i.test(connectionString) ||
  /xxxx|password|ganti_|example|placeholder/i.test(connectionString)
) {
  console.error('DATABASE_URL belum dikonfigurasi dengan kredensial PostgreSQL yang valid.');
  process.exit(1);
}

const pool = new Pool({
  connectionString,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

const runMigration = async () => {
  const client = await pool.connect();
  try {
    const requiredTables = await client.query(
      `SELECT
         to_regclass('public.users') IS NOT NULL AS users,
         to_regclass('public.feedback') IS NOT NULL AS feedback`
    );
    if (!requiredTables.rows[0].users || !requiredTables.rows[0].feedback) {
      throw new Error(
        'Database bukan skema AsuhKita yang diharapkan (tabel users/feedback tidak lengkap).'
      );
    }

    const migration = fs.readFileSync(
      path.join(__dirname, '../src/config/migrations/20261025_push_tokens.sql'),
      'utf8'
    );
    await client.query(migration);

    const verification = await client.query(
      `SELECT to_regclass('public.push_tokens') IS NOT NULL AS exists`
    );
    if (!verification.rows[0].exists) {
      throw new Error('Verifikasi tabel push_tokens gagal.');
    }
    console.log('Migrasi push_tokens berhasil diterapkan dan diverifikasi.');
  } finally {
    client.release();
    await pool.end();
  }
};

runMigration().catch(error => {
  console.error('Migrasi push_tokens gagal:', error.message);
  pool.end().finally(() => process.exit(1));
});
