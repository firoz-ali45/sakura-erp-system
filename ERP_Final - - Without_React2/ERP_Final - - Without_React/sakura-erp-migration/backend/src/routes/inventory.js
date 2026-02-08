import express from 'express';
import { PrismaClient } from '@prisma/client';
import { body, query, validationResult } from 'express-validator';
import { authenticate, requirePermission } from '../middleware/auth.js';

const router = express.Router();
const prisma = new PrismaClient();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/inventory/items
 * Get all inventory items (with filtering and pagination)
 */
router.get('/items', [
  query('page').optional().isInt({ min: 1 }),
  query('limit').optional().isInt({ min: 1, max: 100 }),
  query('search').optional().isString(),
  query('category').optional().isString(),
  query('deleted').optional().isBoolean()
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
    const search = req.query.search || '';
    const category = req.query.category;
    const includeDeleted = req.query.deleted === 'true';

    // Build where clause
    const where = {
      ...(includeDeleted ? {} : { deleted: false }),
      ...(search && {
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { nameLocalized: { contains: search, mode: 'insensitive' } },
          { sku: { contains: search, mode: 'insensitive' } },
          { barcode: { contains: search, mode: 'insensitive' } }
        ]
      }),
      ...(category && { category })
    };

    // Get items and total count
    const [items, total] = await Promise.all([
      prisma.inventoryItem.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' }
      }),
      prisma.inventoryItem.count({ where })
    ]);

    res.json({
      success: true,
      data: {
        items,
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
 * GET /api/inventory/items/:id
 * Get single inventory item
 */
router.get('/items/:id', async (req, res, next) => {
  try {
    const item = await prisma.inventoryItem.findUnique({
      where: { id: req.params.id },
      include: {
        categoryRelation: true
      }
    });

    if (!item) {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }

    res.json({
      success: true,
      data: { item }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/inventory/items
 * Create new inventory item
 */
router.post('/items', [
  body('name').notEmpty().trim(),
  body('sku').notEmpty().trim(),
  body('storageUnit').notEmpty().trim(),
  body('ingredientUnit').notEmpty().trim(),
  body('storageToIngredient').optional().isNumeric(),
  body('costingMethod').optional().isString(),
  body('cost').optional().isNumeric()
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
      name,
      nameLocalized,
      inventoryItemId,
      sku,
      category,
      categoryId,
      storageUnit,
      ingredientUnit,
      storageToIngredient = 1,
      costingMethod = 'From Transactions',
      cost = 0,
      barcode,
      minLevel,
      maxLevel,
      parLevel,
      tags = [],
      ingredients = [],
      suppliers = []
    } = req.body;

    // Check if SKU already exists
    const existingItem = await prisma.inventoryItem.findUnique({
      where: { sku }
    });

    if (existingItem) {
      return res.status(400).json({
        success: false,
        error: 'SKU already exists'
      });
    }

    // Create item
    const item = await prisma.inventoryItem.create({
      data: {
        name,
        nameLocalized,
        inventoryItemId,
        sku,
        category: category || 'Uncategorized',
        categoryId,
        storageUnit,
        ingredientUnit,
        storageToIngredient: parseFloat(storageToIngredient),
        costingMethod,
        cost: parseFloat(cost),
        barcode,
        minLevel,
        maxLevel,
        parLevel,
        tags: Array.isArray(tags) ? tags : [],
        ingredients: Array.isArray(ingredients) ? ingredients : [],
        suppliers: Array.isArray(suppliers) ? suppliers : []
      }
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        action: 'INSERT',
        entityType: 'inventory_items',
        entityId: item.id,
        newValues: item,
        ipAddress: req.ip,
        userAgent: req.get('user-agent')
      }
    });

    res.status(201).json({
      success: true,
      data: { item }
    });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(400).json({
        success: false,
        error: 'SKU or inventory item ID already exists'
      });
    }
    next(error);
  }
});

/**
 * PUT /api/inventory/items/:id
 * Update inventory item
 */
router.put('/items/:id', [
  body('name').optional().notEmpty().trim(),
  body('sku').optional().notEmpty().trim()
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

    const itemId = req.params.id;

    // Get existing item
    const existingItem = await prisma.inventoryItem.findUnique({
      where: { id: itemId }
    });

    if (!existingItem) {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }

    // Prepare update data
    const updateData = {};
    const allowedFields = [
      'name', 'nameLocalized', 'sku', 'category', 'categoryId',
      'storageUnit', 'ingredientUnit', 'storageToIngredient',
      'costingMethod', 'cost', 'barcode', 'minLevel', 'maxLevel',
      'parLevel', 'tags', 'ingredients', 'suppliers'
    ];

    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        if (field === 'storageToIngredient' || field === 'cost') {
          updateData[field] = parseFloat(req.body[field]);
        } else if (field === 'tags' || field === 'ingredients' || field === 'suppliers') {
          updateData[field] = Array.isArray(req.body[field]) ? req.body[field] : [];
        } else {
          updateData[field] = req.body[field];
        }
      }
    });

    // Update item
    const updatedItem = await prisma.inventoryItem.update({
      where: { id: itemId },
      data: updateData
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        action: 'UPDATE',
        entityType: 'inventory_items',
        entityId: itemId,
        oldValues: existingItem,
        newValues: updatedItem,
        ipAddress: req.ip,
        userAgent: req.get('user-agent')
      }
    });

    res.json({
      success: true,
      data: { item: updatedItem }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }
    next(error);
  }
});

/**
 * DELETE /api/inventory/items/:id
 * Soft delete inventory item
 */
router.delete('/items/:id', async (req, res, next) => {
  try {
    const itemId = req.params.id;

    // Get existing item
    const existingItem = await prisma.inventoryItem.findUnique({
      where: { id: itemId }
    });

    if (!existingItem) {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }

    // Soft delete
    const deletedItem = await prisma.inventoryItem.update({
      where: { id: itemId },
      data: {
        deleted: true,
        deletedAt: new Date()
      }
    });

    // Log audit
    await prisma.auditLog.create({
      data: {
        userId: req.user.id,
        action: 'DELETE',
        entityType: 'inventory_items',
        entityId: itemId,
        oldValues: existingItem,
        ipAddress: req.ip,
        userAgent: req.get('user-agent')
      }
    });

    res.json({
      success: true,
      message: 'Item deleted successfully',
      data: { item: deletedItem }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }
    next(error);
  }
});

/**
 * POST /api/inventory/items/:id/restore
 * Restore soft-deleted item
 */
router.post('/items/:id/restore', async (req, res, next) => {
  try {
    const itemId = req.params.id;

    const restoredItem = await prisma.inventoryItem.update({
      where: { id: itemId },
      data: {
        deleted: false,
        deletedAt: null
      }
    });

    res.json({
      success: true,
      message: 'Item restored successfully',
      data: { item: restoredItem }
    });
  } catch (error) {
    if (error.code === 'P2025') {
      return res.status(404).json({
        success: false,
        error: 'Item not found'
      });
    }
    next(error);
  }
});

/**
 * GET /api/inventory/categories
 * Get all inventory categories
 */
router.get('/categories', async (req, res, next) => {
  try {
    const includeDeleted = req.query.deleted === 'true';
    
    const where = includeDeleted ? {} : { deleted: false };

    const categories = await prisma.inventoryCategory.findMany({
      where,
      orderBy: { name: 'asc' }
    });

    res.json({
      success: true,
      data: { categories }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/inventory/categories
 * Create new category
 */
router.post('/categories', [
  body('name').notEmpty().trim()
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

    const { name, nameLocalized, reference } = req.body;

    const category = await prisma.inventoryCategory.create({
      data: {
        name,
        nameLocalized,
        reference
      }
    });

    res.status(201).json({
      success: true,
      data: { category }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/inventory/items/bulk-import
 * Bulk import items from Excel/CSV
 */
router.post('/items/bulk-import', async (req, res, next) => {
  try {
    const { items } = req.body;

    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Items array is required'
      });
    }

    // Validate and prepare items
    const itemsToCreate = items.map(item => ({
      name: item.name || item['Item Name'],
      nameLocalized: item.nameLocalized || item['Name Localized'],
      inventoryItemId: item.inventoryItemId || item['Inventory Item ID'],
      sku: item.sku || item['SKU'],
      category: item.category || 'Uncategorized',
      storageUnit: item.storageUnit || item['Storage Unit'],
      ingredientUnit: item.ingredientUnit || item['Ingredient Unit'],
      storageToIngredient: parseFloat(item.storageToIngredient || item['Storage To Ingredient Conversion'] || 1),
      costingMethod: item.costingMethod || item['Costing Method'] || 'From Transactions',
      cost: parseFloat(item.cost || item['Cost'] || 0),
      barcode: item.barcode || item['Barcode'],
      minLevel: item.minLevel || item['Minimum Level'],
      maxLevel: item.maxLevel || item['Maximum Level'],
      parLevel: item.parLevel || item['PAR Level'],
      tags: Array.isArray(item.tags) ? item.tags : [],
      ingredients: Array.isArray(item.ingredients) ? item.ingredients : [],
      suppliers: Array.isArray(item.suppliers) ? item.suppliers : []
    }));

    // Create items (using createMany for better performance)
    const result = await prisma.inventoryItem.createMany({
      data: itemsToCreate,
      skipDuplicates: true
    });

    res.json({
      success: true,
      data: {
        created: result.count,
        total: items.length
      }
    });
  } catch (error) {
    next(error);
  }
});

export default router;

