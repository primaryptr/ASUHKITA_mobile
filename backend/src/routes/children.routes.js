
const express = require('express');
const router = express.Router();
const { verifyToken, optionalToken, requireRole } = require('../middlewares/auth.middleware');
const {
  getChildren,
  getChildDetail,
  getPackages,
  createChild,
  updateChild,
  updateDailyStatus,
  deleteChild,
  deleteAllChildren,
} = require('../controllers/children.controller');

router.get('/packages', optionalToken, getPackages);
router.get('/', optionalToken, getChildren);
router.get('/:id', optionalToken, getChildDetail);
router.post('/', verifyToken, createChild);
router.put('/:id', verifyToken, updateChild);
router.patch('/:id/daily-status', verifyToken, requireRole('admin_panti'), updateDailyStatus);
router.delete('/:id', verifyToken, deleteChild);
router.delete('/', verifyToken, deleteAllChildren);

module.exports = router;


