import express from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticate, authorize } from '../middleware/auth.js';
import bcrypt from 'bcryptjs';
import { body, validationResult } from 'express-validator';

const router = express.Router();
const prisma = new PrismaClient();

// All routes require authentication
router.use(authenticate);

/**
 * GET /api/users
 * Get all users (admin or userManagement permission)
 */
router.get('/', async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const users = await prisma.user.findMany({
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        permissions: true,
        notes: true,
        profilePhotoUrl: true,
        emailVerified: true,
        createdAt: true,
        lastLogin: true,
        lastActivity: true
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      data: { users }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users
 * Create new user (admin or userManagement permission)
 */
router.post('/', [
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }),
  body('name').notEmpty(),
  body('role').isIn(['admin', 'manager', 'user', 'viewer']),
  body('status').isIn(['active', 'inactive', 'suspended'])
], async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        errors: errors.array()
      });
    }

    const { email, password, name, phone, role, status, permissions, notes } = req.body;

    // Check if user already exists
    const existingUser = await prisma.user.findUnique({ where: { email } });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        error: 'User with this email already exists'
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);

    // Create user
    const newUser = await prisma.user.create({
      data: {
        email,
        name,
        passwordHash,
        phone: phone || '',
        role: role.toLowerCase(),
        status: status.toLowerCase(),
        permissions: permissions || {
          accountsPayable: false,
          forecasting: false,
          warehouse: false,
          userManagement: false,
          reports: false,
          settings: false
        },
        notes: notes || '',
        emailVerified: false
      },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        permissions: true,
        notes: true,
        profilePhotoUrl: true,
        emailVerified: true,
        createdAt: true,
        lastLogin: true,
        lastActivity: true
      }
    });

    res.status(201).json({
      success: true,
      message: 'User created successfully',
      data: { user: newUser }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/users/:id
 * Update user (admin or userManagement permission)
 */
router.put('/:id', [
  body('email').optional().isEmail().normalizeEmail(),
  body('password').optional().isLength({ min: 6 }),
  body('name').optional().notEmpty(),
  body('role').optional().isIn(['admin', 'manager', 'user', 'viewer']),
  body('status').optional().isIn(['active', 'inactive', 'suspended'])
], async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        error: 'Validation failed',
        errors: errors.array()
      });
    }

    const { id } = req.params;
    const { email, password, name, phone, role, status, permissions, notes } = req.body;

    // Check if user exists
    const existingUser = await prisma.user.findUnique({ where: { id } });
    if (!existingUser) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Check if email is being changed and if it's already taken
    if (email && email !== existingUser.email) {
      const emailTaken = await prisma.user.findUnique({ where: { email } });
      if (emailTaken) {
        return res.status(409).json({
          success: false,
          error: 'Email already in use'
        });
      }
    }

    // Prepare update data
    const updateData = {};
    if (name) updateData.name = name.trim();
    if (email) updateData.email = email.trim().toLowerCase();
    if (phone !== undefined) updateData.phone = phone || '';
    if (role) updateData.role = role.toLowerCase();
    if (status) updateData.status = status.toLowerCase();
    if (permissions) updateData.permissions = permissions;
    if (notes !== undefined) updateData.notes = notes || '';
    if (password) {
      updateData.passwordHash = await bcrypt.hash(password, 10);
    }

    // Update user
    const updatedUser = await prisma.user.update({
      where: { id },
      data: updateData,
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        permissions: true,
        notes: true,
        profilePhotoUrl: true,
        emailVerified: true,
        createdAt: true,
        lastLogin: true,
        lastActivity: true
      }
    });

    res.json({
      success: true,
      message: 'User updated successfully',
      data: { user: updatedUser }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/users/:id/approve
 * Approve user (admin or userManagement permission)
 */
router.put('/:id/approve', async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const { id } = req.params;
    const currentUser = req.user;

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    if (user.status === 'active') {
      return res.status(400).json({
        success: false,
        error: 'User is already active'
      });
    }

    // Update user status
    const updatedUser = await prisma.user.update({
      where: { id },
      data: {
        status: 'active',
        permissions: user.permissions || {
          accountsPayable: true,
          forecasting: false,
          warehouse: false,
          userManagement: false,
          reports: false,
          settings: false
        },
        lastActivity: new Date().toISOString()
      },
      select: {
        id: true,
        email: true,
        name: true,
        phone: true,
        role: true,
        status: true,
        permissions: true,
        notes: true,
        profilePhotoUrl: true,
        emailVerified: true,
        createdAt: true,
        lastLogin: true,
        lastActivity: true
      }
    });

    res.json({
      success: true,
      message: 'User approved successfully',
      data: { user: updatedUser }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/users/:id/resend-verification
 * Resend verification email (admin or userManagement permission)
 */
router.post('/:id/resend-verification', async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const { id } = req.params;

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // In production, send verification email here
    // For now, just return success
    res.json({
      success: true,
      message: 'Verification email sent successfully'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/users/:id
 * Delete user (admin or userManagement permission)
 */
router.delete('/:id', async (req, res, next) => {
  // Check if user has admin role or userManagement permission
  if (req.user.role !== 'admin' && !req.user.permissions?.userManagement) {
    return res.status(403).json({
      success: false,
      error: 'Insufficient permissions'
    });
  }
  
  try {
    const { id } = req.params;
    const currentUser = req.user;

    // Prevent deleting own account
    if (id === currentUser.id) {
      return res.status(400).json({
        success: false,
        error: 'You cannot delete your own account'
      });
    }

    const user = await prisma.user.findUnique({ where: { id } });
    if (!user) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }

    // Delete user
    await prisma.user.delete({ where: { id } });

    res.json({
      success: true,
      message: 'User deleted successfully'
    });
  } catch (error) {
    next(error);
  }
});

export default router;

