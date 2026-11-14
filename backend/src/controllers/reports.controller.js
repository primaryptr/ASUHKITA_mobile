const { query } = require('../config/database');

const getReports = async (req, res, next) => {
  try {
    const { child_id = '', category = '', only_gallery = '' } = req.query;
    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (child_id) {
      conditions.push(`(pr.child_id::text = $${paramIndex} OR LOWER(c.alias) = LOWER($${paramIndex}))`);
      params.push(child_id);
      paramIndex++;
    }

    if (category && category !== 'Semua') {
      conditions.push(`pr.category = $${paramIndex}`);
      params.push(category);
      paramIndex++;
    }

    if (String(only_gallery).toLowerCase() === 'true') {
      conditions.push(`(COALESCE(pr.evidence_url, '') <> '' OR pr.category = 'Karya Anak')`);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const sql = `
      SELECT pr.id, pr.child_id, c.alias AS child_alias,
             COALESCE(c.orphanage_name, o.name, 'Panti Asuhan AsuhKita') AS orphanage_name,
             pr.title, pr.category, pr.period, pr.summary,
             pr.evidence_url, pr.author_name, pr.ledger_ref, pr.created_at
      FROM progress_reports pr
      LEFT JOIN children c ON pr.child_id = c.id
      LEFT JOIN orphanages o ON c.orphanage_id = o.id
      ${whereClause}
      ORDER BY pr.created_at DESC
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

const createReport = async (req, res, next) => {
  try {
    const {
      child_id,
      title = '',
      category = 'Kegiatan',
      period = new Date().toISOString().slice(0, 7),
      summary = '',
      evidence_url = '',
      author_name,
    } = req.body;

    if (!child_id || (!summary.trim() && !title.trim())) {
      return res.status(400).json({
        success: false,
        message: 'child_id serta judul atau ringkasan kabar wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    const author = author_name || req.user?.name || 'Pengurus Panti';
    const sql = `
      INSERT INTO progress_reports (child_id, title, category, period, summary, evidence_url, author_name)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;

    const result = await query(sql, [
      child_id,
      title.trim(),
      category || 'Kegiatan',
      period || new Date().toISOString().slice(0, 7),
      summary.trim(),
      evidence_url || '',
      author,
    ]);

    return res.status(201).json({
      success: true,
      message: 'Kabar perkembangan anak berhasil dipublikasikan!',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

const deleteReport = async (req, res, next) => {
  try {
    const { id } = req.params;
    const result = await query(
      `DELETE FROM progress_reports WHERE id::text = $1 RETURNING id`,
      [id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Kabar perkembangan tidak ditemukan.',
        error: 'REPORT_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Kabar perkembangan berhasil dihapus.',
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { getReports, createReport, deleteReport };
