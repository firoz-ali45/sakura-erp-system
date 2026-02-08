import express from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
const prisma = new PrismaClient();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/reports/accounts-payable
 * Accounts Payable Report
 */
router.get('/accounts-payable', async (req, res, next) => {
  try {
    // Get all pending purchase orders
    const orders = await prisma.purchaseOrder.findMany({
      where: {
        status: { in: ['pending', 'partial'] }
      },
      include: {
        supplier: true,
        items: {
          include: {
            item: true
          }
        }
      },
      orderBy: { orderDate: 'asc' }
    });

    res.json({
      success: true,
      data: { orders }
    });
  } catch (error) {
    next(error);
  }
});

export default router;

