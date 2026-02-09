// Supabase Configuration - Same as index.html
import { cachedFetch, cacheKeys, invalidateCache } from '@/utils/dataCache';

const SUPABASE_URL = 'https://kexwnurwavszvmlpifsf.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtleHdudXJ3YXZzenZtbHBpZnNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzk5OTksImV4cCI6MjA4MDg1NTk5OX0.w7RlFdXVFdKtqJJ99L0Q1ofzUiwillyy-g1ASEj1q-U';

// Initialize Supabase Client
export let supabaseClient = null;
export let USE_SUPABASE = false;

// Dynamic import of Supabase
export async function initSupabase() {
  if (typeof window !== 'undefined' && !supabaseClient) {
    try {
      const { createClient } = await import('@supabase/supabase-js');
      
      if (SUPABASE_URL && SUPABASE_URL !== 'YOUR_SUPABASE_PROJECT_URL' && 
          SUPABASE_ANON_KEY && SUPABASE_ANON_KEY !== 'YOUR_SUPABASE_ANON_KEY') {
        supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
        // Update exported variables
        window.supabaseClient = supabaseClient;
        USE_SUPABASE = true;
      }
    } catch (error) {
      console.error('Supabase initialization failed:', error);
      USE_SUPABASE = false;
    }
  }
  return supabaseClient;
}

// Ensure Supabase client is ready before any DB call
export async function ensureSupabaseReady() {
  await initSupabase();
  return USE_SUPABASE && supabaseClient;
}

// Initialize on module load (if in browser)
if (typeof window !== 'undefined') {
  initSupabase();
}

// ==================== USER MANAGEMENT FUNCTIONS ====================

/**
 * Get all users from Supabase or localStorage (with caching)
 */
export async function getUsers() {
  return cachedFetch(cacheKeys.users(), async () => {
    if (USE_SUPABASE && supabaseClient) {
      try {
        // Select only needed columns for performance
        const { data, error } = await supabaseClient
          .from('users')
          .select('id,name,email,phone,role,status,profile_photo_url,permissions,notes,created_at,updated_at,last_login,last_activity')
          .order('created_at', { ascending: false });
        
        if (error) {
          console.error('Error fetching users from Supabase:', error);
          return getUsersFromLocalStorage();
        }
        
        return data || [];
      } catch (error) {
        console.error('Exception fetching users from Supabase:', error);
        return getUsersFromLocalStorage();
      }
    } else {
      return getUsersFromLocalStorage();
    }
  }, 60000); // Cache for 60 seconds
}

function getUsersFromLocalStorage() {
  try {
    const users = JSON.parse(localStorage.getItem('sakura_users') || '[]');
    console.log('getUsers() from localStorage - Found users:', users.length);
    return users;
  } catch (error) {
    console.error('Error reading users from localStorage:', error);
    return [];
  }
}

/**
 * Create user in Supabase
 */
export async function createUserInSupabase(userData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // First, check if user already exists
    const { data: existingUser, error: checkError } = await supabaseClient
      .from('users')
      .select('*')
      .eq('email', userData.email.toLowerCase().trim())
      .single();
    
    // If user exists, update password instead of creating new
    if (existingUser && !checkError) {
      console.log('User already exists, updating password...');
      const { data: updatedData, error: updateError } = await supabaseClient
        .from('users')
        .update({
          password_hash: userData.password.trim(),
          name: userData.name.trim(),
          updated_at: new Date().toISOString()
        })
        .eq('email', userData.email.toLowerCase().trim())
        .select()
        .single();
      
      if (updateError) {
        console.error('Error updating user in Supabase:', updateError);
        return { success: false, error: updateError.message };
      }
      
      invalidateCache(cacheKeys.users());
      return { success: true, data: updatedData, updated: true };
    }
    
    // Create new user record in users table
    // Store password in password_hash field (plain text for compatibility with localStorage)
    // Convert role and status to lowercase to match Supabase constraint
    const newUser = {
      email: userData.email.toLowerCase().trim(),
      name: userData.name.trim(),
      password_hash: userData.password.trim(),
      phone: userData.phone || null,
      role: (userData.role || 'user').toLowerCase(),
      status: (userData.status || 'inactive').toLowerCase(),
      permissions: userData.permissions || {
        accountsPayable: false,
        forecasting: false,
        warehouse: false,
        userManagement: false,
        reports: false,
        settings: false
      },
      notes: userData.notes || null,
      profile_photo_url: userData.profile_photo_url || null,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      last_activity: new Date().toISOString()
    };
    
    console.log('📝 Creating user in Supabase:', {
      email: newUser.email,
      name: newUser.name,
      role: newUser.role,
      status: newUser.status
    });
    
    const { data, error } = await supabaseClient
      .from('users')
      .insert([newUser])
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error creating user in Supabase:', error);
      console.error('Error details:', JSON.stringify(error, null, 2));
      return { success: false, error: error.message };
    }
    
    // Invalidate cache after create
    invalidateCache(cacheKeys.users());
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception creating user in Supabase:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update user in Supabase
 */
export async function updateUserInSupabase(userId, updates) {
  if (!USE_SUPABASE || !supabaseClient) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    // Ensure role and status are lowercase if provided
    const updateData = { ...updates };
    if (updateData.role) {
      updateData.role = updateData.role.toLowerCase();
    }
    if (updateData.status) {
      updateData.status = updateData.status.toLowerCase();
    }
    updateData.updated_at = new Date().toISOString();
    
    const { data, error } = await supabaseClient
      .from('users')
      .update(updateData)
      .eq('id', userId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating user in Supabase:', error);
      return { success: false, error: error.message };
    }
    
    // Invalidate cache after update
    invalidateCache(cacheKeys.users());
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception updating user in Supabase:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete user from Supabase
 */
export async function deleteUserFromSupabase(userId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return { success: false, error: 'Supabase not configured' };
  }
  
  try {
    const { error } = await supabaseClient
      .from('users')
      .delete()
      .eq('id', userId);
    
    if (error) {
      console.error('❌ Error deleting user from Supabase:', error);
      return { success: false, error: error.message };
    }
    
    // Invalidate cache after delete
    invalidateCache(cacheKeys.users());
    return { success: true };
  } catch (error) {
    console.error('❌ Exception deleting user from Supabase:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Login with Supabase
 */
export async function loginWithSupabase(email, password) {
  // Ensure Supabase is ready
  const isReady = await ensureSupabaseReady();
  if (!isReady || !supabaseClient) {
    return { success: false, error: 'Supabase not configured or not connected. Please check your internet connection.' };
  }
  
  try {
    const emailToCheck = email.toLowerCase().trim();
    const passwordToCheck = String(password).trim();
    
    console.log('🔍 Login attempt:');
    console.log('  - Email:', emailToCheck);
    console.log('  - Password length:', passwordToCheck.length);
    
    // Get user from users table first
    const { data: userData, error: userError } = await supabaseClient
      .from('users')
      .select('*')
      .eq('email', emailToCheck)
      .single();
    
    // Handle network errors
    if (userError) {
      console.error('❌ Supabase query error:', userError);
      
      // Check for network errors
      if (userError.message?.includes('Failed to fetch') || 
          userError.message?.includes('NetworkError') ||
          userError.code === 'PGRST116' ||
          userError.message?.includes('fetch')) {
        return { 
          success: false, 
          error: 'Network error: Cannot connect to Supabase. Please check your internet connection and try again.' 
        };
      }
      
      // Check for user not found
      if (userError.code === 'PGRST116' || userError.message?.includes('No rows')) {
        return { success: false, error: 'User not found. Please check your email address.' };
      }
      
      return { success: false, error: userError.message || 'User not found' };
    }
    
    if (!userData) {
      console.error('❌ User not found in Supabase');
      return { success: false, error: 'User not found. Please check your email address.' };
    }
    
    console.log('✅ User found in Supabase:');
    console.log('  - ID:', userData.id);
    console.log('  - Name:', userData.name);
    console.log('  - Email:', userData.email);
    console.log('  - Role:', userData.role);
    console.log('  - Status:', userData.status);
    console.log('  - Password hash exists:', !!userData.password_hash);
    console.log('  - Password hash type:', typeof userData.password_hash);
    
    // Compare password (stored in password_hash field)
    const storedPassword = userData.password_hash ? String(userData.password_hash).trim() : '';
    const enteredPassword = passwordToCheck;
    
    console.log('🔐 Password comparison:');
    console.log('  - Stored password length:', storedPassword.length);
    console.log('  - Entered password length:', enteredPassword.length);
    console.log('  - Passwords match:', storedPassword === enteredPassword);
    
    if (storedPassword !== enteredPassword) {
      console.error('❌ Password mismatch');
      return { success: false, error: 'Invalid password' };
    }
    
    // Check user status
    if (userData.status === 'suspended') {
      console.error('❌ User account is suspended');
      return { success: false, error: 'Account is suspended' };
    }
    
    if (userData.status === 'inactive') {
      console.warn('⚠️ User account is inactive (needs admin approval)');
      return { success: false, error: 'Account is inactive. Please wait for admin approval.' };
    }
    
    // Update last login timestamp
    await updateUserInSupabase(userData.id, {
      last_login: new Date().toISOString(),
      last_activity: new Date().toISOString()
    });
    
    console.log('✅ Login successful with Supabase');
    
    // Return user data in expected format
    return {
      success: true,
      user: {
        id: userData.id,
        name: userData.name,
        email: userData.email,
        role: userData.role,
        status: userData.status,
        permissions: userData.permissions || {},
        profilePhotoUrl: userData.profile_photo_url,
        phone: userData.phone,
        createdAt: userData.created_at,
        updatedAt: userData.updated_at,
        lastLogin: userData.last_login,
        lastActivity: userData.last_activity
      }
    };
  } catch (error) {
    console.error('❌ Exception during Supabase login:', error);
    
    // Handle network errors
    if (error.message?.includes('Failed to fetch') || 
        error.message?.includes('NetworkError') ||
        error.name === 'TypeError' && error.message?.includes('fetch')) {
      return { 
        success: false, 
        error: 'Network error: Cannot connect to Supabase. Please check your internet connection and try again.' 
      };
    }
    
    return { success: false, error: error.message || 'Login failed. Please try again.' };
  }
}

// ==================== INVENTORY ITEMS FUNCTIONS ====================

/**
 * Load items from Supabase
 */
export async function loadItemsFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getItemsFromLocalStorage();
  
  try {
    const { data, error } = await supabaseClient
      .from('inventory_items')
      .select('*')
      .eq('deleted', false)
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('❌ Error loading items from Supabase:', error);
      return getItemsFromLocalStorage();
    }
    
    console.log('✅ Items loaded from Supabase:', data?.length || 0);
    return data || [];
  } catch (error) {
    console.error('❌ Exception loading items from Supabase:', error);
    return getItemsFromLocalStorage();
  }
}

function getItemsFromLocalStorage() {
  try {
    return JSON.parse(localStorage.getItem('sakura_inventory_items') || '[]');
  } catch (error) {
    console.error('Error reading items from localStorage:', error);
    return [];
  }
}

/**
 * Save item to Supabase
 */
export async function saveItemToSupabase(item) {
  if (!USE_SUPABASE || !supabaseClient) {
    return saveItemToLocalStorage(item);
  }
  
  try {
    const itemData = {
      ...item,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('inventory_items')
      .insert([itemData])
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error saving item to Supabase:', error);
      return saveItemToLocalStorage(item);
    }
    
    console.log('✅ Item saved to Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception saving item to Supabase:', error);
    return saveItemToLocalStorage(item);
  }
}

function saveItemToLocalStorage(item) {
  try {
    const items = JSON.parse(localStorage.getItem('sakura_inventory_items') || '[]');
    const newItem = {
      ...item,
      id: item.id || Date.now().toString(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    items.push(newItem);
    localStorage.setItem('sakura_inventory_items', JSON.stringify(items));
    return { success: true, data: newItem };
  } catch (error) {
    console.error('Error saving item to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update item in Supabase
 */
export async function updateItemInSupabase(itemId, updates) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updateItemInLocalStorage(itemId, updates);
  }
  
  try {
    const updateData = {
      ...updates,
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('inventory_items')
      .update(updateData)
      .eq('id', itemId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating item in Supabase:', error);
      return updateItemInLocalStorage(itemId, updates);
    }
    
    console.log('✅ Item updated in Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception updating item in Supabase:', error);
    return updateItemInLocalStorage(itemId, updates);
  }
}

function updateItemInLocalStorage(itemId, updates) {
  try {
    const items = JSON.parse(localStorage.getItem('sakura_inventory_items') || '[]');
    const index = items.findIndex(item => item.id === itemId);
    if (index !== -1) {
      items[index] = { ...items[index], ...updates, updated_at: new Date().toISOString() };
      localStorage.setItem('sakura_inventory_items', JSON.stringify(items));
      return { success: true, data: items[index] };
    }
    return { success: false, error: 'Item not found' };
  } catch (error) {
    console.error('Error updating item in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete item from Supabase
 */
export async function deleteItemFromSupabase(itemId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deleteItemFromLocalStorage(itemId);
  }
  
  try {
    const { error } = await supabaseClient
      .from('inventory_items')
      .delete()
      .eq('id', itemId);
    
    if (error) {
      console.error('❌ Error deleting item from Supabase:', error);
      return deleteItemFromLocalStorage(itemId);
    }
    
    console.log('✅ Item deleted from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Exception deleting item from Supabase:', error);
    return deleteItemFromLocalStorage(itemId);
  }
}

function deleteItemFromLocalStorage(itemId) {
  try {
    const items = JSON.parse(localStorage.getItem('sakura_inventory_items') || '[]');
    const filtered = items.filter(item => item.id !== itemId);
    localStorage.setItem('sakura_inventory_items', JSON.stringify(filtered));
    return { success: true };
  } catch (error) {
    console.error('Error deleting item from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Restore item from Supabase (soft delete - set deleted = false)
 */
export async function restoreItemFromSupabase(itemId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return restoreItemFromLocalStorage(itemId);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('inventory_items')
      .update({ 
        deleted: false,
        deleted_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', itemId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error restoring item from Supabase:', error);
      return restoreItemFromLocalStorage(itemId);
    }
    
    console.log('✅ Item restored from Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception restoring item from Supabase:', error);
    return restoreItemFromLocalStorage(itemId);
  }
}

function restoreItemFromLocalStorage(itemId) {
  try {
    const items = JSON.parse(localStorage.getItem('sakura_inventory_items') || '[]');
    const index = items.findIndex(item => item.id === itemId);
    if (index !== -1) {
      items[index] = { ...items[index], deleted: false, deleted_at: null, updated_at: new Date().toISOString() };
      localStorage.setItem('sakura_inventory_items', JSON.stringify(items));
      return { success: true, data: items[index] };
    }
    return { success: false, error: 'Item not found' };
  } catch (error) {
    console.error('Error restoring item from localStorage:', error);
    return { success: false, error: error.message };
  }
}

// ==================== INVENTORY CATEGORIES FUNCTIONS ====================

/**
 * Load categories from Supabase
 */
export async function loadCategoriesFromSupabase() {
  if (!USE_SUPABASE || !supabaseClient) {
    return getCategoriesFromLocalStorage();
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('inventory_categories')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('❌ Error loading categories from Supabase:', error);
      return getCategoriesFromLocalStorage();
    }
    
    console.log('✅ Categories loaded from Supabase:', data?.length || 0);
    return data || [];
  } catch (error) {
    console.error('❌ Exception loading categories from Supabase:', error);
    return getCategoriesFromLocalStorage();
  }
}

function getCategoriesFromLocalStorage() {
  try {
    return JSON.parse(localStorage.getItem('sakura_inventory_categories') || '[]');
  } catch (error) {
    console.error('Error reading categories from localStorage:', error);
    return [];
  }
}

/**
 * Save category to Supabase
 */
export async function saveCategoryToSupabase(category) {
  if (!USE_SUPABASE || !supabaseClient) {
    return saveCategoryToLocalStorage(category);
  }
  
  try {
    const categoryData = {
      ...category,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('inventory_categories')
      .insert([categoryData])
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error saving category to Supabase:', error);
      return saveCategoryToLocalStorage(category);
    }
    
    console.log('✅ Category saved to Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception saving category to Supabase:', error);
    return saveCategoryToLocalStorage(category);
  }
}

function saveCategoryToLocalStorage(category) {
  try {
    const categories = JSON.parse(localStorage.getItem('sakura_inventory_categories') || '[]');
    const newCategory = {
      ...category,
      id: category.id || Date.now().toString(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    categories.push(newCategory);
    localStorage.setItem('sakura_inventory_categories', JSON.stringify(categories));
    return { success: true, data: newCategory };
  } catch (error) {
    console.error('Error saving category to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update category in Supabase
 */
export async function updateCategoryInSupabase(categoryId, updates) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updateCategoryInLocalStorage(categoryId, updates);
  }
  
  try {
    const updateData = {
      ...updates,
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('inventory_categories')
      .update(updateData)
      .eq('id', categoryId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating category in Supabase:', error);
      return updateCategoryInLocalStorage(categoryId, updates);
    }
    
    console.log('✅ Category updated in Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception updating category in Supabase:', error);
    return updateCategoryInLocalStorage(categoryId, updates);
  }
}

function updateCategoryInLocalStorage(categoryId, updates) {
  try {
    const categories = JSON.parse(localStorage.getItem('sakura_inventory_categories') || '[]');
    const index = categories.findIndex(cat => cat.id === categoryId);
    if (index !== -1) {
      categories[index] = { ...categories[index], ...updates, updated_at: new Date().toISOString() };
      localStorage.setItem('sakura_inventory_categories', JSON.stringify(categories));
      return { success: true, data: categories[index] };
    }
    return { success: false, error: 'Category not found' };
  } catch (error) {
    console.error('Error updating category in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete category from Supabase (soft delete)
 */
export async function deleteCategoryFromSupabase(categoryId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deleteCategoryFromLocalStorage(categoryId);
  }
  
  try {
    // Soft delete
    const { error } = await supabaseClient
      .from('inventory_categories')
      .update({ 
        deleted: true,
        deleted_at: new Date().toISOString()
      })
      .eq('id', categoryId);
    
    if (error) {
      console.error('❌ Error deleting category from Supabase:', error);
      return deleteCategoryFromLocalStorage(categoryId);
    }
    
    console.log('✅ Category deleted from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Exception deleting category from Supabase:', error);
    return deleteCategoryFromLocalStorage(categoryId);
  }
}

function deleteCategoryFromLocalStorage(categoryId) {
  try {
    const categories = JSON.parse(localStorage.getItem('sakura_inventory_categories') || '[]');
    const filtered = categories.filter(cat => cat.id !== categoryId);
    localStorage.setItem('sakura_inventory_categories', JSON.stringify(filtered));
    return { success: true };
  } catch (error) {
    console.error('Error deleting category from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Restore category from Supabase
 */
export async function restoreCategoryFromSupabase(categoryId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return restoreCategoryFromLocalStorage(categoryId);
  }
  
  try {
    const { error } = await supabaseClient
      .from('inventory_categories')
      .update({ 
        deleted: false,
        deleted_at: null
      })
      .eq('id', categoryId);
    
    if (error) {
      console.error('❌ Error restoring category from Supabase:', error);
      return restoreCategoryFromLocalStorage(categoryId);
    }
    
    console.log('✅ Category restored from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Exception restoring category from Supabase:', error);
    return restoreCategoryFromLocalStorage(categoryId);
  }
}

function restoreCategoryFromLocalStorage(categoryId) {
  try {
    const categories = JSON.parse(localStorage.getItem('sakura_inventory_categories') || '[]');
    const category = categories.find(cat => cat.id === categoryId);
    if (category) {
      category.deleted = false;
      category.deleted_at = null;
      localStorage.setItem('sakura_inventory_categories', JSON.stringify(categories));
      return { success: true };
    }
    return { success: false, error: 'Category not found' };
  } catch (error) {
    console.error('Error restoring category from localStorage:', error);
    return { success: false, error: error.message };
  }
}

// ==================== DEPARTMENTS FUNCTIONS ====================

/**
 * Load departments from Supabase (single source of truth)
 * ERP rule: Department dropdown must come from DB, not hardcoded.
 */
export async function loadDepartmentsFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getDepartmentsFromLocalStorage();

  try {
    const { data, error } = await supabaseClient
      .from('departments')
      .select('*')
      .eq('is_active', true)
      .order('name', { ascending: true });

    if (error) {
      console.warn('⚠️ departments table not found or error, using fallback:', error.message);
      return getDepartmentsFromLocalStorage();
    }

    if (data?.length) {
      console.log('✅ Departments loaded from Supabase:', data.length);
      return data;
    }
    return getDepartmentsFromLocalStorage();
  } catch (error) {
    console.error('❌ Exception loading departments:', error);
    return getDepartmentsFromLocalStorage();
  }
}

function getDepartmentsFromLocalStorage() {
  try {
    const stored = localStorage.getItem('sakura_departments');
    if (stored) return JSON.parse(stored);
    return [
      { id: null, code: 'PROC', name: 'Procurement' },
      { id: null, code: 'KIT', name: 'Kitchen' },
      { id: null, code: 'WH', name: 'Warehouse' },
      { id: null, code: 'OPS', name: 'Operations' },
      { id: null, code: 'ADMIN', name: 'Administration' },
      { id: null, code: 'FIN', name: 'Finance' },
      { id: null, code: 'IT', name: 'IT' },
      { id: null, code: 'PROD', name: 'Production' },
      { id: null, code: 'QC', name: 'Quality Control' },
      { id: null, code: 'SALES', name: 'Sales' }
    ];
  } catch (error) {
    return [];
  }
}

// ==================== SUPPLIERS FUNCTIONS ====================

/**
 * Load suppliers from Supabase — SINGLE SOURCE OF TRUTH.
 * NO localStorage, NO slice(20), NO fallback. Supabase only.
 */
export async function loadSuppliersFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return [];
  
  try {
    const { data, error } = await supabaseClient
      .from('suppliers')
      .select('*')
      .eq('deleted', false)
      .order('name', { ascending: true });
    
    if (error) {
      console.error('❌ Error loading suppliers from Supabase:', error);
      return [];
    }
    
    return data || [];
  } catch (error) {
    console.error('❌ Exception loading suppliers from Supabase:', error);
    return [];
  }
}

function getSuppliersFromLocalStorage() {
  try {
    const stored = localStorage.getItem('sakura_suppliers') || localStorage.getItem('suppliers');
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    console.error('Error loading suppliers from localStorage:', error);
    return [];
  }
}

/**
 * Save supplier to Supabase
 */
export async function saveSupplierToSupabase(supplierData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return saveSupplierToLocalStorage(supplierData);
  }
  
  try {
    const insertData = {
      name: supplierData.name,
      name_localized: supplierData.nameLocalized || supplierData.name_localized || supplierData.name,
      code: supplierData.code || null,
      contact_name: supplierData.contactName || supplierData.contact_name || null,
      phone: supplierData.phone || null,
      primary_email: supplierData.primaryEmail || supplierData.primary_email || null,
      additional_emails: supplierData.additionalEmails || supplierData.additional_emails || null,
      address: supplierData.address || null,
      city: supplierData.city || null,
      state: supplierData.state || null,
      country: supplierData.country || null,
      postal_code: supplierData.postalCode || supplierData.postal_code || null,
      tax_id: supplierData.taxId || supplierData.tax_id || null,
      payment_terms: supplierData.paymentTerms || supplierData.payment_terms || 30,
      credit_limit: supplierData.creditLimit || supplierData.credit_limit || 0,
      currency: supplierData.currency || 'SAR',
      website: supplierData.website || null,
      notes: supplierData.notes || null,
      deleted: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('suppliers')
      .insert(insertData)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error saving supplier to Supabase:', error);
      return saveSupplierToLocalStorage(supplierData);
    }
    
    console.log('✅ Supplier saved to Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception saving supplier to Supabase:', error);
    return saveSupplierToLocalStorage(supplierData);
  }
}

function saveSupplierToLocalStorage(supplierData) {
  try {
    const stored = localStorage.getItem('suppliers');
    const suppliers = stored ? JSON.parse(stored) : [];
    const newSupplier = {
      ...supplierData,
      id: supplierData.id || `supplier-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      createdAt: supplierData.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      deleted: false
    };
    suppliers.push(newSupplier);
    localStorage.setItem('suppliers', JSON.stringify(suppliers));
    return { success: true, data: newSupplier };
  } catch (error) {
    console.error('Error saving supplier to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update supplier in Supabase
 */
export async function updateSupplierInSupabase(supplierId, supplierData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updateSupplierInLocalStorage(supplierId, supplierData);
  }
  
  try {
    const updateData = {
      name: supplierData.name,
      name_localized: supplierData.nameLocalized || supplierData.name_localized || supplierData.name,
      code: supplierData.code || null,
      contact_name: supplierData.contactName || supplierData.contact_name || null,
      phone: supplierData.phone || null,
      primary_email: supplierData.primaryEmail || supplierData.primary_email || null,
      additional_emails: supplierData.additionalEmails || supplierData.additional_emails || null,
      address: supplierData.address || null,
      city: supplierData.city || null,
      state: supplierData.state || null,
      country: supplierData.country || null,
      postal_code: supplierData.postalCode || supplierData.postal_code || null,
      tax_id: supplierData.taxId || supplierData.tax_id || null,
      payment_terms: supplierData.paymentTerms || supplierData.payment_terms || 30,
      credit_limit: supplierData.creditLimit || supplierData.credit_limit || 0,
      currency: supplierData.currency || 'SAR',
      website: supplierData.website || null,
      notes: supplierData.notes || null,
      updated_at: new Date().toISOString()
    };
    
    const { data, error } = await supabaseClient
      .from('suppliers')
      .update(updateData)
      .eq('id', supplierId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating supplier in Supabase:', error);
      return updateSupplierInLocalStorage(supplierId, supplierData);
    }
    
    console.log('✅ Supplier updated in Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception updating supplier in Supabase:', error);
    return updateSupplierInLocalStorage(supplierId, supplierData);
  }
}

function updateSupplierInLocalStorage(supplierId, supplierData) {
  try {
    const stored = localStorage.getItem('suppliers');
    const suppliers = stored ? JSON.parse(stored) : [];
    const index = suppliers.findIndex(s => s.id === supplierId);
    if (index !== -1) {
      suppliers[index] = {
        ...suppliers[index],
        ...supplierData,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('suppliers', JSON.stringify(suppliers));
      return { success: true, data: suppliers[index] };
    }
    return { success: false, error: 'Supplier not found' };
  } catch (error) {
    console.error('Error updating supplier in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete supplier from Supabase (soft delete)
 */
export async function deleteSupplierFromSupabase(supplierId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deleteSupplierFromLocalStorage(supplierId);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('suppliers')
      .update({ 
        deleted: true,
        deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', supplierId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error deleting supplier from Supabase:', error);
      return deleteSupplierFromLocalStorage(supplierId);
    }
    
    console.log('✅ Supplier deleted from Supabase');
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception deleting supplier from Supabase:', error);
    return deleteSupplierFromLocalStorage(supplierId);
  }
}

function deleteSupplierFromLocalStorage(supplierId) {
  try {
    const stored = localStorage.getItem('suppliers');
    const suppliers = stored ? JSON.parse(stored) : [];
    const index = suppliers.findIndex(s => s.id === supplierId);
    if (index !== -1) {
      suppliers[index] = {
        ...suppliers[index],
        deleted: true,
        deletedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('suppliers', JSON.stringify(suppliers));
      return { success: true, data: suppliers[index] };
    }
    return { success: false, error: 'Supplier not found' };
  } catch (error) {
    console.error('Error deleting supplier from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Restore supplier from Supabase (soft delete - set deleted = false)
 */
export async function restoreSupplierFromSupabase(supplierId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return restoreSupplierFromLocalStorage(supplierId);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('suppliers')
      .update({ 
        deleted: false,
        deleted_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', supplierId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error restoring supplier from Supabase:', error);
      return restoreSupplierFromLocalStorage(supplierId);
    }
    
    console.log('✅ Supplier restored from Supabase:', data);
    return { success: true, data };
  } catch (error) {
    console.error('❌ Exception restoring supplier from Supabase:', error);
    return restoreSupplierFromLocalStorage(supplierId);
  }
}

function restoreSupplierFromLocalStorage(supplierId) {
  try {
    const stored = localStorage.getItem('suppliers');
    const suppliers = stored ? JSON.parse(stored) : [];
    const index = suppliers.findIndex(s => s.id === supplierId);
    if (index !== -1) {
      suppliers[index] = {
        ...suppliers[index],
        deleted: false,
        deletedAt: null,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('suppliers', JSON.stringify(suppliers));
      return { success: true, data: suppliers[index] };
    }
    return { success: false, error: 'Supplier not found' };
  } catch (error) {
    console.error('Error restoring supplier from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Import suppliers to Supabase (bulk import)
 * Similar to importItemsToSupabase for items
 */
export async function importSuppliersToSupabase(suppliers) {
  if (!USE_SUPABASE || !supabaseClient) {
    console.warn('Supabase not configured, falling back to localStorage');
    // Fallback to localStorage
    const stored = localStorage.getItem('suppliers');
    const existingSuppliers = stored ? JSON.parse(stored) : [];
    suppliers.forEach(supplier => {
      const exists = existingSuppliers.find(s => 
        s.name && supplier.name && 
        s.name.toLowerCase() === supplier.name.toLowerCase() &&
        !s.deleted
      );
      if (!exists) {
        existingSuppliers.push({
          ...supplier,
          id: supplier.id || `supplier-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
          deleted: false
        });
      }
    });
    localStorage.setItem('suppliers', JSON.stringify(existingSuppliers));
    return { success: true, imported: suppliers.length };
  }
  
  try {
    // Import suppliers in batches to avoid timeout
    const batchSize = 50;
    let successCount = 0;
    let errorCount = 0;
    const errors = [];
    
    for (let i = 0; i < suppliers.length; i += batchSize) {
      const batch = suppliers.slice(i, i + batchSize);
      
      // Remove validation metadata before inserting
      const batchToInsert = batch.map(supplier => {
        const { rowNumber, issues, hasIssues, ...supplierData } = supplier;
        
        // Ensure all required fields are present and valid
        if (!supplierData.name || supplierData.name.trim() === '') {
          throw new Error(`Supplier at row ${supplier.rowNumber} missing name`);
        }
        
        // Map to Supabase column names
        const insertData = {
          name: supplierData.name.trim(),
          name_localized: supplierData.nameLocalized || supplierData.name_localized || supplierData.name.trim(),
          code: supplierData.code || supplierData.code || null,
          contact_name: supplierData.contactName || supplierData.contact_name || null,
          phone: supplierData.phone || null,
          primary_email: supplierData.primaryEmail || supplierData.primary_email || null,
          additional_emails: supplierData.additionalEmails || supplierData.additional_emails || null,
          address: supplierData.address || null,
          city: supplierData.city || null,
          state: supplierData.state || null,
          country: supplierData.country || null,
          postal_code: supplierData.postalCode || supplierData.postal_code || null,
          tax_id: supplierData.taxId || supplierData.tax_id || null,
          payment_terms: supplierData.paymentTerms || supplierData.payment_terms || 30,
          credit_limit: supplierData.creditLimit || supplierData.credit_limit || 0,
          currency: supplierData.currency || 'SAR',
          website: supplierData.website || null,
          notes: supplierData.notes || null,
          deleted: false,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        };
        
        return insertData;
      });
      
      const { data, error } = await supabaseClient
        .from('suppliers')
        .insert(batchToInsert)
        .select();
      
      if (error) {
        console.error('Error importing supplier batch:', error);
        console.error('Batch data:', batchToInsert);
        errorCount += batch.length;
        errors.push({
          batch: Math.floor(i / batchSize) + 1,
          error: error.message,
          details: error.details || '',
          hint: error.hint || '',
          suppliers: batch.map(s => `${s.name || 'Unknown'}`).join(', ')
        });
      } else {
        successCount += data ? data.length : 0;
      }
    }
    
    return {
      success: successCount > 0,
      imported: successCount,
      failed: errorCount,
      errors: errors
    };
  } catch (error) {
    console.error('Error importing suppliers:', error);
    return {
      success: false,
      imported: 0,
      failed: suppliers.length,
      errors: [{ error: error.message }]
    };
  }
}

// ==================== PURCHASE ORDERS FUNCTIONS ====================

/**
 * Generate next PO number
 */
async function generatePONumber() {
  try {
    // First try to get from Supabase
    if (USE_SUPABASE && supabaseClient) {
      // Get all existing PO numbers (excluding drafts and nulls)
      const { data, error } = await supabaseClient
        .from('purchase_orders')
        .select('po_number')
        .not('po_number', 'is', null)
        .neq('po_number', '')
        .not('po_number', 'like', 'DRAFT-%') // Exclude draft numbers
        .order('created_at', { ascending: false });
      
      if (!error && data) {
        // Extract all PO numbers and find the maximum
        let maxNumber = 0;
        data.forEach(order => {
          const poNum = order.po_number;
          if (poNum && !poNum.startsWith('DRAFT-')) {
            const num = parseInt(poNum.replace('PO-', '')) || 0;
            if (num > maxNumber) {
              maxNumber = num;
            }
          }
        });
        
        // Generate next number and verify it doesn't exist
        let nextNumber = maxNumber + 1;
        let attempts = 0;
        const maxAttempts = 100; // Prevent infinite loop
        
        while (attempts < maxAttempts) {
          const candidatePO = `PO-${String(nextNumber).padStart(6, '0')}`;
          
          // Check if this PO number already exists
          const { data: existing } = await supabaseClient
            .from('purchase_orders')
            .select('id')
            .eq('po_number', candidatePO)
            .limit(1);
          
          if (!existing || existing.length === 0) {
            // PO number is available
            console.log('✅ Generated unique PO number:', candidatePO);
            return candidatePO;
          }
          
          // PO number exists, try next
          nextNumber++;
          attempts++;
        }
        
        // If we exhausted attempts, use timestamp-based fallback
        console.warn('⚠️ Could not generate sequential PO number, using timestamp fallback');
        return `PO-${String(Date.now()).slice(-6).padStart(6, '0')}`;
      }
    }
    
    // Fallback to localStorage
    const stored = localStorage.getItem('purchase_orders');
    const orders = stored ? JSON.parse(stored) : [];
    
    // Filter out orders without PO numbers (drafts)
    const ordersWithPO = orders.filter(o => (o.poNumber || o.po_number) && (o.poNumber || o.po_number) !== '');
    
    if (ordersWithPO.length === 0) {
      return 'PO-000001';
    }
    
    // Get the highest PO number
    let maxNumber = 0;
    ordersWithPO.forEach(order => {
      const poNum = order.poNumber || order.po_number;
      if (poNum) {
        const num = parseInt(poNum.replace('PO-', '')) || 0;
        if (num > maxNumber) {
          maxNumber = num;
        }
      }
    });
    
    const nextNumber = maxNumber + 1;
    return `PO-${String(nextNumber).padStart(6, '0')}`;
  } catch (error) {
    console.error('Error generating PO number:', error);
    // Fallback: return a timestamp-based PO number
    return `PO-${String(Date.now()).slice(-6).padStart(6, '0')}`;
  }
}

/**
 * Load all purchase orders from Supabase or localStorage
 */
export async function loadPurchaseOrdersFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getPurchaseOrdersFromLocalStorage();
  
  try {
    const { data, error } = await supabaseClient
      .from('purchase_orders')
      .select(`
        *,
        supplier:suppliers(*)
      `)
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('❌ Error loading purchase orders from Supabase:', error);
      return getPurchaseOrdersFromLocalStorage();
    }
    
    // Load items for each order
    // CRITICAL: Convert order.id to string for UUID comparison
    // FIXED: Handle missing FK relationship by loading items separately if relationship query fails
    const ordersWithItems = await Promise.all(
      data.map(async (order) => {
        const orderId = String(order.id).trim(); // Ensure UUID string format
        
        // First try with relationship (if FK exists)
        let { data: items, error: itemsError } = await supabaseClient
          .from('purchase_order_items')
          .select(`
            *,
            item:inventory_items(*)
          `)
          .eq('purchase_order_id', orderId);
        
        // If relationship query fails (PGRST200), load items separately
        if (itemsError && itemsError.code === 'PGRST200') {
          console.warn(`⚠️ FK relationship not found for PO ${order.po_number || order.id}, loading items separately...`);
          
          // Load items without relationship
          const { data: itemsWithoutRel, error: itemsErrorWithoutRel } = await supabaseClient
            .from('purchase_order_items')
            .select('*')
            .eq('purchase_order_id', orderId);
          
          if (itemsErrorWithoutRel) {
            console.error(`❌ Error loading items for PO ${order.po_number || order.id}:`, itemsErrorWithoutRel);
            return { ...order, items: [] };
          }
          
          // Load inventory items separately and map them
          if (itemsWithoutRel && itemsWithoutRel.length > 0) {
            const itemIds = itemsWithoutRel
              .map(item => item.item_id)
              .filter(id => id !== null && id !== undefined);
            
            if (itemIds.length > 0) {
              const { data: inventoryItems } = await supabaseClient
                .from('inventory_items')
                .select('*')
                .in('id', itemIds);
              
              // Map inventory items to PO items
              items = itemsWithoutRel.map(poItem => ({
                ...poItem,
                item: inventoryItems?.find(inv => inv.id === poItem.item_id) || null
              }));
            } else {
              items = itemsWithoutRel;
            }
          } else {
            items = itemsWithoutRel || [];
          }
        } else if (itemsError) {
          console.error(`❌ Error loading items for PO ${order.po_number || order.id}:`, itemsError);
          console.error(`   PO ID: ${orderId}, Type: ${typeof orderId}`);
          return { ...order, items: [] };
        }
        
        return { ...order, items: items || [] };
      })
    );
    
    console.log('✅ Purchase orders loaded from Supabase:', ordersWithItems.length);
    return ordersWithItems;
  } catch (error) {
    console.error('❌ Exception loading purchase orders from Supabase:', error);
    return getPurchaseOrdersFromLocalStorage();
  }
}

function getPurchaseOrdersFromLocalStorage() {
  try {
    const stored = localStorage.getItem('purchase_orders');
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    console.error('Error loading purchase orders from localStorage:', error);
    return [];
  }
}

/**
 * Save purchase order to Supabase or localStorage
 */
export async function savePurchaseOrderToSupabase(orderData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return savePurchaseOrderToLocalStorage(orderData);
  }
  
  try {
    const { items, supplier, ...orderFields } = orderData;
    
    // Map frontend field names to database column names (snake_case)
    // Note: created_by should be UUID/BIGINT (user ID), not username string
    // For now, we'll set it to null if it's a string (username)
    let createdByValue = null;
    if (orderFields.createdBy || orderFields.created_by) {
      const createdBy = orderFields.createdBy || orderFields.created_by;
      // Check if it's a UUID format or numeric (BIGINT)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (uuidRegex.test(createdBy) || /^\d+$/.test(createdBy)) {
        createdByValue = createdBy;
      }
      // If it's a username string, we'll leave it as null
      // You can add a users table lookup here if needed
    }
    
    // Validate and convert supplier_id
    let supplierIdValue = null;
    const supplierId = orderFields.supplierId || orderFields.supplier_id;
    if (supplierId) {
      // Check if it's a valid UUID or numeric (BIGINT)
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (uuidRegex.test(supplierId) || /^\d+$/.test(supplierId)) {
        supplierIdValue = supplierId;
      } else {
        console.warn('⚠️ Invalid supplier_id format:', supplierId);
      }
    }
    
    const insertData = {
      supplier_id: supplierIdValue,
      supplier_name: orderFields.supplierName || orderFields.supplier_name || null,
      destination: orderFields.destination || null,
      status: orderFields.status || 'draft', // Default to 'draft' for new orders
      business_date: orderFields.businessDate || orderFields.business_date || (orderFields.orderDate ? new Date(orderFields.orderDate).toISOString().split('T')[0] : null),
      order_date: orderFields.orderDate || orderFields.order_date ? new Date(orderFields.orderDate).toISOString() : new Date().toISOString(),
      expected_date: orderFields.expectedDate || orderFields.expected_date ? new Date(orderFields.expectedDate).toISOString() : null,
      total_amount: parseFloat(orderFields.totalAmount || orderFields.total_amount || 0),
      vat_amount: parseFloat(orderFields.vatAmount || orderFields.vat_amount || 0),
      notes: orderFields.notes || null,
      created_by: createdByValue, // Only set if it's a valid UUID or BIGINT
      deleted: false,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    
    // PO number handling: For drafts, generate a temporary draft number
    // This will be replaced with a proper PO number when submitted
    if (orderFields.poNumber || orderFields.po_number) {
      insertData.po_number = orderFields.poNumber || orderFields.po_number;
    } else if (insertData.status === 'draft') {
      // Generate a temporary draft PO number (will be replaced on submit)
      // Format: DRAFT-{timestamp} to ensure uniqueness
      const timestamp = Date.now();
      insertData.po_number = `DRAFT-${timestamp}`;
    } else {
      // For non-draft orders, generate a proper PO number
      // Call generatePONumber function (defined in this file)
      insertData.po_number = await generatePONumber();
    }
    
    // Remove any undefined values that might cause issues
    Object.keys(insertData).forEach(key => {
      if (insertData[key] === undefined) {
        delete insertData[key];
      }
    });
    
    // Log the data being inserted for debugging
    console.log('📝 Inserting purchase order data:', JSON.stringify(insertData, null, 2));
    
    // Create order
    const { data: order, error: orderError } = await supabaseClient
      .from('purchase_orders')
      .insert([insertData])
      .select()
      .single();
    
    if (orderError) {
      console.error('❌ Error saving purchase order to Supabase:', orderError);
      console.error('❌ Error details:', {
        message: orderError.message,
        details: orderError.details,
        hint: orderError.hint,
        code: orderError.code
      });
      console.error('❌ Data that failed to insert:', JSON.stringify(insertData, null, 2));
      // Return error instead of falling back to localStorage
      return { 
        success: false, 
        error: orderError.message || 'Failed to save purchase order',
        details: orderError.details,
        hint: orderError.hint
      };
    }
    
    // Create order items
    if (items && items.length > 0) {
      const orderItems = items.map(item => {
        // CRITICAL: Get item_id from multiple possible sources
        const itemId = item.itemId || item.item_id || (item.item && item.item.id) || null;
        
        if (!itemId) {
          console.error('❌ PO Item missing item_id!', item);
        }
        
        return {
          purchase_order_id: order.id,
          item_id: itemId, // CRITICAL: Must be set for foreign key relationship
          quantity: item.quantity || 0,
          unit_price: item.unitPrice || item.unit_price || 0,
          vat_rate: item.vatRate || item.vat_rate || 0,
          vat_amount: item.vatAmount || item.vat_amount || 0,
          total_amount: item.totalAmount || item.total_amount || 0,
          batch_number: item.batchNumber || item.batch_number || null,
          expiry_date: item.expiryDate || item.expiry_date || null
        };
      });
      
      console.log('📦 Saving PO items:', orderItems.length, 'items');
      console.log('📦 First PO item sample:', {
        purchase_order_id: orderItems[0]?.purchase_order_id,
        item_id: orderItems[0]?.item_id,
        quantity: orderItems[0]?.quantity
      });
      
      const { data: insertedItems, error: itemsError } = await supabaseClient
        .from('purchase_order_items')
        .insert(orderItems)
        .select();
      
      if (itemsError) {
        console.error('❌ Error saving purchase order items to Supabase:', itemsError);
        console.error('❌ Items error details:', {
          message: itemsError.message,
          details: itemsError.details,
          hint: itemsError.hint,
          code: itemsError.code
        });
        console.error('❌ Items that failed to insert:', JSON.stringify(orderItems, null, 2));
        // Still return the order even if items failed
      } else {
        console.log('✅ PO items saved successfully:', insertedItems?.length || orderItems.length, 'items');
      }
    }
    
    // Reload order with items - Try with relationship first, fallback if needed
    // First get the order with supplier relationship
    const { data: orderWithSupplier, error: supplierReloadError } = await supabaseClient
      .from('purchase_orders')
      .select(`
        *,
        supplier:suppliers(*)
      `)
      .eq('id', order.id)
      .single();
    
    // Then get items separately WITH item relationship (fallback if it fails)
    let orderItems = null;
    let itemsReloadError = null;
    
    // Try with relationship first
    const { data: itemsWithRel, error: itemsErrorWithRel } = await supabaseClient
      .from('purchase_order_items')
      .select(`
        *,
        item:inventory_items(*)
      `)
      .eq('purchase_order_id', order.id);
    
    if (itemsErrorWithRel) {
      console.warn('⚠️ Error loading items with relationship, trying without:', itemsErrorWithRel);
      // Fallback: Load without relationship
      const { data: itemsWithoutRel, error: itemsErrorWithoutRel } = await supabaseClient
        .from('purchase_order_items')
        .select('*')
        .eq('purchase_order_id', order.id);
      
      if (itemsErrorWithoutRel) {
        console.error('❌ Error reloading purchase order items:', itemsErrorWithoutRel);
        itemsReloadError = itemsErrorWithoutRel;
        orderItems = [];
      } else {
        orderItems = itemsWithoutRel || [];
        // Manually load item relationships if needed
        if (orderItems.length > 0 && !orderItems[0].item) {
          const itemIds = orderItems.map(poItem => poItem.item_id).filter(id => id);
          if (itemIds.length > 0) {
            const { data: inventoryItems } = await supabaseClient
              .from('inventory_items')
              .select('*')
              .in('id', itemIds);
            
            if (inventoryItems) {
              orderItems.forEach(poItem => {
                const invItem = inventoryItems.find(inv => inv.id === poItem.item_id);
                if (invItem) poItem.item = invItem;
              });
            }
          }
        }
      }
    } else {
      orderItems = itemsWithRel || [];
    }
    
    if (supplierReloadError) {
      console.error('❌ Error reloading purchase order with supplier:', supplierReloadError);
    }
    
    // Combine the data
    const fullOrder = orderWithSupplier || order;
    if (orderItems) {
      fullOrder.items = orderItems;
      console.log('✅ Reloaded PO with', orderItems.length, 'items');
      if (orderItems.length > 0) {
        console.log('✅ First reloaded item:', {
          itemId: orderItems[0].item_id,
          hasItem: !!orderItems[0].item,
          itemName: orderItems[0].item?.name
        });
      }
    } else {
      fullOrder.items = [];
    }
    
    // If supplier relationship didn't load, manually add it
    if (!fullOrder.supplier && fullOrder.supplier_id && supplier) {
      fullOrder.supplier = supplier;
    }
    
    console.log('✅ Purchase order saved to Supabase');
    return { success: true, data: fullOrder };
  } catch (error) {
    console.error('❌ Exception saving purchase order to Supabase:', error);
    return savePurchaseOrderToLocalStorage(orderData);
  }
}

function savePurchaseOrderToLocalStorage(orderData) {
  try {
    const stored = localStorage.getItem('purchase_orders');
    const orders = stored ? JSON.parse(stored) : [];
    
    const newOrder = {
      id: orderData.id || `po-${Date.now()}`,
      ...orderData,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    orders.push(newOrder);
    localStorage.setItem('purchase_orders', JSON.stringify(orders));
    return { success: true, data: newOrder };
  } catch (error) {
    console.error('Error saving purchase order to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update purchase order in Supabase or localStorage
 */
function safeDateISO(val) {
  if (val == null || val === '') return null;
  try {
    const d = new Date(val);
    return isNaN(d.getTime()) ? null : d.toISOString();
  } catch { return null; }
}
function safeDateOnly(val) {
  const iso = safeDateISO(val);
  return iso ? iso.split('T')[0] : null;
}

export async function updatePurchaseOrderInSupabase(orderId, orderData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updatePurchaseOrderInLocalStorage(orderId, orderData);
  }
  
  try {
    const { items, supplier, ...orderFields } = orderData;
    
    // Map frontend field names to database column names (snake_case)
    const updateData = {
      supplier_id: orderFields.supplierId || orderFields.supplier_id || null,
      supplier_name: orderFields.supplierName || orderFields.supplier_name || null,
      destination: orderFields.destination || null,
      status: orderFields.status || null,
      business_date: orderFields.businessDate || orderFields.business_date || safeDateOnly(orderFields.orderDate),
      order_date: safeDateISO(orderFields.orderDate || orderFields.order_date),
      expected_date: safeDateISO(orderFields.expectedDate || orderFields.expected_date),
      total_amount: orderFields.totalAmount !== undefined ? parseFloat(orderFields.totalAmount || 0) : null,
      vat_amount: orderFields.vatAmount !== undefined ? parseFloat(orderFields.vatAmount || 0) : null,
      notes: orderFields.notes || null,
      updated_at: new Date().toISOString()
    };
    
    // PO number handling - replace DRAFT- prefix with proper PO number if needed
    if (orderFields.poNumber || orderFields.po_number) {
      let poNumber = orderFields.poNumber || orderFields.po_number;
      // If it's a DRAFT- number, generate a proper PO number
      if (poNumber && poNumber.startsWith('DRAFT-')) {
        poNumber = await generatePONumber();
      }
      updateData.po_number = poNumber;
    }
    
    // Remove undefined values
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });
    
    // Log the data being updated for debugging
    console.log('📝 Updating purchase order data:', JSON.stringify(updateData, null, 2));
    
    // Update order
    const { data: order, error: orderError } = await supabaseClient
      .from('purchase_orders')
      .update(updateData)
      .eq('id', orderId)
      .select()
      .single();
    
    if (orderError) {
      console.error('❌ Error updating purchase order in Supabase:', orderError);
      console.error('❌ Error details:', {
        message: orderError.message,
        details: orderError.details,
        hint: orderError.hint,
        code: orderError.code
      });
      return { 
        success: false, 
        error: orderError.message || 'Failed to update purchase order',
        details: orderError.details,
        hint: orderError.hint
      };
    }
    
    // Update items (delete old, insert new)
    if (items) {
      // Delete existing items
      await supabaseClient
        .from('purchase_order_items')
        .delete()
        .eq('purchase_order_id', orderId);
      
      // Insert new items
      if (items.length > 0) {
        const orderItems = items.map(item => {
          // CRITICAL: Get item_id from multiple possible sources (same logic as savePurchaseOrderToSupabase)
          const itemId = item.itemId || item.item_id || (item.item && item.item.id) || null;
          
          if (!itemId) {
            console.error('❌ PO Item missing item_id during update!', item);
          }
          
          return {
          purchase_order_id: orderId,
            item_id: itemId, // CRITICAL: Must be set for foreign key relationship
            quantity: item.quantity || 0,
            unit_price: item.unitPrice || item.unit_price || 0,
            vat_rate: item.vatRate || item.vat_rate || 0,
            vat_amount: item.vatAmount || item.vat_amount || 0,
            total_amount: item.totalAmount || item.total_amount || 0,
            batch_number: item.batchNumber || item.batch_number || null,
            expiry_date: item.expiryDate || item.expiry_date || null
          };
        });
        
        console.log('📦 Updating PO items:', orderItems.length, 'items');
        console.log('📦 First PO item sample:', {
          purchase_order_id: orderItems[0]?.purchase_order_id,
          item_id: orderItems[0]?.item_id,
          quantity: orderItems[0]?.quantity
        });
        
        const { data: insertedItems, error: itemsError } = await supabaseClient
          .from('purchase_order_items')
          .insert(orderItems)
          .select();
        
        if (itemsError) {
          console.error('❌ Error updating purchase order items in Supabase:', itemsError);
          console.error('❌ Items error details:', {
            message: itemsError.message,
            details: itemsError.details,
            hint: itemsError.hint,
            code: itemsError.code
          });
          console.error('❌ Items that failed to insert:', JSON.stringify(orderItems, null, 2));
        } else {
          console.log('✅ PO items updated successfully:', insertedItems?.length || orderItems.length, 'items');
        }
      }
    }
    
    // Reload order with supplier (simplified query)
    const { data: orderWithSupplier, error: supplierReloadError } = await supabaseClient
      .from('purchase_orders')
      .select(`
        *,
        supplier:suppliers(*)
      `)
      .eq('id', orderId)
      .single();
    
    // Load items separately WITH item relationship - CRITICAL for displaying item names/SKUs
    const { data: orderItems, error: itemsReloadError } = await supabaseClient
      .from('purchase_order_items')
      .select(`
        *,
        item:inventory_items(*)
      `)
      .eq('purchase_order_id', orderId);
    
    if (supplierReloadError) {
      console.error('❌ Error reloading purchase order with supplier:', supplierReloadError);
    }
    
    if (itemsReloadError) {
      console.error('❌ Error reloading purchase order items:', itemsReloadError);
      console.error('❌ Items reload error details:', {
        message: itemsReloadError.message,
        details: itemsReloadError.details,
        hint: itemsReloadError.hint
      });
    }
    
    // Combine the data
    const fullOrder = orderWithSupplier || order;
    if (orderItems && orderItems.length > 0) {
      fullOrder.items = orderItems;
      console.log('✅ Reloaded PO items with item relationships:', orderItems.length, 'items');
      // Log first item to verify item relationship is loaded
      if (orderItems[0]) {
        console.log('✅ First item sample:', {
          itemId: orderItems[0].item_id,
          itemName: orderItems[0].item?.name,
          itemSku: orderItems[0].item?.sku,
          hasItem: !!orderItems[0].item
        });
      }
    } else {
      fullOrder.items = [];
      console.warn('⚠️ No items reloaded for PO:', orderId);
    }
    
    // If supplier relationship didn't load, manually add it
    if (!fullOrder.supplier && fullOrder.supplier_id && supplier) {
      fullOrder.supplier = supplier;
    } else if (!fullOrder.supplier && fullOrder.supplier_id) {
      // Try to load supplier manually
      const { data: supplierData, error: supplierError } = await supabaseClient
        .from('suppliers')
        .select('*')
        .eq('id', fullOrder.supplier_id)
        .single();
      
      if (!supplierError && supplierData) {
        fullOrder.supplier = supplierData;
      }
    }
    
    console.log('✅ Purchase order updated in Supabase');
    return { success: true, data: fullOrder };
  } catch (error) {
    console.error('❌ Exception updating purchase order in Supabase:', error);
    return updatePurchaseOrderInLocalStorage(orderId, orderData);
  }
}

function updatePurchaseOrderInLocalStorage(orderId, orderData) {
  try {
    const stored = localStorage.getItem('purchase_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const index = orders.findIndex(o => o.id === orderId);
    
    if (index !== -1) {
      orders[index] = {
        ...orders[index],
        ...orderData,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('purchase_orders', JSON.stringify(orders));
      return { success: true, data: orders[index] };
    }
    return { success: false, error: 'Purchase order not found' };
  } catch (error) {
    console.error('Error updating purchase order in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete purchase order from Supabase or localStorage
 */
export async function deletePurchaseOrderFromSupabase(orderId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deletePurchaseOrderFromLocalStorage(orderId);
  }
  
  try {
    // Delete items first (cascade should handle this, but being explicit)
    await supabaseClient
      .from('purchase_order_items')
      .delete()
      .eq('purchase_order_id', orderId);
    
    // Delete order
    const { error } = await supabaseClient
      .from('purchase_orders')
      .delete()
      .eq('id', orderId);
    
    if (error) {
      console.error('❌ Error deleting purchase order from Supabase:', error);
      return deletePurchaseOrderFromLocalStorage(orderId);
    }
    
    console.log('✅ Purchase order deleted from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Exception deleting purchase order from Supabase:', error);
    return deletePurchaseOrderFromLocalStorage(orderId);
  }
}

function deletePurchaseOrderFromLocalStorage(orderId) {
  try {
    const stored = localStorage.getItem('purchase_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const filtered = orders.filter(o => o.id !== orderId);
    localStorage.setItem('purchase_orders', JSON.stringify(filtered));
    return { success: true };
  } catch (error) {
    console.error('Error deleting purchase order from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Get single purchase order by ID
 */
export async function getPurchaseOrderById(orderId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return getPurchaseOrderByIdFromLocalStorage(orderId);
  }
  
  try {
    // Load order with supplier (simplified query)
    // CRITICAL: Include total_received_quantity, remaining_quantity, ordered_quantity for PO tracking
    const { data: orderData, error: orderError } = await supabaseClient
      .from('purchase_orders')
      .select(`
        *,
        supplier:suppliers(*)
      `)
      .eq('id', orderId)
      .single();
    
    // If quantities are null or 0, trigger manual calculation
    if (orderData && (!orderData.total_received_quantity && orderData.total_received_quantity !== 0)) {
      console.log('🔄 PO quantities not set, triggering manual calculation...');
      try {
        // Call the database function to update quantities
        const { error: calcError } = await supabaseClient.rpc('update_po_received_quantities', {
          po_id_param: orderId
        });
        if (!calcError) {
          // Reload PO data after calculation
          const { data: recalculatedPO } = await supabaseClient
            .from('purchase_orders')
            .select('*')
            .eq('id', orderId)
            .single();
          if (recalculatedPO) {
            Object.assign(orderData, {
              total_received_quantity: recalculatedPO.total_received_quantity || 0,
              remaining_quantity: recalculatedPO.remaining_quantity || 0,
              ordered_quantity: recalculatedPO.ordered_quantity || 0
            });
            console.log('✅ PO quantities recalculated:', {
              ordered: orderData.ordered_quantity,
              received: orderData.total_received_quantity,
              remaining: orderData.remaining_quantity
            });
          }
        }
      } catch (e) {
        console.warn('⚠️ Could not trigger PO quantity calculation:', e);
      }
    }
    
    if (orderError) {
      console.error('❌ Error loading purchase order from Supabase:', orderError);
      return getPurchaseOrderByIdFromLocalStorage(orderId);
    }
    
    if (!orderData) {
      return { success: false, data: null, error: 'Purchase order not found' };
    }
    
    // Load items separately - Try with relationship first, fallback to without if it fails
    let itemsData = null;
    let itemsError = null;
    
    // First try with item relationship
    let { data: itemsWithRel, error: itemsErrorWithRel } = await supabaseClient
      .from('purchase_order_items')
      .select(`
        *,
        item:inventory_items(*)
      `)
      .eq('purchase_order_id', orderId);
    
    // If relationship query fails (PGRST200), load items separately
    if (itemsErrorWithRel && itemsErrorWithRel.code === 'PGRST200') {
      console.warn(`⚠️ FK relationship not found for PO ${orderId}, loading items separately...`);
      
      // Load items without relationship
      const { data: itemsWithoutRel, error: itemsErrorWithoutRel } = await supabaseClient
        .from('purchase_order_items')
        .select('*')
        .eq('purchase_order_id', orderId);
      
      if (!itemsErrorWithoutRel && itemsWithoutRel) {
        // Load inventory items separately
        const itemIds = itemsWithoutRel
          .map(item => item.item_id)
          .filter(id => id !== null && id !== undefined);
        
        if (itemIds.length > 0) {
          const { data: inventoryItems } = await supabaseClient
            .from('inventory_items')
            .select('*')
            .in('id', itemIds);
          
          // Map inventory items to PO items
          itemsWithRel = itemsWithoutRel.map(poItem => ({
            ...poItem,
            item: inventoryItems?.find(inv => inv.id === poItem.item_id) || null
          }));
        } else {
          itemsWithRel = itemsWithoutRel;
        }
        itemsErrorWithRel = null; // Clear error since we loaded successfully
      }
    }
    
    if (itemsErrorWithRel) {
      console.warn('⚠️ Error loading PO items with relationship, trying without relationship:', itemsErrorWithRel);
      // Fallback: Load items without relationship
      const { data: itemsWithoutRel, error: itemsErrorWithoutRel } = await supabaseClient
        .from('purchase_order_items')
        .select('*')
        .eq('purchase_order_id', orderId);
      
      if (itemsErrorWithoutRel) {
        console.error('❌ Error loading purchase order items from Supabase (without relationship):', itemsErrorWithoutRel);
        console.error('❌ Items error details:', {
          message: itemsErrorWithoutRel.message,
          details: itemsErrorWithoutRel.details,
          hint: itemsErrorWithoutRel.hint,
          code: itemsErrorWithoutRel.code
        });
        itemsError = itemsErrorWithoutRel;
        itemsData = [];
      } else {
        itemsData = itemsWithoutRel || [];
        console.log('✅ Loaded PO items without relationship (will load items manually):', itemsData.length, 'items');
      }
    } else {
      itemsData = itemsWithRel || [];
      console.log('✅ Loaded PO items with item relationships:', itemsData.length, 'items');
    }
    
    if (itemsError) {
      orderData.items = [];
    } else {
      orderData.items = itemsData || [];
      
      // If items don't have item relationship loaded, manually load them
      if (itemsData && itemsData.length > 0 && !itemsData[0].item) {
        console.log('🔄 Items missing relationship, loading items manually...');
        const itemIds = itemsData.map(poItem => poItem.item_id).filter(id => id);
        if (itemIds.length > 0) {
          const { data: inventoryItems, error: invError } = await supabaseClient
            .from('inventory_items')
            .select('*')
            .in('id', itemIds);
          
          if (!invError && inventoryItems) {
            // Map items to PO items
            itemsData.forEach(poItem => {
              const inventoryItem = inventoryItems.find(inv => inv.id === poItem.item_id);
              if (inventoryItem) {
                poItem.item = inventoryItem;
              }
            });
            console.log('✅ Manually loaded item relationships for', inventoryItems.length, 'items');
          }
        }
      }
      
      // Log first item to verify item relationship is loaded
      if (itemsData && itemsData.length > 0) {
        console.log('✅ First PO item sample:', {
          itemId: itemsData[0].item_id,
          itemName: itemsData[0].item?.name,
          itemSku: itemsData[0].item?.sku,
          itemCode: itemsData[0].item?.code,
          hasItem: !!itemsData[0].item,
          quantity: itemsData[0].quantity,
          unit_price: itemsData[0].unit_price
        });
      }
    }
    
    // If supplier relationship didn't load, try to load it manually
    if (!orderData.supplier && orderData.supplier_id) {
      const { data: supplierData, error: supplierError } = await supabaseClient
        .from('suppliers')
        .select('*')
        .eq('id', orderData.supplier_id)
        .single();
      
      if (!supplierError && supplierData) {
        orderData.supplier = supplierData;
      }
    }
    
    return { success: true, data: orderData };
  } catch (error) {
    console.error('❌ Exception loading purchase order from Supabase:', error);
    return getPurchaseOrderByIdFromLocalStorage(orderId);
  }
}

function getPurchaseOrderByIdFromLocalStorage(orderId) {
  try {
    const stored = localStorage.getItem('purchase_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const order = orders.find(o => o.id === orderId);
    return { success: !!order, data: order || null };
  } catch (error) {
    console.error('Error loading purchase order from localStorage:', error);
    return { success: false, data: null };
  }
}

// Export generatePONumber for use in components
export { generatePONumber };

// ==================== TRANSFER ORDERS ====================

/**
 * Generate Transfer Order Number
 */
async function generateTONumber() {
  try {
    // First try to get from Supabase
    if (USE_SUPABASE && supabaseClient) {
      const { data, error } = await supabaseClient
        .from('transfer_orders')
        .select('to_number, toNumber')
        .not('to_number', 'is', null)
        .neq('to_number', '')
        .order('created_at', { ascending: false })
        .limit(1);
      
      if (!error && data && data.length > 0) {
        const lastTO = data[0].to_number || data[0].toNumber;
        if (lastTO) {
          const lastNumber = parseInt(lastTO.replace('TO-', '')) || 0;
          const nextNumber = lastNumber + 1;
          return `TO-${String(nextNumber).padStart(6, '0')}`;
        }
      }
    }
    
    // Fallback to localStorage
    const stored = localStorage.getItem('transfer_orders');
    const orders = stored ? JSON.parse(stored) : [];
    
    // Filter out orders without TO numbers (drafts)
    const ordersWithTO = orders.filter(o => (o.toNumber || o.to_number) && (o.toNumber || o.to_number) !== '');
    
    if (ordersWithTO.length === 0) {
      return 'TO-000001';
    }
    
    // Get the highest TO number
    let maxNumber = 0;
    ordersWithTO.forEach(order => {
      const toNum = order.toNumber || order.to_number;
      if (toNum) {
        const num = parseInt(toNum.replace('TO-', '')) || 0;
        if (num > maxNumber) {
          maxNumber = num;
        }
      }
    });
    
    const nextNumber = maxNumber + 1;
    return `TO-${String(nextNumber).padStart(6, '0')}`;
  } catch (error) {
    console.error('Error generating TO number:', error);
    // Fallback: return a timestamp-based TO number
    return `TO-${String(Date.now()).slice(-6).padStart(6, '0')}`;
  }
}

/**
 * Load all transfer orders from Supabase or localStorage
 */
export async function loadTransferOrdersFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getTransferOrdersFromLocalStorage();
  
  try {
    const { data, error } = await supabaseClient
      .from('transfer_orders')
      .select(`
        *,
        items:transfer_order_items(
          *,
          item:inventory_items(*)
        )
      `)
      .order('created_at', { ascending: false });
    
    if (error) {
      console.error('❌ Error loading transfer orders from Supabase:', error);
      return getTransferOrdersFromLocalStorage();
    }
    
    console.log('✔ Transfer Orders loaded from Supabase:', data?.length || 0);
    
    // Sync to localStorage as backup
    if (data) {
      localStorage.setItem('transfer_orders', JSON.stringify(data));
    }
    
    return data || [];
  } catch (error) {
    console.error('❌ Error in loadTransferOrdersFromSupabase:', error);
    return getTransferOrdersFromLocalStorage();
  }
}

/**
 * Get transfer orders from localStorage
 */
function getTransferOrdersFromLocalStorage() {
  try {
    const stored = localStorage.getItem('transfer_orders');
    return stored ? JSON.parse(stored) : [];
  } catch (error) {
    console.error('Error loading transfer orders from localStorage:', error);
    return [];
  }
}

/**
 * Save transfer order to Supabase or localStorage
 */
export async function saveTransferOrderToSupabase(orderData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return saveTransferOrderToLocalStorage(orderData);
  }
  
  try {
    // Separate items from order data
    const { items, ...orderFields } = orderData;
    
    // Save order
    const { data, error } = await supabaseClient
      .from('transfer_orders')
      .insert([orderFields])
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error saving transfer order to Supabase:', error);
      return saveTransferOrderToLocalStorage(orderData);
    }
    
    // Save items if provided
    if (items && items.length > 0 && data) {
      const itemsToInsert = items.map(item => ({
        transfer_order_id: data.id,
        item_id: item.itemId || item.item_id,
        quantity: item.quantity || 0,
        storage_quantity: item.storageQuantity || item.storage_quantity || 0,
        ingredient_quantity: item.ingredientQuantity || item.ingredient_quantity || 0,
        available_quantity: item.availableQuantity || item.available_quantity || 0
      }));
      
      const { error: itemsError } = await supabaseClient
        .from('transfer_order_items')
        .insert(itemsToInsert);
      
      if (itemsError) {
        console.error('❌ Error saving transfer order items:', itemsError);
      }
    }
    
    // Reload to get full order with relationships
    const fullOrder = await getTransferOrderById(data.id);
    
    console.log('✔ Transfer Order saved to Supabase');
    return { success: true, data: fullOrder.data || data };
  } catch (error) {
    console.error('❌ Error in saveTransferOrderToSupabase:', error);
    return saveTransferOrderToLocalStorage(orderData);
  }
}

/**
 * Save transfer order to localStorage
 */
function saveTransferOrderToLocalStorage(orderData) {
  try {
    const stored = localStorage.getItem('transfer_orders');
    const orders = stored ? JSON.parse(stored) : [];
    
    const newOrder = {
      id: orderData.id || `to-${Date.now()}`,
      ...orderData,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    orders.push(newOrder);
    localStorage.setItem('transfer_orders', JSON.stringify(orders));
    return { success: true, data: newOrder };
  } catch (error) {
    console.error('Error saving transfer order to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update transfer order in Supabase or localStorage
 */
export async function updateTransferOrderInSupabase(orderId, orderData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updateTransferOrderInLocalStorage(orderId, orderData);
  }
  
  try {
    // Separate items from order data
    const { items, ...orderFields } = orderData;
    
    // Update order
    const { data, error } = await supabaseClient
      .from('transfer_orders')
      .update(orderFields)
      .eq('id', orderId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating transfer order in Supabase:', error);
      return updateTransferOrderInLocalStorage(orderId, orderData);
    }
    
    // Update items if provided
    if (items !== undefined && data) {
      // Delete existing items
      await supabaseClient
        .from('transfer_order_items')
        .delete()
        .eq('transfer_order_id', orderId);
      
      // Insert new items
      if (items.length > 0) {
        const itemsToInsert = items.map(item => ({
          transfer_order_id: orderId,
          item_id: item.itemId || item.item_id || item.item?.id,
          quantity: item.quantity || 0,
          storage_quantity: item.storageQuantity || item.storage_quantity || 0,
          ingredient_quantity: item.ingredientQuantity || item.ingredient_quantity || 0,
          available_quantity: item.availableQuantity || item.available_quantity || 0
        }));
        
        const { error: itemsError } = await supabaseClient
          .from('transfer_order_items')
          .insert(itemsToInsert);
        
        if (itemsError) {
          console.error('❌ Error updating transfer order items:', itemsError);
        }
      }
    }
    
    // Reload to get full order with relationships
    const fullOrder = await getTransferOrderById(orderId);
    
    console.log('✔ Transfer Order updated in Supabase');
    return { success: true, data: fullOrder.data || data };
  } catch (error) {
    console.error('❌ Error in updateTransferOrderInSupabase:', error);
    return updateTransferOrderInLocalStorage(orderId, orderData);
  }
}

/**
 * Update transfer order in localStorage
 */
function updateTransferOrderInLocalStorage(orderId, orderData) {
  try {
    const stored = localStorage.getItem('transfer_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const index = orders.findIndex(o => o.id === orderId);
    
    if (index === -1) {
      return { success: false, error: 'Transfer order not found' };
    }
    
    orders[index] = {
      ...orders[index],
      ...orderData,
      updatedAt: new Date().toISOString()
    };
    
    localStorage.setItem('transfer_orders', JSON.stringify(orders));
    return { success: true, data: orders[index] };
  } catch (error) {
    console.error('Error updating transfer order in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete transfer order from Supabase or localStorage
 */
export async function deleteTransferOrderFromSupabase(orderId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deleteTransferOrderFromLocalStorage(orderId);
  }
  
  try {
    // Delete items first
    await supabaseClient
      .from('transfer_order_items')
      .delete()
      .eq('transfer_order_id', orderId);
    
    // Delete order
    const { error } = await supabaseClient
      .from('transfer_orders')
      .delete()
      .eq('id', orderId);
    
    if (error) {
      console.error('❌ Error deleting transfer order from Supabase:', error);
      return deleteTransferOrderFromLocalStorage(orderId);
    }
    
    console.log('✔ Transfer Order deleted from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Error in deleteTransferOrderFromSupabase:', error);
    return deleteTransferOrderFromLocalStorage(orderId);
  }
}

/**
 * Delete transfer order from localStorage
 */
function deleteTransferOrderFromLocalStorage(orderId) {
  try {
    const stored = localStorage.getItem('transfer_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const filtered = orders.filter(o => o.id !== orderId);
    localStorage.setItem('transfer_orders', JSON.stringify(filtered));
    return { success: true };
  } catch (error) {
    console.error('Error deleting transfer order from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Get transfer order by ID from Supabase or localStorage
 */
export async function getTransferOrderById(orderId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return getTransferOrderByIdFromLocalStorage(orderId);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('transfer_orders')
      .select(`
        *,
        items:transfer_order_items(
          *,
          item:inventory_items(*)
        )
      `)
      .eq('id', orderId)
      .single();
    
    if (error) {
      console.error('❌ Error loading transfer order from Supabase:', error);
      return getTransferOrderByIdFromLocalStorage(orderId);
    }
    
    return { success: true, data };
  } catch (error) {
    console.error('❌ Error in getTransferOrderById:', error);
    return getTransferOrderByIdFromLocalStorage(orderId);
  }
}

/**
 * Get transfer order by ID from localStorage
 */
function getTransferOrderByIdFromLocalStorage(orderId) {
  try {
    const stored = localStorage.getItem('transfer_orders');
    const orders = stored ? JSON.parse(stored) : [];
    const order = orders.find(o => o.id === orderId);
    return { success: !!order, data: order || null };
  } catch (error) {
    console.error('Error loading transfer order from localStorage:', error);
    return { success: false, data: null };
  }
}

// Export generateTONumber for use in components
export { generateTONumber };

// ==================== GRN (GOODS RECEIPT NOTE) FUNCTIONS ====================

/**
 * Load all GRNs from Supabase or localStorage
 */
export async function loadGRNsFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getGRNsFromLocalStorage();

  try {
    // First try grn_inspections (correct table name)
    // CRITICAL: Include purchase_order_number and supplier_name for display in GRN list
    let { data: grnsData, error: grnsError } = await supabaseClient
      .from('grn_inspections')
      .select(`
        *,
        items:grn_inspection_items(*)
      `)
      .eq('deleted', false)
      .order('created_at', { ascending: false });
    
    // Map database fields to frontend fields for compatibility
    if (grnsData) {
      grnsData = grnsData.map(grn => {
        // CRITICAL: Extract supplier name properly - handle both string and object
        let supplierDisplay = 'N/A';
        
        // Priority 1: supplier_name column (string from database)
        if (grn.supplier_name && typeof grn.supplier_name === 'string' && grn.supplier_name !== 'N/A' && grn.supplier_name !== '') {
          supplierDisplay = grn.supplier_name;
        }
        // Priority 2: supplier field (could be string or object from relationship)
        else if (grn.supplier) {
          if (typeof grn.supplier === 'string' && grn.supplier !== 'N/A' && grn.supplier !== '') {
            supplierDisplay = grn.supplier;
          } else if (typeof grn.supplier === 'object' && grn.supplier !== null) {
            // Extract name from supplier object
            supplierDisplay = grn.supplier.name || 
                             grn.supplier.nameLocalized || 
                             grn.supplier.supplier_name || 
                             grn.supplier.name_localized || 
                             'N/A';
          }
        }
        
        return {
        ...grn,
        // Map purchase_order_number to purchase_order_reference for frontend compatibility
        purchase_order_reference: grn.purchase_order_number || grn.purchase_order_reference,
        purchaseOrderReference: grn.purchase_order_number || grn.purchase_order_reference,
          // CRITICAL: Always use extracted supplier name as string, never pass object
          supplier: supplierDisplay,
          supplier_name: supplierDisplay, // Ensure both fields have the string value
        // Map purchase_order_id to purchaseOrderId for frontend compatibility
        purchaseOrderId: grn.purchase_order_id,
        // Map grn_number to grnNumber for frontend compatibility
        grnNumber: grn.grn_number || grn.grnNumber
        };
      });
    }
    
    // Do NOT fallback to 'grns' - that table does not exist. Use grn_inspections only.
    if (grnsError) {
      console.error('❌ Error loading GRNs from Supabase:', grnsError);
      console.error('❌ Error details:', {
        message: grnsError.message,
        code: grnsError.code,
        hint: grnsError.hint
      });
      console.error('⚠️ Make sure you have run CREATE_GRN_TABLES.sql in Supabase SQL Editor');
      return getGRNsFromLocalStorage();
    }
    
    console.log('✅ Loaded', grnsData?.length || 0, 'GRNs from Supabase');
    return grnsData || [];
  } catch (error) {
    console.error('❌ Exception loading GRNs from Supabase:', error);
    return getGRNsFromLocalStorage();
  }
}

function getGRNsFromLocalStorage() {
  try {
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    return grns;
  } catch (error) {
    console.error('Error reading GRNs from localStorage:', error);
    return [];
  }
}

/**
 * Save GRN to Supabase or localStorage
 */
export async function saveGRNToSupabase(grn) {
  if (!USE_SUPABASE || !supabaseClient) {
    return saveGRNToLocalStorage(grn);
  }
  
  try {
    const { items, ...grnFields } = grn;
    
    // Map frontend field names to database column names (snake_case)
    // For drafts, do NOT generate any number - leave it null
    // GRN number will be generated only when submitting for inspection
    let grnNumber = grnFields.grnNumber || grnFields.grn_number;
    if (!grnNumber || grnNumber === '' || grnNumber.startsWith('DRAFT-')) {
      // Only generate number for non-draft GRNs
      if (grnFields.status && grnFields.status !== 'draft') {
        // For non-draft, generate proper GRN number
        grnNumber = await generateGRNNumber();
      } else {
        // For drafts, set to null - no number until submitted
        grnNumber = null;
      }
    }
    
    // Get supplier ID if supplier name is provided
    let supplierIdValue = grnFields.supplierId || grnFields.supplier_id || null;
    if (!supplierIdValue && grnFields.supplier) {
      // Try to find supplier by name
      try {
        const { data: suppliers } = await supabaseClient
          .from('suppliers')
          .select('id')
          .eq('name', grnFields.supplier)
          .eq('deleted', false)
          .limit(1);
        
        if (suppliers && suppliers.length > 0) {
          supplierIdValue = suppliers[0].id;
        }
      } catch (e) {
        console.warn('⚠️ Could not find supplier by name:', e);
      }
    }
    
    // CRITICAL: grn_inspections.purchase_order_id is BIGINT (FK to purchase_orders.id). Keep numeric PO id.
    let purchaseOrderIdValue = grnFields.purchaseOrderId ?? grnFields.purchase_order_id ?? null;
    if (purchaseOrderIdValue != null && typeof purchaseOrderIdValue === 'string' && /^\d+$/.test(purchaseOrderIdValue)) {
      purchaseOrderIdValue = parseInt(purchaseOrderIdValue, 10);
    }
    if (purchaseOrderIdValue != null && typeof purchaseOrderIdValue !== 'number') {
      const num = Number(purchaseOrderIdValue);
      if (!Number.isNaN(num)) purchaseOrderIdValue = num;
    }
    
    // Get purchase order number - CRITICAL: This is the linking field between GRN and PO
    // Try multiple field names as autoDraftFlow.js sets several
    let purchaseOrderNumber = 
      grnFields.purchase_order_number || 
      grnFields.purchaseOrderNumber || 
      grnFields.purchaseOrderReference || 
      grnFields.purchase_order_reference || 
      grnFields.poNumber || 
      grnFields.po_number || 
      null;
      
    console.log('📝 purchase_order_number extracted:', purchaseOrderNumber);
    
    if (!purchaseOrderNumber && purchaseOrderIdValue) {
      try {
        const { data: po } = await supabaseClient
          .from('purchase_orders')
          .select('po_number')
          .eq('id', purchaseOrderIdValue)
          .single();
        
        if (po && po.po_number) {
          purchaseOrderNumber = po.po_number;
        }
      } catch (e) {
        console.warn('⚠️ Could not find PO number:', e);
        // If PO lookup fails, try to get from grnFields directly
        purchaseOrderNumber = grnFields.poNumber || grnFields.po_number || null;
      }
    }
    
    // CRITICAL: Ensure supplier_name is always set if supplier is provided
    let supplierNameValue = grnFields.supplier || grnFields.supplier_name || null;
    if (!supplierNameValue && supplierIdValue) {
      // Try to get supplier name from suppliers table
      try {
        const { data: supplier } = await supabaseClient
          .from('suppliers')
          .select('name, name_localized')
          .eq('id', supplierIdValue)
          .single();
        
        if (supplier) {
          supplierNameValue = supplier.name || supplier.name_localized || null;
        }
      } catch (e) {
        console.warn('⚠️ Could not find supplier name:', e);
      }
    }
    
    const insertData = {
      purchase_order_id: purchaseOrderIdValue,
      purchase_order_number: purchaseOrderNumber || grnFields.poNumber || grnFields.po_number || null,
      supplier_id: supplierIdValue,
      supplier_name: supplierNameValue || grnFields.supplier || null,
      receiving_location: grnFields.receivingLocation || grnFields.receiving_location || null,
      external_reference_id: grnFields.externalReferenceId || grnFields.external_reference_id || null,
      status: grnFields.status || 'draft',
      grn_number: grnNumber || null, // For drafts, set to null (no number until submitted)
      grn_date: grnFields.grnDate || grnFields.grn_date ? new Date(grnFields.grnDate || grnFields.grn_date).toISOString() : new Date().toISOString(),
      inspection_date: grnFields.inspectionDate || grnFields.inspection_date || new Date().toISOString(),
      received_by_name: grnFields.receivedBy || grnFields.received_by || null,
      quality_checked_by_name: grnFields.qcCheckedBy || grnFields.qc_checked_by || null,
      invoice_number: grnFields.supplierInvoiceNumber || grnFields.supplier_invoice_number || null,
      vendor_batch_number: grnFields.vendorBatchNumber || grnFields.vendor_batch_number || null,
      qc_status: grnFields.qcStatus || grnFields.qc_status || null,
      disposition: grnFields.disposition || null,
      qa_remarks: grnFields.qaRemarks || grnFields.qa_remarks || null,
      corrective_action_required: grnFields.correctiveActionRequired !== undefined ? grnFields.correctiveActionRequired : false,
      // Combine notes and deliveryNoteNumber
      notes: (() => {
        const notes = grnFields.notes || null;
        const deliveryNote = grnFields.deliveryNoteNumber || grnFields.delivery_note_number;
        if (deliveryNote) {
          return notes ? `${notes}\nDelivery Note: ${deliveryNote}` : `Delivery Note: ${deliveryNote}`;
        }
        return notes;
      })(),
      created_at: grnFields.createdAt || grnFields.created_at || new Date().toISOString(),
      updated_at: grnFields.updatedAt || grnFields.updated_at || new Date().toISOString(),
      deleted: false
    };
    
    // ERP-GRADE VALIDATION: Validate received quantities against PO before saving
    if (purchaseOrderIdValue && grnFields.items && Array.isArray(grnFields.items) && grnFields.items.length > 0) {
      try {
        // Load PO to validate quantities
        const { data: poData, error: poError } = await supabaseClient
          .from('purchase_orders')
          .select(`
            id,
            status,
            items:purchase_order_items(*)
          `)
          .eq('id', purchaseOrderIdValue)
          .single();
        
        if (!poError && poData) {
          // Check if PO is closed
          const poStatus = (poData.status || '').toLowerCase();
          if (poStatus === 'closed') {
            return {
              success: false,
              error: 'Cannot create GRN from a closed Purchase Order. The PO has been fully received or manually closed.',
              data: null
            };
          }
          
          // Load existing GRNs for this PO
          const { data: existingGRNs } = await supabaseClient
            .from('grn_inspections')
            .select(`
              id,
              status,
              items:grn_inspection_items(item_id, received_quantity)
            `)
            .eq('purchase_order_id', purchaseOrderIdValue)
            .eq('deleted', false);
          
          // Calculate already received quantities per item
          const itemReceivedQty = {};
          if (existingGRNs) {
            existingGRNs.forEach(grn => {
              const grnStatus = (grn.status || '').toLowerCase();
              if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
                (grn.items || []).forEach(grnItem => {
                  const itemId = grnItem.item_id;
                  if (itemId) {
                    if (!itemReceivedQty[itemId]) {
                      itemReceivedQty[itemId] = 0;
                    }
                    itemReceivedQty[itemId] += parseFloat(grnItem.received_quantity || 0);
                  }
                });
              }
            });
          }
          
          // Validate each GRN item against PO
          for (const grnItem of grnFields.items) {
            const itemId = grnItem.itemId || grnItem.item_id;
            if (!itemId) continue;
            
            // Find PO item
            const poItem = (poData.items || []).find(poi => 
              (poi.item_id || poi.itemId) === itemId
            );
            
            if (poItem) {
              const orderedQty = parseFloat(poItem.quantity || 0);
              const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
              const alreadyReceived = itemReceivedQty[itemId] || 0;
              const totalAfterThisGRN = alreadyReceived + receivedQty;
              
              // Validate: total received must not exceed ordered
              if (totalAfterThisGRN > orderedQty) {
                return {
                  success: false,
                  error: `Over-receiving detected! Item ${poItem.item_name || poItem.item_sku || itemId}: Ordered=${orderedQty}, Already Received=${alreadyReceived}, Attempting to receive=${receivedQty}, Total would be=${totalAfterThisGRN}. Maximum allowed=${orderedQty - alreadyReceived}`,
                  data: null
                };
              }
            }
          }
        }
      } catch (validationError) {
        console.error('⚠️ Error during GRN quantity validation:', validationError);
        // Don't block save if validation fails due to error, but log it
      }
    }
    
    // Remove undefined values
    Object.keys(insertData).forEach(key => {
      if (insertData[key] === undefined) {
        delete insertData[key];
      }
    });
    
    // Log the data being inserted for debugging
    console.log('📝 Inserting GRN data:', JSON.stringify(insertData, null, 2));
    
    // Insert GRN into grn_inspections only (table 'grns' does not exist)
    const { data: grnData, error: grnError } = await supabaseClient
      .from('grn_inspections')
      .insert([insertData])
      .select()
      .single();
    
    if (grnError) {
      console.error('❌ Error saving GRN to Supabase:', grnError);
      console.error('❌ Error details:', {
        message: grnError.message,
        details: grnError.details,
        hint: grnError.hint,
        code: grnError.code
      });
      const hintMsg = grnError.message?.includes('schema cache') || grnError.message?.includes('not find the table')
        ? 'Ensure table public.grn_inspections exists. Run your GRN migration (e.g. CREATE_GRN_TABLES or grn_inspections / grn_inspection_items) in Supabase SQL Editor.'
        : (grnError.hint || 'Check that grn_inspections and grn_inspection_items tables exist.');
      return { 
        success: false, 
        error: grnError.message || 'Failed to save GRN',
        details: grnError.details,
        hint: hintMsg
      };
    }
    
    // CRITICAL: Verify GRN was actually created
    if (!grnData || !grnData.id) {
      console.error('❌ GRN data is missing or has no ID after insert!');
      console.error('❌ GRN Data:', grnData);
      return {
        success: false,
        error: 'GRN was not created properly - missing ID'
      };
    }
    
    console.log('✅ GRN created successfully with ID:', grnData.id);
    
    // Save GRN items separately - CRITICAL: Must save items after GRN is created
    console.log('🔍 Checking items to save:', {
      hasItems: !!items,
      itemsLength: items?.length || 0,
      hasGrnData: !!grnData,
      grnDataId: grnData?.id
    });
    
    if (items && items.length > 0 && grnData && grnData.id) {
      console.log('📦 Saving GRN items:', items.length, 'items to GRN:', grnData.id);
      const grnItems = items.map((item, index) => {
        // Get item details if item_id is provided
        let itemCode = item.itemCode || item.item_code || null;
        let itemName = item.itemName || item.item_name || null;
        let itemDescription = item.itemDescription || item.item_description || null;
        
        // CRITICAL: Get item_id - this is the foreign key to inventory_items
        const itemId = item.itemId || item.item_id;
        
        // If item object is provided, extract details from it
        if (item.item) {
          if (!itemCode) itemCode = item.item.code || item.item.sku || null;
          if (!itemName) itemName = item.item.name || null;
          if (!itemDescription) itemDescription = item.item.description || null;
        }
        
        // Log item being saved for debugging
        console.log(`📦 GRN Item ${index + 1}:`, {
          itemId: itemId,
          itemCode: itemCode,
          itemName: itemName,
          orderedQty: item.orderedQuantity || item.ordered_quantity,
          receivedQty: item.receivedQuantity || item.received_quantity,
          hasItemObject: !!item.item
        });
        
        if (!itemId) {
          console.warn(`⚠️ GRN Item ${index + 1} missing itemId!`, item);
        }
        
        return {
          grn_inspection_id: grnData.id,
          purchase_order_id: purchaseOrderIdValue, // Use validated UUID value, not insertData.purchase_order_id
          item_id: itemId || null, // CRITICAL: This must be set for item relationship to work
          item_code: itemCode || item.item?.code || item.item?.sku || null,
          item_name: itemName || item.item?.name || null,
          item_description: itemDescription || item.item?.description || null,
          unit_of_measure: item.unit || item.unitOfMeasure || item.unit_of_measure || item.item?.storageUnit || item.item?.storage_unit || null,
          ordered_quantity: parseFloat(item.orderedQuantity || item.ordered_quantity || 0),
          received_quantity: parseFloat(item.receivedQuantity || item.received_quantity || 0),
          expiry_date: item.expiryDate || item.expiry_date ? new Date(item.expiryDate || item.expiry_date).toISOString() : null,
          packaging_condition: (() => {
            // Normalize packaging_condition to valid values: 'Good', 'Damaged', or null
            const value = (item.packagingType || item.packaging_type || item.packagingCondition || item.packaging_condition || '').trim();
            if (value === '' || value.toLowerCase() === 'n/a' || value.toLowerCase() === 'select...') {
              return 'Good'; // Default to 'Good' if empty
            }
            // Normalize common variations
            const normalized = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
            if (normalized === 'Good' || normalized === 'Damaged') {
              return normalized;
            }
            // If invalid value, default to 'Good' and log warning
            console.warn(`⚠️ Invalid packaging_condition value: "${value}", defaulting to "Good"`);
            return 'Good';
          })(),
          supplier_lot_number: (item.supplierLotNumber || item.supplier_lot_number || '').trim() || null, // CRITICAL: Supplier lot number field
          visual_inspection: item.visualInspectionResult || item.visual_inspection_result || item.visualInspection || item.visual_inspection || null,
          temperature_check: item.temperatureCheck || item.temperature_check || null,
          non_conformance_reason: item.nonConformanceReason || item.non_conformance_reason || null,
          non_conformance_severity: item.nonConformanceSeverity || item.non_conformance_severity || null,
          quality_status: item.qualityStatus || item.quality_status || null,
          batch_number: item.batchNumber || item.batch_number || null,
          test_results: item.testResults || item.test_results || null
        };
      });
      
      console.log('📦 GRN Items to insert:', JSON.stringify(grnItems, null, 2));
      
      // Try grn_inspection_items first, fallback to grn_items if needed
      let { data: insertedItems, error: itemsError } = await supabaseClient
        .from('grn_inspection_items')
        .insert(grnItems)
        .select();
      
      // If table doesn't exist, try alternative table name
      if (itemsError && (itemsError.code === '42P01' || itemsError.message?.includes('does not exist'))) {
        console.warn('⚠️ grn_inspection_items table not found, trying alternative...');
        const { data: insertedItemsAlt, error: itemsErrorAlt } = await supabaseClient
          .from('grn_items')
          .insert(grnItems)
          .select();
        
        if (!itemsErrorAlt) {
          itemsError = null;
          insertedItems = insertedItemsAlt;
          console.warn('⚠️ Saved to grn_items table (please run CREATE_GRN_TABLES.sql)');
        } else {
          itemsError = itemsErrorAlt;
        }
      }
      
      if (itemsError) {
        console.error('❌ Error saving GRN items to Supabase:', itemsError);
        console.error('❌ Items error details:', {
          message: itemsError.message,
          details: itemsError.details,
          hint: itemsError.hint,
          code: itemsError.code
        });
        console.error('❌ Items that failed to insert:', JSON.stringify(grnItems, null, 2));
        console.error('⚠️ Make sure you have run CREATE_GRN_TABLES.sql and FIX_GRN_CONSTRAINTS.sql in Supabase SQL Editor');
        
        // Check if it's a constraint violation
        if (itemsError.code === '23514' || itemsError.message?.includes('check constraint')) {
          console.error('❌ CHECK CONSTRAINT VIOLATION - This is likely a packaging_condition issue');
          console.error('❌ Run FIX_GRN_CONSTRAINTS.sql in Supabase SQL Editor');
        }
        
        // CRITICAL: Delete the GRN if items failed to save (rollback)
        console.error('🔄 Rolling back GRN creation because items failed to save...');
        try {
          await supabaseClient
            .from('grn_inspections')
            .delete()
            .eq('id', grnData.id);
          console.log('✅ GRN rolled back (deleted)');
        } catch (rollbackError) {
          console.error('❌ Failed to rollback GRN:', rollbackError);
        }
        
        // CRITICAL: Throw error so user knows items failed to save
        throw new Error(`Failed to save GRN items: ${itemsError.message}. GRN has been rolled back. Please check console for details and run FIX_GRN_CONSTRAINTS.sql.`);
      } else {
        console.log('✅ GRN items saved successfully:', insertedItems?.length || grnItems.length, 'items');
        if (insertedItems && insertedItems.length > 0) {
          console.log('✅ First inserted item sample:', {
            id: insertedItems[0].id,
            item_id: insertedItems[0].item_id,
            item_name: insertedItems[0].item_name,
            item_code: insertedItems[0].item_code,
            grn_inspection_id: insertedItems[0].grn_inspection_id
          });
        } else {
          console.warn('⚠️ Items insert returned no data, but no error. Check if items were actually saved.');
        }
      }
    } else {
      console.warn('⚠️ No items to save or GRN data missing:', {
        hasItems: !!items,
        itemsLength: items?.length || 0,
        hasGrnData: !!grnData,
        grnDataId: grnData?.id
      });
      // CRITICAL: If items were supposed to be saved but weren't, this is an error
      if (items && items.length > 0) {
        console.error('❌ CRITICAL: Items were provided but not saved!', {
          itemsCount: items.length,
          grnDataExists: !!grnData,
          grnDataId: grnData?.id,
          grnData: grnData
        });
        // Don't throw here - GRN was saved, items can be added manually
        // But log it clearly
      }
    }
    
    // Reload GRN with items AND item relationships - CRITICAL for displaying item names/SKUs
    // Try with relationship first
    let { data: fullGRN, error: reloadError } = await supabaseClient
      .from('grn_inspections')
      .select(`
        *,
        items:grn_inspection_items(
          *,
          item:inventory_items(*)
        )
      `)
      .eq('id', grnData.id)
      .single();
    
    // If relationship query fails, try without relationship (fallback)
    if (reloadError && (reloadError.code === '42P01' || reloadError.message?.includes('does not exist') || reloadError.message?.includes('relation') || reloadError.message?.includes('foreign key'))) {
      console.warn('⚠️ Relationship query failed, trying without relationship:', reloadError.message);
      const { data: fullGRNAlt, error: reloadErrorAlt } = await supabaseClient
        .from('grn_inspections')
        .select(`
          *,
          items:grn_inspection_items(*)
        `)
        .eq('id', grnData.id)
        .single();
      
      if (!reloadErrorAlt && fullGRNAlt) {
        fullGRN = fullGRNAlt;
        reloadError = null;
        console.log('✅ Loaded GRN without item relationship (will load manually)');
      } else {
        reloadError = reloadErrorAlt || reloadError;
      }
    }
    
    // Do NOT fallback to 'grns' - that table does not exist.
    if (reloadError) {
      console.error('❌ Error reloading GRN:', reloadError);
      console.error('❌ Reload error details:', {
        message: reloadError.message,
        details: reloadError.details,
        hint: reloadError.hint
      });
      // Still return success with the GRN data we have, but manually add items
      if (items && items.length > 0) {
        grnData.items = items;
        console.log('⚠️ Manually adding items to GRN data due to reload error');
      }
      return { success: true, data: grnData };
    }
    
    // Log items count for debugging
    if (fullGRN) {
      console.log('✅ GRN reloaded with', fullGRN.items?.length || 0, 'items');
      if (fullGRN.items && fullGRN.items.length > 0) {
        console.log('✅ First item sample:', {
          itemId: fullGRN.items[0].item_id,
          itemName: fullGRN.items[0].item?.name || fullGRN.items[0].item_name,
          itemSku: fullGRN.items[0].item?.sku || fullGRN.items[0].item_code,
          hasItem: !!fullGRN.items[0].item
        });
      } else {
        console.warn('⚠️ GRN reloaded but items array is empty!');
        // If items were saved but not loaded, manually add them
        if (items && items.length > 0) {
          console.log('⚠️ Manually adding items to GRN data');
          fullGRN.items = items;
        }
      }
    }
    
    console.log('✅ GRN saved to Supabase');
    return { success: true, data: fullGRN || grnData };
  } catch (error) {
    console.error('❌ Exception saving GRN to Supabase:', error);
    return { 
      success: false, 
      error: error.message || 'Failed to save GRN' 
    };
  }
}

function saveGRNToLocalStorage(grn) {
  try {
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    const newGRN = {
      ...grn,
      id: grn.id || `grn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      created_at: grn.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    grns.push(newGRN);
    localStorage.setItem('sakura_grns', JSON.stringify(grns));
    return { success: true, data: newGRN };
  } catch (error) {
    console.error('Error saving GRN to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update GRN in Supabase or localStorage
 */
export async function updateGRNInSupabase(grnId, updates) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updateGRNInLocalStorage(grnId, updates);
  }
  
  try {
    const { items, ...grnFields } = updates;
    
    // CRITICAL: Ensure purchase_order_number and supplier_name are always updated if PO/Supplier info is available
    let purchaseOrderNumber = grnFields.purchaseOrderReference || grnFields.purchase_order_reference || grnFields.poNumber || grnFields.po_number || undefined;
    let supplierName = grnFields.supplier || grnFields.supplier_name || undefined;
    
    // If purchase_order_id is provided but purchase_order_number is missing, fetch it
    const purchaseOrderIdValue = grnFields.purchaseOrderId || grnFields.purchase_order_id;
    if (!purchaseOrderNumber && purchaseOrderIdValue) {
      try {
        const { data: po } = await supabaseClient
          .from('purchase_orders')
          .select('po_number')
          .eq('id', purchaseOrderIdValue)
          .single();
        
        if (po && po.po_number) {
          purchaseOrderNumber = po.po_number;
        }
      } catch (e) {
        console.warn('⚠️ Could not find PO number for update:', e);
      }
    }
    
    // If supplier_id is provided but supplier_name is missing, fetch it
    const supplierIdValue = grnFields.supplierId || grnFields.supplier_id;
    if (!supplierName && supplierIdValue) {
      try {
        const { data: supplier } = await supabaseClient
          .from('suppliers')
          .select('name, name_localized')
          .eq('id', supplierIdValue)
          .single();
        
        if (supplier) {
          supplierName = supplier.name || supplier.name_localized || undefined;
        }
      } catch (e) {
        console.warn('⚠️ Could not find supplier name for update:', e);
      }
    }
    
    // Map frontend field names to database column names (snake_case)
    const updateData = {
      purchase_order_id: grnFields.purchaseOrderId !== undefined ? (grnFields.purchaseOrderId || null) : undefined,
      purchase_order_number: purchaseOrderNumber !== undefined ? purchaseOrderNumber : undefined,
      supplier_id: grnFields.supplierId !== undefined ? (grnFields.supplierId || null) : undefined,
      supplier_name: supplierName !== undefined ? supplierName : undefined,
      receiving_location: grnFields.receivingLocation !== undefined ? (grnFields.receivingLocation || null) : undefined,
      external_reference_id: grnFields.externalReferenceId !== undefined ? (grnFields.externalReferenceId || null) : undefined,
      status: grnFields.status !== undefined ? grnFields.status : undefined,
      grn_number: grnFields.grnNumber !== undefined ? (grnFields.grnNumber || grnFields.grn_number || null) : undefined,
      grn_date: grnFields.grnDate !== undefined ? (grnFields.grnDate ? new Date(grnFields.grnDate).toISOString() : null) : undefined,
      inspection_date: grnFields.inspectionDate !== undefined ? (grnFields.inspectionDate ? new Date(grnFields.inspectionDate).toISOString() : null) : undefined,
      received_by_name: grnFields.receivedBy !== undefined ? (grnFields.receivedBy || grnFields.received_by || null) : undefined,
      quality_checked_by_name: grnFields.qcCheckedBy !== undefined ? (grnFields.qcCheckedBy || grnFields.qc_checked_by || null) : undefined,
      invoice_number: grnFields.supplierInvoiceNumber !== undefined ? (grnFields.supplierInvoiceNumber || grnFields.supplier_invoice_number || null) : undefined,
      vendor_batch_number: grnFields.vendorBatchNumber !== undefined ? (grnFields.vendorBatchNumber || grnFields.vendor_batch_number || null) : undefined,
      qc_status: grnFields.qcStatus !== undefined ? (grnFields.qcStatus || grnFields.qc_status || null) : undefined,
      disposition: grnFields.disposition !== undefined ? (grnFields.disposition || null) : undefined,
      qa_remarks: grnFields.qaRemarks !== undefined ? (grnFields.qaRemarks || grnFields.qa_remarks || null) : undefined,
      corrective_action_required: grnFields.correctiveActionRequired !== undefined ? grnFields.correctiveActionRequired : undefined,
      // Approval workflow fields
      submitted_for_approval: grnFields.submittedForApproval !== undefined ? grnFields.submittedForApproval : (grnFields.submitted_for_approval !== undefined ? grnFields.submitted_for_approval : undefined),
      submitted_for_approval_at: grnFields.submittedForApprovalAt !== undefined ? (grnFields.submittedForApprovalAt ? new Date(grnFields.submittedForApprovalAt).toISOString() : null) : (grnFields.submitted_for_approval_at !== undefined ? (grnFields.submitted_for_approval_at ? new Date(grnFields.submitted_for_approval_at).toISOString() : null) : undefined),
      submitted_for_approval_by: grnFields.submittedForApprovalBy !== undefined ? (grnFields.submittedForApprovalBy || grnFields.submitted_for_approval_by || null) : undefined,
      approved_by_name: grnFields.approvedBy !== undefined ? (grnFields.approvedBy || grnFields.approved_by || null) : undefined,
      approval_date: grnFields.approvedAt !== undefined ? (grnFields.approvedAt ? new Date(grnFields.approvedAt).toISOString() : null) : (grnFields.approved_at !== undefined ? (grnFields.approved_at ? new Date(grnFields.approved_at).toISOString() : null) : undefined),
      // Combine notes and deliveryNoteNumber
      notes: grnFields.notes !== undefined || grnFields.deliveryNoteNumber !== undefined ? (() => {
        const notes = grnFields.notes || null;
        const deliveryNote = grnFields.deliveryNoteNumber || grnFields.delivery_note_number;
        if (deliveryNote) {
          return notes ? `${notes}\nDelivery Note: ${deliveryNote}` : `Delivery Note: ${deliveryNote}`;
        }
        return notes;
      })() : undefined,
      updated_at: new Date().toISOString()
    };
    
    // ERP-GRADE VALIDATION: Validate received quantities against PO before updating
    if (items && Array.isArray(items) && items.length > 0) {
      // Get current GRN to find PO ID
      const { data: currentGRN } = await supabaseClient
        .from('grn_inspections')
        .select('purchase_order_id, status')
        .eq('id', grnId)
        .single();
      
      if (currentGRN && currentGRN.purchase_order_id) {
        const poId = currentGRN.purchase_order_id;
        
        try {
          // Load PO to validate quantities
          const { data: poData, error: poError } = await supabaseClient
            .from('purchase_orders')
            .select(`
              id,
              status,
              items:purchase_order_items(*)
            `)
            .eq('id', poId)
            .single();
          
          if (!poError && poData) {
            // Check if PO is closed
            const poStatus = (poData.status || '').toLowerCase();
            if (poStatus === 'closed') {
              return {
                success: false,
                error: 'Cannot update GRN from a closed Purchase Order. The PO has been fully received or manually closed.',
                data: null
              };
            }
            
            // Load existing GRNs for this PO (excluding current GRN)
            const { data: existingGRNs } = await supabaseClient
              .from('grn_inspections')
              .select(`
                id,
                status,
                items:grn_inspection_items(item_id, received_quantity)
              `)
              .eq('purchase_order_id', poId)
              .neq('id', grnId)
              .eq('deleted', false);
            
            // Calculate already received quantities per item (from other GRNs)
            const itemReceivedQty = {};
            if (existingGRNs) {
              existingGRNs.forEach(grn => {
                const grnStatus = (grn.status || '').toLowerCase();
                if (grnStatus !== 'rejected' && grnStatus !== 'cancelled') {
                  (grn.items || []).forEach(grnItem => {
                    const itemId = grnItem.item_id;
                    if (itemId) {
                      if (!itemReceivedQty[itemId]) {
                        itemReceivedQty[itemId] = 0;
                      }
                      itemReceivedQty[itemId] += parseFloat(grnItem.received_quantity || 0);
                    }
                  });
                }
              });
            }
            
            // Validate each GRN item against PO
            for (const grnItem of items) {
              const itemId = grnItem.itemId || grnItem.item_id;
              if (!itemId) continue;
              
              // Find PO item
              const poItem = (poData.items || []).find(poi => 
                (poi.item_id || poi.itemId) === itemId
              );
              
              if (poItem) {
                const orderedQty = parseFloat(poItem.quantity || 0);
                const receivedQty = parseFloat(grnItem.receivedQuantity || grnItem.received_quantity || 0);
                const alreadyReceived = itemReceivedQty[itemId] || 0;
                const totalAfterThisGRN = alreadyReceived + receivedQty;
                
                // Validate: total received must not exceed ordered
                if (totalAfterThisGRN > orderedQty) {
                  return {
                    success: false,
                    error: `Over-receiving detected! Item ${poItem.item_name || poItem.item_sku || itemId}: Ordered=${orderedQty}, Already Received (from other GRNs)=${alreadyReceived}, Attempting to receive=${receivedQty}, Total would be=${totalAfterThisGRN}. Maximum allowed=${orderedQty - alreadyReceived}`,
                    data: null
                  };
                }
              }
            }
          }
        } catch (validationError) {
          console.error('⚠️ Error during GRN quantity validation on update:', validationError);
          // Don't block update if validation fails due to error, but log it
        }
      }
    }
    
    // Remove undefined values
    Object.keys(updateData).forEach(key => {
      if (updateData[key] === undefined) {
        delete updateData[key];
      }
    });
    
    // Update GRN
    const { data, error } = await supabaseClient
      .from('grn_inspections')
      .update(updateData)
      .eq('id', grnId)
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error updating GRN in Supabase:', error);
      console.error('❌ Error details:', {
        message: error.message,
        details: error.details,
        hint: error.hint,
        code: error.code
      });
      return { 
        success: false, 
        error: error.message || 'Failed to update GRN',
        details: error.details,
        hint: error.hint
      };
    }
    
    // Update items if provided
    if (items && items.length > 0) {
      // Delete existing items
      await supabaseClient
        .from('grn_inspection_items')
        .delete()
        .eq('grn_inspection_id', grnId);
      
      // Insert new items with complete field mapping
      const grnItems = items.map((item, index) => {
        // CRITICAL: Get item_id from multiple possible sources (same logic as saveGRNToSupabase)
        const itemId = item.itemId || item.item_id || (item.item && item.item.id) || null;
        
        // Get item details - try item relationship first, then direct fields
        let itemCode = item.itemCode || item.item_code || null;
        let itemName = item.itemName || item.item_name || null;
        let itemDescription = item.itemDescription || item.item_description || null;
        
        // If item relationship exists, extract details from it
        if (item.item) {
          if (!itemCode) itemCode = item.item.code || item.item.sku || null;
          if (!itemName) itemName = item.item.name || null;
          if (!itemDescription) itemDescription = item.item.description || null;
        }
        
        // Validate item_id - if missing, log warning
        if (!itemId) {
          console.warn(`⚠️ GRN Item ${index + 1} missing item_id during update!`, {
            itemName: itemName,
            itemCode: itemCode,
            hasItemObject: !!item.item
          });
        }
        
        // Get unit of measure - try multiple sources
        const unitOfMeasure = item.unit || item.unitOfMeasure || item.unit_of_measure || 
                             (item.item && (item.item.storageUnit || item.item.storage_unit)) || null;
        
        // Get packaging condition - normalize to valid values
        const packagingCondition = (() => {
          const value = (item.packagingType || item.packaging_type || item.packagingCondition || item.packaging_condition || '').trim();
          if (value === '' || value.toLowerCase() === 'n/a' || value.toLowerCase() === 'select...') {
            return 'Good'; // Default to 'Good' if empty
          }
          const normalized = value.charAt(0).toUpperCase() + value.slice(1).toLowerCase();
          if (normalized === 'Good' || normalized === 'Damaged') {
            return normalized;
          }
          return 'Good'; // Default to 'Good' for invalid values
        })();
        
        // Get supplier lot number - CRITICAL: This field must be saved
        const supplierLotNumber = (item.supplierLotNumber || item.supplier_lot_number || '').trim() || null;
        
        return {
          grn_inspection_id: grnId,
          purchase_order_id: updateData.purchase_order_id, // Use validated UUID from updateData
          item_id: itemId, // CRITICAL: Must be set for item relationship to work
          item_code: itemCode,
          item_name: itemName,
          item_description: itemDescription,
          unit_of_measure: unitOfMeasure,
          ordered_quantity: parseFloat(item.orderedQuantity || item.ordered_quantity || 0),
          received_quantity: parseFloat(item.receivedQuantity || item.received_quantity || 0),
          expiry_date: item.expiryDate || item.expiry_date ? new Date(item.expiryDate || item.expiry_date).toISOString() : null,
          packaging_condition: packagingCondition,
          supplier_lot_number: supplierLotNumber, // CRITICAL: Supplier lot number field
          visual_inspection: item.visualInspectionResult || item.visual_inspection_result || item.visualInspection || item.visual_inspection || null,
          temperature_check: item.temperatureCheck || item.temperature_check || null,
          non_conformance_reason: item.nonConformanceReason || item.non_conformance_reason || null,
          non_conformance_severity: item.nonConformanceSeverity || item.non_conformance_severity || null,
          quality_status: item.qualityStatus || item.quality_status || null,
          batch_number: item.batchNumber || item.batch_number || null,
          test_results: item.testResults || item.test_results || null
        };
      });
      
      // Log items being updated for debugging
      console.log('📦 Updating GRN items:', grnItems.length, 'items');
      console.log('📦 First GRN item sample:', {
        grn_inspection_id: grnItems[0]?.grn_inspection_id,
        item_id: grnItems[0]?.item_id,
        item_name: grnItems[0]?.item_name,
        received_quantity: grnItems[0]?.received_quantity,
        packaging_condition: grnItems[0]?.packaging_condition,
        supplier_lot_number: grnItems[0]?.supplier_lot_number
      });
      
      const { data: insertedItems, error: itemsError } = await supabaseClient
        .from('grn_inspection_items')
        .insert(grnItems)
        .select();
      
      if (itemsError) {
        console.error('❌ Error updating GRN items:', itemsError);
        console.error('❌ Items error details:', {
          message: itemsError.message,
          details: itemsError.details,
          hint: itemsError.hint,
          code: itemsError.code
        });
        console.error('❌ Items that failed to insert:', JSON.stringify(grnItems, null, 2));
        
        // CRITICAL: If items fail to insert, we need to rollback or throw error
        // Since we already deleted old items, this is a critical error
        throw new Error(`Failed to save GRN items: ${itemsError.message || 'Unknown error'}. ${itemsError.hint || ''}`);
      } else {
        console.log('✅ GRN items updated successfully:', insertedItems?.length || grnItems.length, 'items');
      }
    }
    
    // Reload GRN with items AND item relationships - CRITICAL for displaying item names/SKUs
    const { data: fullGRN, error: reloadError } = await supabaseClient
      .from('grn_inspections')
      .select(`
        *,
        items:grn_inspection_items(
          *,
          item:inventory_items(*)
        )
      `)
      .eq('id', grnId)
      .single();
    
    if (reloadError) {
      console.error('❌ Error reloading GRN:', reloadError);
      return { success: true, data };
    }
    
    return { success: true, data: fullGRN || data };
  } catch (error) {
    console.error('❌ Exception updating GRN in Supabase:', error);
    return { 
      success: false, 
      error: error.message || 'Failed to update GRN' 
    };
  }
}

function updateGRNInLocalStorage(grnId, updates) {
  try {
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    const index = grns.findIndex(g => g.id === grnId);
    if (index !== -1) {
      grns[index] = { ...grns[index], ...updates, updated_at: new Date().toISOString() };
      localStorage.setItem('sakura_grns', JSON.stringify(grns));
      return { success: true, data: grns[index] };
    }
    return { success: false, error: 'GRN not found' };
  } catch (error) {
    console.error('Error updating GRN in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Delete GRN from Supabase or localStorage
 */
export async function deleteGRNFromSupabase(grnId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return deleteGRNFromLocalStorage(grnId);
  }
  
  try {
    // Soft delete: Set deleted flag and deleted_at timestamp
    const { error } = await supabaseClient
      .from('grn_inspections')
      .update({
        deleted: true,
        deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', grnId);
    
    if (error) {
      console.error('❌ Error deleting GRN from Supabase:', error);
      return deleteGRNFromLocalStorage(grnId);
    }
    
    console.log('✅ GRN soft deleted from Supabase');
    return { success: true };
  } catch (error) {
    console.error('❌ Exception deleting GRN from Supabase:', error);
    return deleteGRNFromLocalStorage(grnId);
  }
}

function deleteGRNFromLocalStorage(grnId) {
  try {
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    const filtered = grns.filter(g => g.id !== grnId);
    localStorage.setItem('sakura_grns', JSON.stringify(filtered));
    return { success: true };
  } catch (error) {
    console.error('Error deleting GRN from localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Get GRN by ID from Supabase or localStorage
 */
export async function getGRNById(grnId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return getGRNByIdFromLocalStorage(grnId);
  }
  
  try {
    // Load GRN with supplier (simplified query)
    const { data: grnData, error: grnError } = await supabaseClient
      .from('grn_inspections')
      .select(`
        *,
        supplier:suppliers(*)
      `)
      .eq('id', grnId)
      .eq('deleted', false)
      .single();
    
    if (grnError) {
      console.error('❌ Error loading GRN from Supabase:', grnError);
      return getGRNByIdFromLocalStorage(grnId);
    }
    
    if (!grnData) {
      return { success: false, data: null, error: 'GRN not found' };
    }
    
    // Load items separately WITH item relationship - CRITICAL for displaying item names/SKUs
    const { data: itemsData, error: itemsError } = await supabaseClient
      .from('grn_inspection_items')
      .select(`
        *,
        item:inventory_items(*)
      `)
      .eq('grn_inspection_id', grnId);
    
    if (itemsError) {
      console.error('❌ Error loading GRN items from Supabase:', itemsError);
      console.error('❌ Items error details:', {
        message: itemsError.message,
        details: itemsError.details,
        hint: itemsError.hint
      });
      grnData.items = [];
    } else {
      grnData.items = itemsData || [];
      console.log('✅ Loaded GRN items with item relationships:', itemsData?.length || 0, 'items');
      // Log first item to verify item relationship is loaded
      if (itemsData && itemsData.length > 0) {
        console.log('✅ First GRN item sample:', {
          itemId: itemsData[0].item_id,
          itemName: itemsData[0].item?.name || itemsData[0].item_name,
          itemSku: itemsData[0].item?.sku || itemsData[0].item_code,
          hasItem: !!itemsData[0].item
        });
      }
    }
    
    // If supplier relationship didn't load, try to load it manually
    if (!grnData.supplier && grnData.supplier_id) {
      const { data: supplierData, error: supplierError } = await supabaseClient
        .from('suppliers')
        .select('*')
        .eq('id', grnData.supplier_id)
        .single();
      
      if (!supplierError && supplierData) {
        grnData.supplier = supplierData;
      }
    }
    
    // Extract deliveryNoteNumber from notes if it exists
    if (grnData.notes && grnData.notes.includes('Delivery Note:')) {
      const deliveryNoteMatch = grnData.notes.match(/Delivery Note:\s*(.+)/);
      if (deliveryNoteMatch) {
        grnData.deliveryNoteNumber = deliveryNoteMatch[1].trim();
        grnData.delivery_note_number = deliveryNoteMatch[1].trim();
      }
    }

    // CRITICAL: Always load batches from DB (single source: v_grn_all_batches / grn_batches)
    try {
      const batchesData = await loadBatchesForGRN(grnId);
      grnData.batches = Array.isArray(batchesData) ? batchesData : [];
    } catch (batchErr) {
      console.warn('⚠️ loadBatchesForGRN failed, using empty batches:', batchErr);
      grnData.batches = [];
    }

    return { success: true, data: grnData };
  } catch (error) {
    console.error('❌ Error in getGRNById:', error);
    try {
      return getGRNByIdFromLocalStorage(grnId) || { success: false, data: null };
    } catch (localErr) {
      console.error('❌ getGRNByIdFromLocalStorage failed:', localErr);
      return { success: false, data: null };
    }
  }
}

function getGRNByIdFromLocalStorage(grnId) {
  try {
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    const grn = grns.find(g => g.id === grnId);
    if (grn) {
      grn.batches = []; // Batches only from Supabase, never localStorage
      return { success: true, data: grn };
    }
    return { success: false, data: null };
  } catch (error) {
    console.error('Error loading GRN from localStorage:', error);
    return { success: false, data: null };
  }
}

/**
 * Generate unique GRN number (GRN-000001, GRN-000002, etc.)
 * ISO 22000: Batch traceability starts at GRN level
 */
export async function generateGRNNumber() {
  try {
    // First try to get from Supabase
    // Exclude draft GRNs - only count GRNs that have been submitted (have a GRN number)
    if (USE_SUPABASE && supabaseClient) {
      const { data, error } = await supabaseClient
        .from('grn_inspections')
        .select('grn_number, status')
        .not('grn_number', 'is', null)
        .neq('grn_number', '')
        .not('grn_number', 'like', 'DRAFT-%') // Exclude DRAFT- numbers
        .neq('status', 'draft') // Exclude draft GRNs
        .order('created_at', { ascending: false })
        .limit(1);
      
      if (!error && data && data.length > 0) {
        const lastNumber = data[0].grn_number || data[0].grnNumber;
        if (lastNumber && lastNumber.startsWith('GRN-')) {
          const num = parseInt(lastNumber.replace('GRN-', ''));
          const nextNum = String(num + 1).padStart(6, '0');
          return `GRN-${nextNum}`;
        }
      }
    }
    
    // Fallback to localStorage
    // Exclude draft GRNs and DRAFT- numbers - only count GRNs that have been submitted
    const grns = JSON.parse(localStorage.getItem('sakura_grns') || '[]');
    const numbers = grns
      .filter(g => {
        const status = (g.status || '').toLowerCase();
        const grnNum = g.grn_number || g.grnNumber;
        const hasNumber = grnNum && grnNum !== '' && !grnNum.startsWith('DRAFT-');
        return hasNumber && status !== 'draft';
      })
      .map(g => g.grn_number || g.grnNumber)
      .filter(n => n && n.startsWith('GRN-') && !n.startsWith('DRAFT-'))
      .map(n => parseInt(n.replace('GRN-', '')))
      .filter(n => !isNaN(n));
    
    const maxNum = numbers.length > 0 ? Math.max(...numbers) : 0;
    const nextNum = String(maxNum + 1).padStart(6, '0');
    return `GRN-${nextNum}`;
  } catch (error) {
    console.error('Error generating GRN number:', error);
    // Fallback to timestamp-based
    return `GRN-${Date.now().toString().slice(-6)}`;
  }
}

/**
 * DEPRECATED: Do NOT generate batch_number in frontend.
 * Batch number is generated by DB (fn_generate_batch_number_from_grn) in format:
 * BATCH-{GRN_NUMBER}-{YYYYMMDD}-{SEQ}
 * This function is kept only for legacy/fallback when loading old data.
 */
function computeBatchNumber(batch) {
  // Only use if batch already has a DB-generated batch_number (e.g. from load)
  const dbNum = batch.batch_number || batch.batchNumber;
  if (dbNum && String(dbNum).trim()) return String(dbNum).trim();
  return null; // Never generate; let DB do it
}

/**
 * Insert a new row in inventory_batches for this GRN batch. One row per batch — no upsert/merge.
 * batch_number is generated by DB (BATCH-{GRN}-{YYYYMMDD}-{SEQ}); no UUID/random fragment.
 * Returns { batch_number } so caller can sync grn_batches to the same business format.
 */
async function insertInventoryBatchFromGrnBatch(supabase, batch) {
  const itemId = batch.itemId || batch.item_id;
  const grnId = batch.grnId || batch.grn_id;
  const expiryDate = batch.expiryDate || batch.expiry_date;
  if (!itemId || !grnId) return null;
  try {
    const row = {
      item_id: itemId,
      expiry_date: expiryDate || null,
      received_from_grn_id: grnId,
      qc_status: 'HOLD'
    };
    const { data, error } = await supabase
      .from('inventory_batches')
      .insert(row)
      .select('id, batch_number')
      .single();
    if (error) {
      console.warn('⚠️ inventory_batches insert:', error.message);
      return null;
    }
    return data;
  } catch (e) {
    console.warn('⚠️ inventory_batches insert failed:', e);
    return null;
  }
}

/**
 * Save batch to Supabase or localStorage
 * ISO 22000 Rule: Batch = Item + Expiry Date + GRN
 * Persists to grn_batches and inserts a new row in inventory_batches (no upsert; each batch = one row).
 */
export async function saveBatchToSupabase(batch) {
  if (USE_SUPABASE && supabaseClient) {
    try {
      const quantity = batch.quantity ?? batch.batchQuantity ?? batch.batch_quantity ?? 0;
      // Map frontend fields to database columns (handle both snake_case and camelCase)
      // IMPORTANT: Do NOT send batch_number or batch_id - DB generates batch_number via trigger
      const batchData = {
        ...(batch.id ? { id: batch.id } : {}),
        grn_id: batch.grnId || batch.grn_id,
        item_id: batch.itemId || batch.item_id,
        batch_id: null, // Will be set after inventory_batches insert
        batch_number: null, // DB generates via fn_generate_batch_number_from_grn
        expiry_date: batch.expiryDate || batch.expiry_date,
        quantity,
        qc_data: batch.qcData || batch.qc_data || null,
        qcData: batch.qcData || batch.qc_data || null, // Also include camelCase
        qc_checked_at: batch.qcCheckedAt || batch.qc_checked_at || null,
        qcCheckedAt: batch.qcCheckedAt || batch.qc_checked_at || null, // Also include camelCase
        created_by: batch.createdBy || batch.created_by || null,
        createdBy: batch.createdBy || batch.created_by || null, // Also include camelCase
        created_at: batch.createdAt || batch.created_at || new Date().toISOString(),
        updated_at: batch.updatedAt || batch.updated_at || new Date().toISOString()
      };

      const { data, error } = await supabaseClient
        .from('grn_batches')
        .insert([batchData])
        .select()
        .single();

      if (error) {
        // If table doesn't exist (404), use localStorage
        if (error.code === 'PGRST205' || error.message?.includes('not found')) {
          console.warn('⚠️ grn_batches table not found, using localStorage');
          return saveBatchToLocalStorage(batch);
        }
        // If column missing (PGRST204), try without that column
        if (error.code === 'PGRST204') {
          console.warn('⚠️ Column missing in grn_batches, trying without it:', error.message);
          // Remove problematic fields and retry
          delete batchData.qcData;
          delete batchData.qcCheckedAt;
          delete batchData.createdBy;
          const { data: retryData, error: retryError } = await supabaseClient
            .from('grn_batches')
            .insert([batchData])
            .select()
            .single();
          if (!retryError) {
            const invBatch = await insertInventoryBatchFromGrnBatch(supabaseClient, batch);
            let retryMerged = retryData;
            if (invBatch?.batch_number && retryData?.id) {
              await supabaseClient.from('grn_batches').update({ batch_number: invBatch.batch_number }).eq('id', retryData.id);
              retryMerged = { ...retryData, batch_number: invBatch.batch_number };
            }
            return { success: true, data: retryMerged };
          }
        }
        console.error('❌ Error saving batch to Supabase:', error);
        return saveBatchToLocalStorage(batch);
      }

      const invBatch = await insertInventoryBatchFromGrnBatch(supabaseClient, batch);
      let mergedData = { ...data };
      if (invBatch?.batch_number && data?.id) {
        const updatePayload = { batch_number: invBatch.batch_number };
        if (invBatch.id) updatePayload.batch_id = invBatch.id;
        await supabaseClient.from('grn_batches').update(updatePayload).eq('id', data.id);
        mergedData = { ...data, batch_number: invBatch.batch_number };
      }
      return { success: true, data: mergedData };
    } catch (error) {
      console.error('❌ Exception saving batch to Supabase:', error);
      return saveBatchToLocalStorage(batch);
    }
  } else {
    return saveBatchToLocalStorage(batch);
  }
}

function saveBatchToLocalStorage(batch) {
  try {
    const batches = JSON.parse(localStorage.getItem('sakura_grn_batches') || '[]');
    const newBatch = {
      ...batch,
      id: batch.id || `batch_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      created_at: batch.created_at || new Date().toISOString(),
      updated_at: new Date().toISOString()
    };
    batches.push(newBatch);
    localStorage.setItem('sakura_grn_batches', JSON.stringify(batches));
    return { success: true, data: newBatch };
  } catch (error) {
    console.error('Error saving batch to localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Update batch in Supabase or localStorage
 */
export async function updateBatchInSupabase(batchId, updates) {
  if (USE_SUPABASE && supabaseClient) {
    try {
      // Map frontend fields to database columns (handle both snake_case and camelCase)
      const updateData = {
        ...updates,
        updated_at: new Date().toISOString()
      };

      // Ensure both snake_case and camelCase versions are included
      if (updates.qcData !== undefined) {
        updateData.qc_data = updates.qcData;
        updateData.qcData = updates.qcData;
      }
      if (updates.qcCheckedAt !== undefined) {
        updateData.qc_checked_at = updates.qcCheckedAt;
        updateData.qcCheckedAt = updates.qcCheckedAt;
      }
      if (updates.createdBy !== undefined) {
        updateData.created_by = updates.createdBy;
        updateData.createdBy = updates.createdBy;
      }

      const { data, error } = await supabaseClient
        .from('grn_batches')
        .update(updateData)
        .eq('id', batchId)
        .select()
        .single();

      if (error) {
        // If table doesn't exist (404), use localStorage
        if (error.code === 'PGRST205' || error.message?.includes('not found')) {
          console.warn('⚠️ grn_batches table not found, using localStorage');
          return updateBatchInLocalStorage(batchId, updates);
        }
        // If column missing (PGRST204), try without that column
        if (error.code === 'PGRST204') {
          console.warn('⚠️ Column missing in grn_batches, trying without it:', error.message);
          // Remove problematic fields and retry
          delete updateData.qcData;
          delete updateData.qcCheckedAt;
          delete updateData.createdBy;
          const { data: retryData, error: retryError } = await supabaseClient
            .from('grn_batches')
            .update(updateData)
            .eq('id', batchId)
            .select()
            .single();
          if (!retryError) {
            return { success: true, data: retryData };
          }
        }
        console.error('❌ Error updating batch in Supabase:', error);
        return updateBatchInLocalStorage(batchId, updates);
      }

      return { success: true, data };
    } catch (error) {
      console.error('❌ Exception updating batch in Supabase:', error);
      return updateBatchInLocalStorage(batchId, updates);
    }
  } else {
    return updateBatchInLocalStorage(batchId, updates);
  }
}

function updateBatchInLocalStorage(batchId, updates) {
  try {
    const batches = JSON.parse(localStorage.getItem('sakura_grn_batches') || '[]');
    const index = batches.findIndex(b => b.id === batchId);
    if (index !== -1) {
      batches[index] = { ...batches[index], ...updates, updated_at: new Date().toISOString() };
      localStorage.setItem('sakura_grn_batches', JSON.stringify(batches));
      return { success: true, data: batches[index] };
    }
    return { success: false, error: 'Batch not found' };
  } catch (error) {
    console.error('Error updating batch in localStorage:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Generate unique batch ID
 * ISO 22000: Internal batch ID for traceability
 */
export async function generateBatchId(grnId, itemId, expiryDate) {
  // ISO Rule: Same Item + Same Expiry + Same GRN = Same Batch
  // Check if batch already exists
  if (USE_SUPABASE && supabaseClient) {
    try {
      const { data } = await supabaseClient
        .from('grn_batches')
        .select('id, batch_id, batchId')
        .eq('grn_id', grnId)
        .eq('item_id', itemId)
        .eq('expiry_date', expiryDate)
        .limit(1)
        .single();

      if (data) {
        return data.batch_id || data.batchId || data.id;
      }
    } catch (error) {
      // Batch doesn't exist, generate new one
    }
  }

  // Generate new batch ID: BATCH-GRN-ITEM-EXPIRY
  const grnNum = grnId.toString().slice(-6);
  const itemNum = itemId.toString().slice(-6);
  const expiryNum = expiryDate.replace(/-/g, '').slice(-8);
  return `BATCH-${grnNum}-${itemNum}-${expiryNum}`;
}

/**
 * Load batches for a specific GRN — SUPABASE ONLY (no localStorage).
 * Tries grn_batches table first, then optional views. Returns [] if none.
 */
export async function loadBatchesForGRN(grnId) {
  if (!USE_SUPABASE || !supabaseClient) return [];
  try {
    // 1) Base table — Vercel + local same data
    let { data, error } = await supabaseClient
      .from('grn_batches')
      .select('*')
      .eq('grn_id', grnId)
      .order('created_at', { ascending: false });
    if (!error && data && data.length > 0) return data;

    // 2) Optional views
    const viewResult = await supabaseClient
      .from('v_grn_all_batches')
      .select('*')
      .eq('grn_id', grnId)
      .order('created_at', { ascending: false });
    if (!viewResult.error && viewResult.data?.length) return viewResult.data;
    const view2 = await supabaseClient
      .from('v_grn_batches_with_batch_number')
      .select('*')
      .eq('grn_id', grnId)
      .order('created_at', { ascending: false });
    if (!view2.error && view2.data?.length) return view2.data;

    return data || [];
  } catch (err) {
    console.warn('loadBatchesForGRN:', err);
    return [];
  }
}

// ============================================================
// PURCHASING MODULE FUNCTIONS (SAP-STYLE ACCOUNTS PAYABLE)
// ============================================================

/**
 * Load all purchasing invoices from Supabase
 */
export async function loadPurchasingInvoicesFromSupabase() {
  const ready = await ensureSupabaseReady();
  if (!ready) return getPurchasingInvoicesFromLocalStorage();
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .select('*')
      .eq('deleted', false)
      .order('created_at', { ascending: false });
    
    if (error) {
      if (error.code === '42P01' || error.message?.includes('does not exist')) {
        console.warn('⚠️ purchasing_invoices table not found. Run migration script first.');
        return getPurchasingInvoicesFromLocalStorage();
      }
      console.error('Error loading purchasing invoices:', error);
      return getPurchasingInvoicesFromLocalStorage();
    }
    
    return data || [];
  } catch (error) {
    console.error('Exception loading purchasing invoices:', error);
    return getPurchasingInvoicesFromLocalStorage();
  }
}

function getPurchasingInvoicesFromLocalStorage() {
  try {
    return JSON.parse(localStorage.getItem('sakura_purchasing_invoices') || '[]');
  } catch (error) {
    return [];
  }
}

/**
 * ERP Document Closure: Check if Purchasing (MIRO) exists for this GRN.
 * If yes, "Create Purchasing" must be hidden (child document exists).
 */
export async function hasPurchasingForGRN(grnId) {
  if (!USE_SUPABASE || !supabaseClient || !grnId) return false;
  try {
    const { count, error } = await supabaseClient
      .from('purchasing_invoices')
      .select('id', { count: 'exact', head: true })
      .eq('grn_id', grnId)
      .eq('deleted', false);
    if (error) return false;
    return (count || 0) > 0;
  } catch {
    return false;
  }
}

/**
 * Get purchasing invoice by ID
 */
export async function getPurchasingInvoiceById(invoiceId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return getPurchasingInvoiceByIdFromLocalStorage(invoiceId);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .select('*')
      .eq('id', invoiceId)
      .single();
    
    if (error) {
      console.error('Error loading purchasing invoice:', error);
      return { success: false, error: error.message };
    }
    
    return { success: true, data };
  } catch (error) {
    console.error('Exception loading purchasing invoice:', error);
    return { success: false, error: error.message };
  }
}

function getPurchasingInvoiceByIdFromLocalStorage(invoiceId) {
  try {
    const invoices = JSON.parse(localStorage.getItem('sakura_purchasing_invoices') || '[]');
    const invoice = invoices.find(inv => inv.id === invoiceId);
    return invoice ? { success: true, data: invoice } : { success: false, error: 'Invoice not found' };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Save purchasing invoice to Supabase
 */
export async function savePurchasingInvoiceToSupabase(invoiceData) {
  if (!USE_SUPABASE || !supabaseClient) {
    return savePurchasingInvoiceToLocalStorage(invoiceData);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .insert(invoiceData)
      .select()
      .single();
    
    if (error) {
      console.error('Error saving purchasing invoice:', error);
      return { success: false, error: error.message };
    }
    
    return { success: true, data };
  } catch (error) {
    console.error('Exception saving purchasing invoice:', error);
    return { success: false, error: error.message };
  }
}

function savePurchasingInvoiceToLocalStorage(invoiceData) {
  try {
    const invoices = JSON.parse(localStorage.getItem('sakura_purchasing_invoices') || '[]');
    const newInvoice = {
      ...invoiceData,
      id: invoiceData.id || crypto.randomUUID(),
      created_at: new Date().toISOString()
    };
    invoices.push(newInvoice);
    localStorage.setItem('sakura_purchasing_invoices', JSON.stringify(invoices));
    return { success: true, data: newInvoice };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Update purchasing invoice in Supabase
 */
export async function updatePurchasingInvoiceInSupabase(invoiceId, updates) {
  if (!USE_SUPABASE || !supabaseClient) {
    return updatePurchasingInvoiceInLocalStorage(invoiceId, updates);
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .update({
        ...updates,
        updated_at: new Date().toISOString()
      })
      .eq('id', invoiceId)
      .select()
      .single();
    
    if (error) {
      console.error('Error updating purchasing invoice:', error);
      return { success: false, error: error.message };
    }
    
    return { success: true, data };
  } catch (error) {
    console.error('Exception updating purchasing invoice:', error);
    return { success: false, error: error.message };
  }
}

function updatePurchasingInvoiceInLocalStorage(invoiceId, updates) {
  try {
    const invoices = JSON.parse(localStorage.getItem('sakura_purchasing_invoices') || '[]');
    const index = invoices.findIndex(inv => inv.id === invoiceId);
    if (index === -1) {
      return { success: false, error: 'Invoice not found' };
    }
    invoices[index] = { ...invoices[index], ...updates, updated_at: new Date().toISOString() };
    localStorage.setItem('sakura_purchasing_invoices', JSON.stringify(invoices));
    return { success: true, data: invoices[index] };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Load purchasing invoice items
 */
export async function loadPurchasingInvoiceItems(invoiceId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return [];
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoice_items')
      .select('*')
      .eq('purchasing_invoice_id', invoiceId)
      .order('created_at', { ascending: true });
    
    if (error) {
      console.error('Error loading purchasing invoice items:', error);
      return [];
    }
    
    return data || [];
  } catch (error) {
    console.error('Exception loading purchasing invoice items:', error);
    return [];
  }
}

/**
 * Save purchasing invoice items
 */
export async function savePurchasingInvoiceItems(invoiceId, items) {
  if (!USE_SUPABASE || !supabaseClient) {
    return { success: false, error: 'Supabase not available' };
  }
  
  try {
    const itemsToInsert = items.map(item => ({
      ...item,
      purchasing_invoice_id: invoiceId
    }));
    
    const { data, error } = await supabaseClient
      .from('purchasing_invoice_items')
      .insert(itemsToInsert)
      .select();
    
    if (error) {
      console.error('Error saving purchasing invoice items:', error);
      return { success: false, error: error.message };
    }
    
    return { success: true, data };
  } catch (error) {
    console.error('Exception saving purchasing invoice items:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Check if purchasing invoice exists for a GRN
 */
export async function getPurchasingInvoiceByGRN(grnId) {
  if (!USE_SUPABASE || !supabaseClient) {
    return { success: false, exists: false };
  }
  
  try {
    const { data, error } = await supabaseClient
      .from('purchasing_invoices')
      .select('id, invoice_number')
      .eq('grn_id', grnId)
      .eq('deleted', false)
      .single();
    
    if (error && error.code !== 'PGRST116') { // PGRST116 = no rows returned
      console.error('Error checking purchasing invoice:', error);
      return { success: false, exists: false, error: error.message };
    }
    
    return { 
      success: true, 
      exists: !!data, 
      data 
    };
  } catch (error) {
    console.error('Exception checking purchasing invoice:', error);
    return { success: false, exists: false, error: error.message };
  }
}

// Note: supabaseClient, USE_SUPABASE, and initSupabase are already exported above

