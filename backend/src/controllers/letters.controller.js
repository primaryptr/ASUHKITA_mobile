




const { query } = require('../config/database');




const createLetter = async (req, res, next) => {
  try {
    const {
      child_id,
      content = '',
      ai_generated = false,
      sender_role,
      msg_type = 'text',
      file_url = '',
      is_gallery_item = false,
    } = req.body;

    const normalizedType = msg_type === 'file' ? 'file' : 'text';
    const trimmedContent = String(content).trim();

    if (!child_id || (normalizedType !== 'file' && !trimmedContent) || (normalizedType === 'file' && !file_url && !trimmedContent)) {
      return res.status(400).json({
        success: false,
        message: 'child_id dan isi pesan atau lampiran wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }

    if (normalizedType !== 'file' && trimmedContent.length < 10) {
      return res.status(400).json({
        success: false,
        message: 'Isi surat minimal 10 karakter.',
        error: 'CONTENT_TOO_SHORT',
      });
    }

    const childCheck = await query(
      `SELECT id, alias FROM children WHERE id = $1`,
      [child_id]
    );

    if (childCheck.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Anak asuh tidak ditemukan.',
        error: 'CHILD_NOT_FOUND',
      });
    }

    const resolvedRole = sender_role || (req.user?.role === 'admin_panti' ? 'admin' : 'donor');
    const result = await query(
      `INSERT INTO letters (user_id, child_id, content, ai_generated, sender_role, msg_type, file_url, is_gallery_item)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, user_id, child_id, content, ai_generated, sender_role, msg_type, file_url, is_gallery_item, created_at`,
      [
        req.user.id,
        child_id,
        trimmedContent,
        ai_generated === true,
        resolvedRole,
        normalizedType,
        file_url || '',
        Boolean(is_gallery_item),
      ]
    );

    return res.status(201).json({
      success: true,
      message: `Surat berhasil dikirim ke ${childCheck.rows[0]?.alias || 'anak asuh'}! 💌`,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};


const getMyLetters = async (req, res, next) => {
  try {
    const { child_id, is_gallery_item } = req.query;
    const isAdmin = req.user?.role === 'admin_panti';
    const galleryFilter = String(is_gallery_item).toLowerCase() === 'true'
      ? ` AND (l.is_gallery_item = TRUE OR COALESCE(l.file_url, '') <> '')`
      : '';
    let sql, params;

    if (child_id && isAdmin) {
      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.sender_role, l.msg_type, l.file_url, l.is_gallery_item, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.child_id = $1${galleryFilter}
             ORDER BY l.created_at DESC`;
      params = [child_id];
    } else if (child_id) {
      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.sender_role, l.msg_type, l.file_url, l.is_gallery_item, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.user_id = $1 AND l.child_id = $2${galleryFilter}
             ORDER BY l.created_at DESC`;
      params = [req.user.id, child_id];
    } else {
      sql = `SELECT l.id, l.child_id, c.alias AS child_alias, l.content,
                    l.ai_generated, l.sender_role, l.msg_type, l.file_url, l.is_gallery_item, l.created_at
             FROM letters l
             LEFT JOIN children c ON c.id = l.child_id
             WHERE l.user_id = $1${galleryFilter}
             ORDER BY l.created_at DESC`;
      params = [req.user.id];
    }

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






const getLetterById = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await query(
      `SELECT l.id, l.user_id, l.child_id, c.alias AS child_alias,
              l.content, l.ai_generated, l.created_at
       FROM letters l
       LEFT JOIN children c ON c.id = l.child_id
       WHERE l.id = $1 AND l.user_id = $2`,
      [id, req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Surat tidak ditemukan.',
        error: 'LETTER_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const deleteLetter = async (req, res, next) => {
  try {
    const { id } = req.params;

    const result = await query(
      `DELETE FROM letters WHERE id = $1 AND user_id = $2 RETURNING id`,
      [id, req.user.id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Surat tidak ditemukan atau bukan milik Anda.',
        error: 'LETTER_NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Surat berhasil dihapus.',
    });
  } catch (err) {
    next(err);
  }
};

module.exports = { createLetter, getMyLetters, getLetterById, deleteLetter };
