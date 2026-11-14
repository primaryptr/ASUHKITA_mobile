process.env.DATABASE_URL = '';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test_secret_key_asuhkita';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/app');
const { makeToken, requestApp } = require('./test_helper');

describe('Task 7: Two-Way Schedule Coordination API', () => {
  const donorToken = makeToken({
    id: 'usr-demo-001',
    role: 'donatur',
    email: 'demo@asuhkita.com',
    name: 'Demo Donatur',
  });
  const adminToken = makeToken({
    id: 'usr-admin-001',
    role: 'admin_panti',
    email: 'admin@asuhkita.com',
    name: 'Admin Al-Ikhlas',
  });

  let createdScheduleId = '';

  it('creates schedule via POST /api/orphanages/schedules and exposes role-aware GET /api/orphanages/schedules', async () => {
    const futureIso = new Date(Date.now() + 86400000).toISOString();
    const createRes = await requestApp(app, {
      method: 'POST',
      path: '/api/orphanages/schedules',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        sponsorship_id: 'sp-seed-001',
        scheduled_at_utc: futureIso,
        donor_timezone: 'Asia/Jakarta',
        notes: 'Ingin menyapa Bintang',
      },
    });
    assert.equal(createRes.status, 201);
    createdScheduleId = createRes.body.data.schedule.id;
    assert.ok(createdScheduleId);

    const adminListRes = await requestApp(app, {
      method: 'GET',
      path: '/api/orphanages/schedules',
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert.equal(adminListRes.status, 200);
    assert.equal(adminListRes.body.success, true);
    assert.ok(adminListRes.body.data.some((s) => s.id === createdScheduleId));

    const donorListRes = await requestApp(app, {
      method: 'GET',
      path: '/api/orphanages/schedules',
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(donorListRes.status, 200);
    assert.equal(donorListRes.body.success, true);
  });

  it('rejects PATCH /api/orphanages/schedules/:id/status for donatur (403) and updates for admin_panti (200)', async () => {
    const donorRes = await requestApp(app, {
      method: 'PATCH',
      path: `/api/orphanages/schedules/${createdScheduleId}/status`,
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { status: 'approved', admin_notes: 'Diterima' },
    });
    assert.equal(donorRes.status, 403);

    const adminRes = await requestApp(app, {
      method: 'PATCH',
      path: `/api/orphanages/schedules/${createdScheduleId}/status`,
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { status: 'approved', admin_notes: 'Siap jam 10 WIB via Zoom.' },
    });
    assert.equal(adminRes.status, 200);
    assert.equal(adminRes.body.data.status, 'approved');
    assert.equal(adminRes.body.data.admin_notes, 'Siap jam 10 WIB via Zoom.');
  });
});
