
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  createSchedule, getSchedules, updateScheduleStatus
} = require('../controllers/orphanages.controller');


router.post('/schedules', verifyToken, createSchedule);
router.get('/schedules', verifyToken, getSchedules);
router.patch('/schedules/:id/status', verifyToken, requireRole('admin_panti'), updateScheduleStatus);

module.exports = router;
