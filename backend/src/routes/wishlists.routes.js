const express = require('express');
const router = express.Router();
const { verifyToken, optionalToken, requireRole } = require('../middlewares/auth.middleware');
const {
  getWishlists,
  createWishlist,
  fundWishlist,
  fulfillWishlist,
} = require('../controllers/wishlists.controller');

router.get('/', optionalToken, getWishlists);
router.post('/', verifyToken, requireRole('admin_panti'), createWishlist);
router.post('/:id/fund', verifyToken, fundWishlist);
router.patch('/:id/fulfill', verifyToken, requireRole('admin_panti'), fulfillWishlist);

module.exports = router;
