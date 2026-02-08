import express from 'express';
import { PrismaClient } from '@prisma/client';
import { body, query, validationResult } from 'express-validator';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
const prisma = new PrismaClient();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/purchase-orders
 * Get all purchase orders
 */
router.get('/', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('status').optional().isString(),
  query('supplierId').optional().isUUID()
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        errors: errors.array()
      });
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const where = {
      ...(req.query.status && { status: req.query.status }),
      ...(req.query.supplierId && { supplierId: req.query.supplierId })
    };

    const [orders, total] = await Promise.all([
      prisma.purchaseOrder.findMany({
        where,
        include: {
          supplier: true,
          items: {
            include: {
              item: true
            }
          }
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' }
      }),
      prisma.purchaseOrder.count({ where })
    ]);

    res.json({
      success: true,
      data: {
        orders,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/purchase-orders/:id
 * Get single purchase order
 */
router.get('/:id', async (req, res, next) => {
  try {
    const order = await prisma.purchaseOrder.findUnique({
      where: { id: req.params.id },
      include: {
        supplier: true,
        items: {
          include: {
            item: true
          }
        }
      }
    });

    if (!order) {
      return res.status(404).json({
        success: false,
        error: 'Purchase order not found'
      });
    }

    res.json({
      success: true,
      data: { order }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/purchase-orders
 * Create new purchase order
 */
router.post('/', [
  body('poNumber').notEmpty().trim(),
  body('supplierId').isUUID(),
  body('orderDate').isISO8601(),
  body('items').isArray().notEmpty()
], async (req, res, next) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        errors: errors.array()
      });
    }

    const {
      poNumber,
      supplierId,
      orderDate,
      expectedDate,
      status = 'pending',
      notes,
      items
    } = req.body;

    // Calculate totals
    let totalAmount = 0;
    let vatAmount = 0;

    const orderItems = items.map(item => {
      const quantity = parseFloat(item.quantity);
      const unitPrice = parseFloat(item.unitPrice);
      const vatRate = parseFloat(item.vatRate || 0);
      const itemVatAmount = (quantity * unitPrice * vatRate) / 100;
      const itemTotal = (quantity * unitPrice) + itemVatAmount;

      totalAmount += itemTotal;
      vatAmount += itemVatAmount;

      return {
        itemId: item.itemId,
        quantity,
        unitPrice,
        vatRate,
        vatAmount: itemVatAmount,
        totalAmount: itemTotal,
        batchNumber: item.batchNumber,
        expiryDate: item.expiryDate ? new Date(item.expiryDate) : null
      };
    });

    // Create purchase order with items
    const order = await prisma.purchaseOrder.create({
      data: {
        poNumber,
        supplierId,
        orderDate: new Date(orderDate),
        expectedDate: expectedDate ? new Date(expectedDate) : null,
        status,
        totalAmount,
        vatAmount,
        notes,
        createdBy: req.user.id,
        items: {
          create: orderItems
        }
      },
      include: {
        supplier: true,
        items: {
          include: {
            item: true
          }
        }
      }
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        action: 'INSERT',
        entityType: 'purchase_orders',
        entityId: order.id,
        newValues: order,
        ipAddress: req.ip,
        userAgent: req.get('user-agent')
      }
    });

    res.status(201).json({
      success: true,
      data: { order }
    });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({
        success: false,
        error: 'PO Number already exists'
      });
    }
    next(error);
  }
});

/**
 * PUT /api/purchase-orders/:id
 * Update purchase order
 */
router.put('/:id', async (req, res, next) => {
  try {
    const orderId = req.params.id;

    const existingOrder = await prisma.purchaseOrder.findUnique({
      where: { id: orderId }
    });

    if (!existingOrder) {
      return res.status(404).json({
        success: false,
        error: 'Purchase order not found'
      });
    }

    const updateData = {};
    const allowedFields = ['status', 'expectedDate', 'notes'];

    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        if (field === 'expectedDate') {
          updateData[field] = new Date(req.body[field]);
        } else {
          updateData[field] = req.body[field];
        }
      }
    });

    const updatedOrder = await prisma.purchaseOrder.update({
      where: { id: orderId },
      data: updateData,
      include: {
        supplier: true,
        items: {
          include: {
            item: true
          }
        }
      }
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        action: 'UPDATE',
        entityType: 'purchase_orders',
        entityId: orderId,
        oldValues: existingOrder,
        newValues: updatedOrder,
        ipAddress: req.ip,
        userAgent: req.get('user-agent')
      }
    });

    res.json({
      success: true,
      data: { order: updatedOrder }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: 'Purchase order not found'
      });
    }
    next(error);
  }
});

/**
 * GET /api/purchase-orders/suppliers
 * Get all suppliers
 */
router.get('/suppliers', async (req, res, next) => {
  try {
    const suppliers = await prisma.supplier.findMany({
      where: { deleted: false },
      orderBy: { name: 'asc' }
    });

    res.json({
      success: true,
      data: { suppliers }
    });
  } catch (error) {
    next(error);
  }
});

export default router;

