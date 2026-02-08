import api from './api';
import { 
  loadItemsFromSupabase, 
  saveItemToSupabase, 
  updateItemInSupabase, 
  deleteItemFromSupabase,
  restoreItemFromSupabase,
  loadCategoriesFromSupabase,
  saveCategoryToSupabase,
  updateCategoryInSupabase,
  deleteCategoryFromSupabase,
  restoreCategoryFromSupabase
} from './supabase';

export const inventoryService = {
  // Get all items - Try Supabase first, fallback to API
  async getItems(params = {}) {
    try {
      // Try Supabase first
      const items = await loadItemsFromSupabase();
      if (items && items.length > 0) {
        return { data: items, success: true };
      }
    } catch (error) {
      console.warn('Supabase load failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.get('/inventory/items', { params });
      return response.data;
    } catch (error) {
      console.error('API load failed:', error);
      return { data: [], success: false };
    }
  },

  // Get single item
  async getItem(id) {
    const response = await api.get(`/inventory/items/${id}`);
    return response.data;
  },

  // Create item - Try Supabase first, fallback to API
  async createItem(itemData) {
    try {
      const result = await saveItemToSupabase(itemData);
      if (result.success) {
        return { data: result.data, success: true };
      }
    } catch (error) {
      console.warn('Supabase save failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.post('/inventory/items', itemData);
      return response.data;
    } catch (error) {
      console.error('API save failed:', error);
      return { success: false, error: error.message };
    }
  },

  // Update item - Try Supabase first, fallback to API
  async updateItem(id, itemData) {
    try {
      const result = await updateItemInSupabase(id, itemData);
      if (result.success) {
        return { data: result.data, success: true };
      }
    } catch (error) {
      console.warn('Supabase update failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.put(`/inventory/items/${id}`, itemData);
      return response.data;
    } catch (error) {
      console.error('API update failed:', error);
      return { success: false, error: error.message };
    }
  },

  // Delete item - Try Supabase first, fallback to API
  async deleteItem(id) {
    try {
      const result = await deleteItemFromSupabase(id);
      if (result.success) {
        return { success: true };
      }
    } catch (error) {
      console.warn('Supabase delete failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.delete(`/inventory/items/${id}`);
      return response.data;
    } catch (error) {
      console.error('API delete failed:', error);
      return { success: false, error: error.message };
    }
  },

  // Restore item - Try Supabase first, fallback to API
  async restoreItem(id) {
    try {
      const result = await restoreItemFromSupabase(id);
      if (result.success) {
        return { data: result.data, success: true };
      }
    } catch (error) {
      console.warn('Supabase restore failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.post(`/inventory/items/${id}/restore`);
      return response.data;
    } catch (error) {
      console.error('API restore failed:', error);
      // Don't throw - return error object instead
      return { 
        success: false, 
        error: error.response?.data?.error || error.message || 'Failed to restore item' 
      };
    }
  },

  // Get categories - Try Supabase first, fallback to API
  async getCategories(includeDeleted = false) {
    try {
      const categories = await loadCategoriesFromSupabase();
      if (categories && categories.length > 0) {
        // Filter deleted if needed
        if (!includeDeleted) {
          const filtered = categories.filter(cat => !cat.deleted);
          return { data: filtered, success: true };
        }
        return { data: categories, success: true };
      }
    } catch (error) {
      console.warn('Supabase categories load failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.get('/inventory/categories', {
        params: { deleted: includeDeleted }
      });
      return response.data;
    } catch (error) {
      console.error('API categories load failed:', error);
      return { data: [], success: false };
    }
  },

  // Create category - Try Supabase first, fallback to API
  async createCategory(categoryData) {
    try {
      const result = await saveCategoryToSupabase(categoryData);
      if (result.success) {
        return { data: result.data, success: true };
      }
    } catch (error) {
      console.warn('Supabase category save failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.post('/inventory/categories', categoryData);
      return response.data;
    } catch (error) {
      console.error('API category save failed:', error);
      return { success: false, error: error.message };
    }
  },
  
  // Update category - Try Supabase first, fallback to API
  async updateCategory(categoryId, categoryData) {
    try {
      const result = await updateCategoryInSupabase(categoryId, categoryData);
      if (result.success) {
        return { data: result.data, success: true };
      }
    } catch (error) {
      console.warn('Supabase category update failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.put(`/inventory/categories/${categoryId}`, categoryData);
      return response.data;
    } catch (error) {
      console.error('API category update failed:', error);
      return { success: false, error: error.message };
    }
  },
  
  // Delete category - Try Supabase first, fallback to API
  async deleteCategory(categoryId) {
    try {
      const result = await deleteCategoryFromSupabase(categoryId);
      if (result.success) {
        return { success: true };
      }
    } catch (error) {
      console.warn('Supabase category delete failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.delete(`/inventory/categories/${categoryId}`);
      return response.data;
    } catch (error) {
      console.error('API category delete failed:', error);
      return { success: false, error: error.message };
    }
  },
  
  // Restore category - Try Supabase first, fallback to API
  async restoreCategory(categoryId) {
    try {
      const result = await restoreCategoryFromSupabase(categoryId);
      if (result.success) {
        return { success: true };
      }
    } catch (error) {
      console.warn('Supabase category restore failed, trying API:', error);
    }
    
    // Fallback to API
    try {
      const response = await api.post(`/inventory/categories/${categoryId}/restore`);
      return response.data;
    } catch (error) {
      console.error('API category restore failed:', error);
      return { success: false, error: error.message };
    }
  },

  // Bulk import
  async bulkImport(items) {
    const response = await api.post('/inventory/items/bulk-import', { items });
    return response.data;
  }
};

