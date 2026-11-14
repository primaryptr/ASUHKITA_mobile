process.env.DATABASE_URL = '';
process.env.JWT_ACCESS_SECRET = process.env.JWT_ACCESS_SECRET || 'test_secret_key_asuhkita';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/app');
const { makeToken, requestApp } = require('./test_helper');

describe('Task 6: Micro-Wishlist API', () => {
  const donorToken = makeToken({
    id: 'usr-demo-001',
    role: 'donatur',
    email: 'demo@asuhkita.com',
    name: 'Demo Donatur',
  });
  const secondDonorToken = makeToken({
    id: 'usr-demo-002',
    role: 'donatur',
    email: 'demo2@asuhkita.com',
    name: 'Donatur Kedua',
  });
  const adminToken = makeToken({
    id: 'usr-admin-001',
    role: 'admin_panti',
    email: 'admin@asuhkita.com',
    name: 'Admin Al-Ikhlas',
  });

  let createdId = '';

  it('rejects POST /api/wishlists for donatur (403) and creates wishlist for admin_panti (201)', async () => {
    const donorRes = await requestApp(app, {
      method: 'POST',
      path: '/api/wishlists',
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { child_id: 'ch-001', item_name: 'Tas Sekolah Baru', estimated_idr: 175000 },
    });
    assert.equal(donorRes.status, 403);

    const adminRes = await requestApp(app, {
      method: 'POST',
      path: '/api/wishlists',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { child_id: 'ch-001', item_name: 'Tas Sekolah Baru', estimated_idr: 175000 },
    });
    assert.equal(adminRes.status, 201);
    assert.equal(adminRes.body.success, true);
    assert.equal(adminRes.body.data.status, 'open');
    createdId = adminRes.body.data.id;
    assert.ok(createdId);
  });

  it('lists wishlists via GET /api/wishlists?child_id=ch-001', async () => {
    const res = await requestApp(app, {
      method: 'GET',
      path: '/api/wishlists?child_id=ch-001',
      headers: { Authorization: `Bearer ${donorToken}` },
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(Array.isArray(res.body.data));
    assert.ok(res.body.data.some((w) => w.item_name === 'Tas Sekolah Baru'));
  });

  it('allows donor to fund open wishlist (200) and blocks double-funding (409)', async () => {
    const firstFund = await requestApp(app, {
      method: 'POST',
      path: `/api/wishlists/${createdId}/fund`,
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { amount_idr: 175000 },
    });
    assert.equal(firstFund.status, 200);
    assert.equal(firstFund.body.data.status, 'funded');
    assert.equal(firstFund.body.data.funded_by_user_id, 'usr-demo-001');

    const secondFund = await requestApp(app, {
      method: 'POST',
      path: `/api/wishlists/${createdId}/fund`,
      headers: { Authorization: `Bearer ${secondDonorToken}` },
      body: { amount_idr: 175000 },
    });
    assert.equal(secondFund.status, 409);
  });

  it('rejects PATCH /api/wishlists/:id/fulfill for donatur (403) and allows admin_panti (200)', async () => {
    const donorRes = await requestApp(app, {
      method: 'PATCH',
      path: `/api/wishlists/${createdId}/fulfill`,
      headers: { Authorization: `Bearer ${donorToken}` },
      body: { receipt_url: 'data:image/png;base64,iVBORw0KGgo=' },
    });
    assert.equal(donorRes.status, 403);

    const adminRes = await requestApp(app, {
      method: 'PATCH',
      path: `/api/wishlists/${createdId}/fulfill`,
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { receipt_url: 'data:image/png;base64,iVBORw0KGgo=' },
    });
    assert.equal(adminRes.status, 200);
    assert.equal(adminRes.body.data.status, 'fulfilled');
    assert.equal(adminRes.body.data.receipt_url, 'data:image/png;base64,iVBORw0KGgo=');
  });
});
