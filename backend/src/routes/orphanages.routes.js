
const express = require('express');
const router = express.Router();
const { verifyToken, requireRole } = require('../middlewares/auth.middleware');
const {
  getNearbyOrphanages, getAllOrphanages, checkIn,
  createSchedule, getSchedules, updateScheduleStatus
} = require('../controllers/orphanages.controller');


router.get('/', getAllOrphanages);
router.get('/nearby', getNearbyOrphanages);
router.post('/:id/checkin', verifyToken, checkIn);


router.post('/schedules', verifyToken, createSchedule);
router.get('/schedules', verifyToken, getSchedules);
router.patch('/schedules/:id/status', verifyToken, requireRole('admin_panti'), updateScheduleStatus);

module.exports = router;
