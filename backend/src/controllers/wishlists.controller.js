const { query } = require('../config/database');

const getWishlists = async (req, res, next) => {
  try {
    const { child_id = '', status = '' } = req.query;
    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (child_id) {
      conditions.push(`(cw.child_id::text = $${paramIndex} OR LOWER(c.alias) = LOWER($${paramIndex}))`);
      params.push(child_id);
      paramIndex++;
    }

    if (status) {
      conditions.push(`cw.status = $${paramIndex}`);
      params.push(status);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const sql = `
      SELECT cw.id, cw.child_id, c.alias AS child_alias,
             cw.item_name, cw.estimated_idr, cw.status,
             cw.funded_by_user_id, cw.funded_by_name,
             cw.receipt_url, cw.created_at
      FROM child_wishlists cw
      LEFT JOIN children c ON cw.child_id = c.id
      ${whereClause}
      ORDER BY cw.created_at DESC
    `;

    const result = await query(sql, params);
    return res.status(200).json({
      success: true,
      count: result.rowCount,
      data: result.rows,
    });
  } catch (err) {
    next(err);
  }
};

const createWishlist = async (req, res, next) => {
  try {
    const { child_id, item_name = '', estimated_idr } = req.body;
    const amount = Number(estimated_idr);

    if (!child_id || !String(item_name).trim() || !Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'child_id, item_name, dan estimated_idr (> 0) wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    const sql = `
      INSERT INTO child_wishlists (child_id, item_name, estimated_idr)
      VALUES ($1, $2, $3)
      RETURNING *
    `;
    const result = await query(sql, [child_id, String(item_name).trim(), amount]);

    return res.status(201).json({
      success: true,
      message: 'Wishlist anak berhasil ditambahkan.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

const fundWishlist = async (req, res, next) => {
  try {
    const { id } = req.params;
    const fundedByName = req.body?.donor_name || req.user?.name || 'Donatur';
    const fundedByUserId = req.user?.id || 'usr-demo-001';

    const existing = await query('SELECT * FROM child_wishlists WHERE id = $1', [id]);
    if (existing.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Item wishlist tidak ditemukan.',
        error: 'NOT_FOUND',
      });
    }

    if (existing.rows[0].status !== 'open') {
      return res.status(409).json({
        success: false,
        message: 'Kebutuhan wishlist ini sudah didanai oleh donatur lain.',
        error: 'ALREADY_FUNDED',
      });
    }

    const result = await query(
      `UPDATE child_wishlists
       SET status = 'funded', funded_by_user_id = $1, funded_by_name = $2
       WHERE id = $3 AND status = 'open'
       RETURNING *`,
      [fundedByUserId, fundedByName, id]
    );

    if (result.rowCount === 0) {
      return res.status(409).json({
        success: false,
        message: 'Kebutuhan wishlist ini sudah didanai oleh donatur lain.',
        error: 'ALREADY_FUNDED',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Terima kasih! Kebutuhan anak berhasil didanai.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

const fulfillWishlist = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { receipt_url = '' } = req.body;

    const existing = await query('SELECT * FROM child_wishlists WHERE id = $1', [id]);
    if (existing.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Item wishlist tidak ditemukan.',
        error: 'NOT_FOUND',
      });
    }

    const result = await query(
      `UPDATE child_wishlists
       SET status = 'fulfilled', receipt_url = $1
       WHERE id = $2
       RETURNING *`,
      [receipt_url || '', id]
    );

    return res.status(200).json({
      success: true,
      message: 'Wishlist ditandai sudah disalurkan dengan bukti penyaluran.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getWishlists,
  createWishlist,
  fundWishlist,
  fulfillWishlist,
};
