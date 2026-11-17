



const { query } = require('../config/database');











const createSchedule = async (req, res, next) => {
  try {
    const { sponsorship_id, scheduled_at_utc, donor_timezone, notes } = req.body;

    if (!sponsorship_id || !scheduled_at_utc) {
      return res.status(400).json({
        success: false,
        message: 'sponsorship_id dan scheduled_at_utc wajib diisi.',
        error: 'MISSING_FIELDS',
      });
    }


    const scheduledDate = new Date(scheduled_at_utc);
    if (isNaN(scheduledDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Format tanggal tidak valid. Gunakan format ISO 8601 (contoh: 2026-10-25T10:00:00Z)',
        error: 'INVALID_DATE',
      });
    }

    if (scheduledDate < new Date()) {
      return res.status(400).json({
        success: false,
        message: 'Jadwal tidak boleh di masa lalu.',
        error: 'DATE_IN_PAST',
      });
    }

    const result = await query(
      `INSERT INTO call_schedules (sponsorship_id, scheduled_at_utc, donor_timezone, notes)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [sponsorship_id, scheduledDate.toISOString(), donor_timezone || 'Asia/Jakarta', notes || '']
    );

    const schedule = result.rows[0];




    const utcTime = new Date(schedule.scheduled_at_utc);
    const timezones = convertToFourTimezones(utcTime);

    return res.status(201).json({
      success: true,
      message: 'Jadwal video call berhasil dibuat.',
      data: {
        schedule,
        display_times: timezones,
      },
    });
  } catch (err) {
    next(err);
  }
};






const getSchedules = async (req, res, next) => {
  try {
    const isAdmin = req.user?.role === 'admin_panti';
    const sql = isAdmin
      ? `SELECT cs.*, c.alias AS child_alias, o.name AS orphanage_name,
                u.name AS donor_name, u.email AS donor_email
         FROM call_schedules cs
         LEFT JOIN sponsorships s ON cs.sponsorship_id = s.id
         LEFT JOIN children c ON s.child_id = c.id
         LEFT JOIN orphanages o ON c.orphanage_id = o.id
         LEFT JOIN users u ON s.user_id = u.id
         ORDER BY cs.scheduled_at_utc ASC`
      : `SELECT cs.*, c.alias AS child_alias, o.name AS orphanage_name
         FROM call_schedules cs
         JOIN sponsorships s ON cs.sponsorship_id = s.id
         JOIN children c ON s.child_id = c.id
         JOIN orphanages o ON c.orphanage_id = o.id
         WHERE s.user_id = $1
         ORDER BY cs.scheduled_at_utc ASC`;

    const result = await query(sql, isAdmin ? [] : [req.user.id]);

    const schedulesWithTimezones = result.rows.map(s => ({
      ...s,
      display_times: convertToFourTimezones(new Date(s.scheduled_at_utc)),
    }));

    return res.status(200).json({
      success: true,
      data: schedulesWithTimezones,
    });
  } catch (err) {
    next(err);
  }
};

const updateScheduleStatus = async (req, res, next) => {
  try {
    const { id } = req.params;
    const { status, scheduled_at_utc, admin_notes } = req.body;
    const allowed = ['scheduled', 'approved', 'rescheduled', 'completed'];

    if (!allowed.includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Status jadwal harus salah satu dari: scheduled, approved, rescheduled, completed.',
        error: 'INVALID_STATUS',
      });
    }

    let nextIso = null;
    if (scheduled_at_utc) {
      const parsed = new Date(scheduled_at_utc);
      if (isNaN(parsed.getTime())) {
        return res.status(400).json({
          success: false,
          message: 'Format scheduled_at_utc tidak valid.',
          error: 'INVALID_DATE',
        });
      }
      nextIso = parsed.toISOString();
    }

    const result = await query(
      `UPDATE call_schedules
       SET status = $1,
           scheduled_at_utc = COALESCE($2, scheduled_at_utc),
           admin_notes = COALESCE($3, admin_notes)
       WHERE id = $4
       RETURNING *`,
      [status, nextIso, admin_notes !== undefined ? String(admin_notes) : '', id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'Jadwal tidak ditemukan.',
        error: 'NOT_FOUND',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Status koordinasi jadwal berhasil diperbarui.',
      data: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};






const convertToFourTimezones = (utcDate) => {
  const format = (d) => d.toISOString().replace('T', ' ').substring(0, 16) + ' ';



  const month = utcDate.getUTCMonth();
  const londonOffset = (month >= 2 && month <= 9) ? 60 : 0;

  const addMinutes = (date, minutes) => new Date(date.getTime() + minutes * 60000);

  return {
    WIB: {
      label: 'WIB (Asia/Jakarta)',
      offset: '+07:00',
      time: format(addMinutes(utcDate, 420)),
    },
    WITA: {
      label: 'WITA (Asia/Makassar)',
      offset: '+08:00',
      time: format(addMinutes(utcDate, 480)),
    },
    WIT: {
      label: 'WIT (Asia/Jayapura)',
      offset: '+09:00',
      time: format(addMinutes(utcDate, 540)),
    },
    London: {
      label: londonOffset > 0 ? 'London (BST/UTC+1)' : 'London (GMT/UTC+0)',
      offset: londonOffset > 0 ? '+01:00' : '+00:00',
      time: format(addMinutes(utcDate, londonOffset)),
      is_dst: londonOffset > 0,
    },
  };
};

module.exports = {
  createSchedule,
  getSchedules,
  updateScheduleStatus,
};
