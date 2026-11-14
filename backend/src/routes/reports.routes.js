const express = require('express');
const router = express.Router();
const { verifyToken, optionalToken, requireRole } = require('../middlewares/auth.middleware');
const { getReports, createReport, deleteReport } = require('../controllers/reports.controller');

router.get('/', optionalToken, getReports);
router.post('/', verifyToken, requireRole('admin_panti'), createReport);
router.delete('/:id', verifyToken, requireRole('admin_panti'), deleteReport);

module.exports = router;
