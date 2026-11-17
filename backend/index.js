
require('dotenv').config();
const app = require('./src/app');
const { pool, isMockMode } = require('./src/config/database');

const PORT = process.env.PORT || 3000;

async function startServer() {
  // Kalau mock mode (DATABASE_URL kosong/dummy), langsung start tanpa tes koneksi DB
  if (isMockMode) {
    console.log('⚠️  [MOCK MODE] Berjalan dengan data IN-MEMORY (demo/testing).');
    console.log('⚠️  Untuk koneksi ke Supabase, isi DATABASE_URL yang valid di .env');
    return startListening();
  }

  // Coba koneksi ke Supabase dulu
  try {
    await pool.query('SELECT NOW()');
    console.log('✅ Koneksi ke Supabase PostgreSQL berhasil!');
    return startListening();
  } catch (err) {
    console.error('❌ Gagal terhubung ke Supabase:', err.message);
    console.log('⚠️  Beralih ke MOCK MODE (data in-memory) sebagai fallback...');
    // Tetap jalankan server dengan mock mode — jangan crash
    return startListening();
  }
}

function startListening() {
  app.listen(PORT, () => {
    console.log('');
    console.log('╔══════════════════════════════════════╗');
    console.log('║   AsuhKita Backend Server v1.0.0     ║');
    console.log('╠══════════════════════════════════════╣');
    console.log(`║   Berjalan di: http://localhost:${PORT}  ║`);
    console.log(`║   Mode: ${process.env.NODE_ENV || 'development'}                  ║`);
    console.log('╚══════════════════════════════════════╝');
    console.log('');
    console.log('📌 Endpoint yang tersedia:');
    console.log(`   [AUTH]      POST /api/auth/register | login | refresh | logout`);
    console.log(`   [AUTH]      GET  /api/auth/me`);
    console.log(`   [PROFILE]   GET/PUT /api/users/profile`);
    console.log(`   [PROFILE]   POST /api/users/profile/photo`);
    console.log(`   [FEEDBACK]  POST/GET /api/feedback`);
    console.log(`   [CHILDREN]  GET /api/children | /api/children/:id | /api/children/packages`);
    console.log(`   [DONATIONS] POST /api/donations | /api/donations/sponsorships`);
    console.log(`   [DONATIONS] GET /api/donations/history | POST /api/donations/sync`);
    console.log(`   [LEDGER]    GET /api/ledger | /api/ledger/verify | /api/ledger/block/:index`);
    console.log(`   [LEDGER]    POST /api/ledger/certificates | /api/ledger/report`);
    console.log(`   [SCHEDULE]  POST/GET /api/orphanages/schedules`);
    console.log(`   [GAME]      POST /api/game/scores | /api/game/steps`);
    console.log(`   [GAME]      GET  /api/game/leaderboard | /api/game/my-scores | /api/game/steps`);
    console.log(`   [IOT]       POST /api/iot/events | /api/iot/devices`);
    console.log(`   [IOT]       GET  /api/iot/events | /api/iot/test-hmac`);
    console.log('');
  });
}

startServer();
