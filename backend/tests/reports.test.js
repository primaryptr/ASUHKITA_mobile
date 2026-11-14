process.env.DATABASE_URL = '';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test_secret_key_asuhkita';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/app');
const { makeToken, requestApp } = require('./test_helper');

describe('Task 3: Reports, Daily Status & Gallery-aware Letters API', () => {
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

  it('rejects POST /api/reports for donatur (403) and allows admin_panti (201)', async () => {
    const donorRes = await requestApp(app, {
      method: 'POST',
      path: '/api/reports',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: {
        child_id: 'ch-001',
        title: 'Tes Karya',
        category: 'Karya Anak',
        period: '2026-11',
        summary: 'Bintang membuat lukisan indah hari ini.',
      },
    });
    assert.equal(donorRes.status, 403);

    const adminRes = await requestApp(app, {
      method: 'POST',
      path: '/api/reports',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        child_id: 'ch-002',
        title: 'Lukisan Awan',
        category: 'Karya Anak',
        period: '2026-11',
        summary: 'Bulan melukis awan dan pelangi.',
        evidence_url: 'data:image/png;base64,iVBORw0KGgo=',
      },
    });
    assert.equal(adminRes.status, 201);
    assert.equal(adminRes.body.success, true);
    assert.equal(adminRes.body.data.title, 'Lukisan Awan');
  });

  it('filters gallery items with GET /api/reports?only_gallery=true', async () => {
    const res = await requestApp(app, {
      method: 'GET',
      path: '/api/reports?only_gallery=true',
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(Array.isArray(res.body.data));
    assert.ok(res.body.data.length >= 1);
    for (const item of res.body.data) {
      assert.ok(
        (item.evidence_url && item.evidence_url.trim().length > 0) || item.category === 'Karya Anak',
        'Every gallery item must have evidence_url or category Karya Anak'
      );
    }
  });

  it('updates child daily_status via PATCH /api/children/ch-001/daily-status', async () => {
    const patchRes = await requestApp(app, {
      method: 'PATCH',
      path: '/api/children/ch-001/daily-status',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { daily_status: 'Berhasil menyelesaikan hafalan!' },
    });
    assert.equal(patchRes.status, 200);
    assert.equal(patchRes.body.data.daily_status, 'Berhasil menyelesaikan hafalan!');

    const listRes = await requestApp(app, { method: 'GET', path: '/api/children' });
    assert.equal(listRes.status, 200);
    const bintang = listRes.body.data.find((c) => c.id === 'ch-001');
    assert.equal(bintang.daily_status, 'Berhasil menyelesaikan hafalan!');
  });

  it('supports gallery-aware file letters with short captions', async () => {
    const res = await requestApp(app, {
      method: 'POST',
      path: '/api/letters',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        child_id: 'ch-001',
        content: 'Karya',
        sender_role: 'admin',
        msg_type: 'file',
        file_url: 'data:image/png;base64,iVBORw0KGgo=',
        is_gallery_item: true,
      },
    });
    assert.equal(res.status, 201);
    assert.equal(res.body.data.is_gallery_item, true);
    assert.equal(res.body.data.msg_type, 'file');
  });
});
