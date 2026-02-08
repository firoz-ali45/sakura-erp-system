<template>
  <div class="min-h-screen bg-[#f0e1cd] p-6">
    <!-- Header -->
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-800" data-key="manage">Manage</h1>
    </div>

    <!-- Inventory Item Tag Section -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold text-gray-800" data-key="inventory_item_tag">Inventory Item Tag</h2>
        <button @click="openCreateTagModal" class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2">
          <i class="fas fa-plus"></i>
          <span data-key="create_tag">Create Tag</span>
        </button>
      </div>
      
      <div v-if="loading" class="text-center py-8">
        <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
        <p class="text-gray-600 mt-4">Loading tags...</p>
      </div>
      
      <div v-else-if="tags.length === 0" class="text-gray-500 text-center py-4">
        <p>No tags created yet. Click "Create Tag" to add your first tag.</p>
      </div>
      
      <div v-else class="space-y-2">
        <div 
          v-for="tag in tags" 
          :key="tag.id"
          class="tag-item flex justify-between items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
        >
          <div>
            <div class="font-medium text-gray-900">{{ tag.name }}</div>
            <div v-if="tag.nameLocalized" class="text-sm text-gray-600">{{ tag.nameLocalized }}</div>
          </div>
          <div class="flex items-center gap-4">
            <span class="text-sm text-gray-600">Inventory Items ({{ tag.itemCount || 0 }})</span>
            <button 
              @click="editTag(tag)"
              class="text-blue-600 hover:text-blue-800"
              title="Edit"
            >
              <i class="fas fa-edit"></i>
            </button>
            <button @click="deleteTag(tag.id)" class="text-red-600 hover:text-red-800" title="Delete">
              <i class="fas fa-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Supplier Tag Section -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold text-gray-800" data-key="supplier_tag">Supplier Tag</h2>
        <button @click="openCreateSupplierTagModal" class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2">
          <i class="fas fa-plus"></i>
          <span data-key="create_tag">Create Tag</span>
        </button>
      </div>
      
      <div v-if="loadingSupplierTags" class="text-center py-8">
        <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
        <p class="text-gray-600 mt-4">Loading supplier tags...</p>
      </div>
      
      <div v-else-if="supplierTags.length === 0" class="text-gray-500 text-center py-4">
        <p>No supplier tags created yet. Click "Create Tag" to add your first supplier tag.</p>
      </div>
      
      <div v-else class="space-y-2">
        <div 
          v-for="tag in supplierTags" 
          :key="tag.id"
          class="tag-item flex justify-between items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
        >
          <div class="flex items-center gap-3">
            <div>
              <div class="font-medium text-gray-900">{{ tag.name }}</div>
              <div v-if="tag.nameLocalized" class="text-sm text-gray-600">{{ tag.nameLocalized }}</div>
            </div>
            <button 
              @click="editSupplierTag(tag)"
              class="text-blue-600 hover:text-blue-800"
              title="Edit"
            >
              <i class="fas fa-edit"></i>
            </button>
          </div>
          <div class="flex items-center gap-4">
            <span 
              @click="filterSuppliersByTag(tag)" 
              class="text-sm text-gray-600 cursor-pointer hover:text-purple-600 hover:underline"
              title="Click to filter suppliers by this tag"
            >
              Suppliers ({{ tag.supplierCount || 0 }})
            </span>
            <button @click="deleteSupplierTag(tag.id)" class="text-red-600 hover:text-red-800" title="Delete">
              <i class="fas fa-trash"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Order Tag Section -->
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-xl font-bold text-gray-800" data-key="order_tag">Order Tag</h2>
        <button @click="openCreateOrderTagModal" class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2">
          <i class="fas fa-plus"></i>
          <span data-key="create_tag">Create Tag</span>
        </button>
      </div>
      
      <div class="text-gray-500 text-center py-4">
        <p>Order Tag creation - To be implemented</p>
      </div>
    </div>

    <!-- Create Supplier Tag Modal -->
    <div 
      v-if="showCreateSupplierTagModal"
      class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
      @click.self="closeCreateSupplierTagModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">{{ editingSupplierTag ? 'Edit Supplier Tag' : 'Create Supplier Tag' }}</h2>
          <button @click="closeCreateSupplierTagModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <form @submit.prevent="handleCreateSupplierTag" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name <span class="text-red-500">*</span>
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Enter the tag name"></i>
            </label>
            <input 
              v-model="newSupplierTag.name" 
              type="text" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" 
              placeholder="Enter tag name"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name Localized
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Enter the localized name (e.g., Arabic)"></i>
            </label>
            <input 
              v-model="newSupplierTag.nameLocalized" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" 
              placeholder="Enter localized name"
            >
          </div>

          <div class="flex justify-end gap-3 pt-4">
            <button 
              type="button"
              @click="closeCreateSupplierTagModal"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              type="submit"
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              {{ editingSupplierTag ? 'Update' : 'Save' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Create Inventory Item Tag Modal -->
    <div 
      v-if="showCreateModal"
      class="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
      @click.self="closeCreateTagModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">{{ editingTag ? 'Edit Inventory Item Tag' : 'Create Inventory Item Tag' }}</h2>
          <button @click="closeCreateTagModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <form @submit.prevent="handleCreateTag" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name <span class="text-red-500">*</span>
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Enter the tag name"></i>
            </label>
            <input 
              v-model="newTag.name" 
              type="text" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" 
              placeholder="Enter tag name"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name Localized
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Enter the localized name (e.g., Arabic)"></i>
            </label>
            <input 
              v-model="newTag.nameLocalized" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" 
              placeholder="Enter localized name"
            >
          </div>

          <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
            <button 
              type="button" 
              @click="closeCreateTagModal" 
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Close
            </button>
            <button 
              type="submit" 
              class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
            >
              {{ editingTag ? 'Update' : 'Save' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { translatePage, broadcastLanguageChange } from '@/utils/i18n';

const tags = ref([]);
const loading = ref(false);
const showCreateModal = ref(false);
const editingTag = ref(null);

// Supplier Tags
const supplierTags = ref([]);
const loadingSupplierTags = ref(false);
const showCreateSupplierTagModal = ref(false);
const editingSupplierTag = ref(null);
const newSupplierTag = ref({
  name: '',
  nameLocalized: ''
});
const newTag = ref({
  name: '',
  nameLocalized: ''
});

const loadTags = () => {
  loading.value = true;
  try {
    // Load from localStorage (can be migrated to API later)
    const storedTags = localStorage.getItem('inventory_item_tags');
    if (storedTags) {
      tags.value = JSON.parse(storedTags);
    } else {
      // Initialize sample tags if none exist
      initializeSampleTags();
      const storedTagsAfterInit = localStorage.getItem('inventory_item_tags');
      if (storedTagsAfterInit) {
        tags.value = JSON.parse(storedTagsAfterInit);
      }
    }
  } catch (error) {
    console.error('Error loading tags:', error);
  } finally {
    loading.value = false;
  }
};

const initializeSampleTags = () => {
  const existingTags = localStorage.getItem('inventory_item_tags');
  if (!existingTags || JSON.parse(existingTags).length === 0) {
    const sampleTags = [
      { id: 'tag-1', name: 'Wadi Warehouse item', nameLocalized: 'عنصر مستودع وادي', itemCount: 75, createdAt: new Date().toISOString() },
      { id: 'tag-2', name: 'Fresh Items Transfer Request', nameLocalized: 'طلب نقل العناصر الطازجة', itemCount: 8, createdAt: new Date().toISOString() },
      { id: 'tag-3', name: 'Warehouse Items for Sakura Wadi', nameLocalized: 'عناصر المستودع لساكورا وادي', itemCount: 50, createdAt: new Date().toISOString() },
      { id: 'tag-4', name: 'FAJER DAILY (SPOT CHECK)', nameLocalized: 'فجر يومي (فحص عشوائي)', itemCount: 2, createdAt: new Date().toISOString() },
      { id: 'tag-5', name: 'MADINA DAILY (SPOT CHECK)', nameLocalized: 'المدينة يومي (فحص عشوائي)', itemCount: 3, createdAt: new Date().toISOString() },
      { id: 'tag-6', name: 'WADI DAILY (SPOT CHECK)', nameLocalized: 'وادي يومي (فحص عشوائي)', itemCount: 2, createdAt: new Date().toISOString() },
      { id: 'tag-7', name: 'RAJHI DAILY (SPOT CHECK)', nameLocalized: 'راجحي يومي (فحص عشوائي)', itemCount: 4, createdAt: new Date().toISOString() },
      { id: 'tag-8', name: 'JAMYEEN DAILY (SPOT CHECK)', nameLocalized: 'جميعين يومي (فحص عشوائي)', itemCount: 6, createdAt: new Date().toISOString() },
      { id: 'tag-9', name: 'NUGRA DAILY (SPOT CHECK)', nameLocalized: 'نجرة يومي (فحص عشوائي)', itemCount: 4, createdAt: new Date().toISOString() }
    ];
    localStorage.setItem('inventory_item_tags', JSON.stringify(sampleTags));
  }
};

const openCreateTagModal = () => {
  editingTag.value = null;
  showCreateModal.value = true;
  newTag.value = { name: '', nameLocalized: '' };
};

const closeCreateTagModal = () => {
  showCreateModal.value = false;
  editingTag.value = null;
  newTag.value = { name: '', nameLocalized: '' };
};

const editTag = (tag) => {
  editingTag.value = tag;
  newTag.value = {
    name: tag.name,
    nameLocalized: tag.nameLocalized || tag.name
  };
  showCreateModal.value = true;
};

const handleCreateTag = () => {
  const name = newTag.value.name.trim();
  const nameLocalized = newTag.value.nameLocalized.trim();
  
  if (!name) {
    showNotification('Please enter a tag name', 'warning');
    return;
  }
  
  // Get existing tags
  const existingTags = JSON.parse(localStorage.getItem('inventory_item_tags') || '[]');
  
  if (editingTag.value) {
    // Update existing tag
    const index = existingTags.findIndex(t => t.id === editingTag.value.id);
    if (index !== -1) {
      existingTags[index] = {
        ...existingTags[index],
        name: name,
        nameLocalized: nameLocalized || name,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('inventory_item_tags', JSON.stringify(existingTags));
      showNotification('Tag updated successfully!', 'success');
    }
  } else {
    // Check if tag already exists
    if (existingTags.some(tag => tag.name.toLowerCase() === name.toLowerCase())) {
      showNotification('A tag with this name already exists', 'warning');
      return;
    }
    
    // Create new tag
    const tag = {
      id: 'tag-' + Date.now(),
      name: name,
      nameLocalized: nameLocalized || name,
      itemCount: 0,
      createdAt: new Date().toISOString()
    };
    
    existingTags.push(tag);
    localStorage.setItem('inventory_item_tags', JSON.stringify(existingTags));
    showNotification('Tag created successfully!', 'success');
  }
  
  closeCreateTagModal();
  loadTags();
};

const deleteTag = async (tagId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Tag',
    message: 'Are you sure you want to delete this tag? This will unlink it from all items.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  if (!confirmed) {
    return;
  }
  
  const existingTags = JSON.parse(localStorage.getItem('inventory_item_tags') || '[]');
  const filteredTags = existingTags.filter(tag => tag.id !== tagId);
  localStorage.setItem('inventory_item_tags', JSON.stringify(filteredTags));
  
  // Also remove from items
  const items = JSON.parse(localStorage.getItem('inventory_items') || '[]');
  items.forEach(item => {
    if (item.tags && item.tags.includes(tagId)) {
      item.tags = item.tags.filter(id => id !== tagId);
    }
  });
  localStorage.setItem('inventory_items', JSON.stringify(items));
  
  loadTags();
};

// Supplier Tags Functions
const loadSupplierTags = async () => {
  loadingSupplierTags.value = true;
  try {
    const stored = localStorage.getItem('supplier_tags');
    if (stored) {
      supplierTags.value = JSON.parse(stored);
      
      // Count suppliers for each tag
      const suppliers = JSON.parse(localStorage.getItem('suppliers') || '[]');
      supplierTags.value.forEach(tag => {
        let count = 0;
        suppliers.forEach(supplier => {
          if (!supplier.deleted) {
            const linkedTags = JSON.parse(localStorage.getItem(`supplier_${supplier.id}_tags`) || '[]');
            if (linkedTags.includes(tag.id)) {
              count++;
            }
          }
        });
        tag.supplierCount = count;
      });
    } else {
      supplierTags.value = [];
    }
  } catch (error) {
    console.error('Error loading supplier tags:', error);
    showNotification('Error loading supplier tags', 'error');
  } finally {
    loadingSupplierTags.value = false;
  }
};

const openCreateSupplierTagModal = () => {
  editingSupplierTag.value = null;
  newSupplierTag.value = {
    name: '',
    nameLocalized: ''
  };
  showCreateSupplierTagModal.value = true;
};

const closeCreateSupplierTagModal = () => {
  showCreateSupplierTagModal.value = false;
  editingSupplierTag.value = null;
  newSupplierTag.value = {
    name: '',
    nameLocalized: ''
  };
};

const handleCreateSupplierTag = () => {
  if (!newSupplierTag.value.name) {
    showNotification('Please enter a tag name', 'warning');
    return;
  }
  
  const existingTags = JSON.parse(localStorage.getItem('supplier_tags') || '[]');
  
  if (editingSupplierTag.value) {
    // Update existing tag
    const index = existingTags.findIndex(t => t.id === editingSupplierTag.value.id);
    if (index !== -1) {
      existingTags[index] = {
        ...existingTags[index],
        name: newSupplierTag.value.name,
        nameLocalized: newSupplierTag.value.nameLocalized || newSupplierTag.value.name,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('supplier_tags', JSON.stringify(existingTags));
      showNotification('Supplier tag updated successfully!', 'success');
    }
  } else {
    // Check if tag already exists
    if (existingTags.some(tag => tag.name.toLowerCase() === newSupplierTag.value.name.toLowerCase())) {
      showNotification('A supplier tag with this name already exists', 'warning');
      return;
    }
    
    // Create new tag
    const tag = {
      id: 'supplier-tag-' + Date.now(),
      name: newSupplierTag.value.name,
      nameLocalized: newSupplierTag.value.nameLocalized || newSupplierTag.value.name,
      supplierCount: 0,
      createdAt: new Date().toISOString()
    };
    
    existingTags.push(tag);
    localStorage.setItem('supplier_tags', JSON.stringify(existingTags));
    showNotification('Supplier tag created successfully!', 'success');
  }
  
  closeCreateSupplierTagModal();
  loadSupplierTags();
};

const editSupplierTag = (tag) => {
  editingSupplierTag.value = tag;
  newSupplierTag.value = {
    name: tag.name,
    nameLocalized: tag.nameLocalized || tag.name
  };
  showCreateSupplierTagModal.value = true;
};

const filterSuppliersByTag = (tag) => {
  // Navigate to suppliers page with tag filter
  if (window.parent && window.parent.loadDashboard) {
    window.parent.loadDashboard(`inventory-suppliers?tag=${encodeURIComponent(tag.name)}`);
  } else if (window.loadDashboard) {
    window.loadDashboard(`inventory-suppliers?tag=${encodeURIComponent(tag.name)}`);
  }
};

const deleteSupplierTag = async (tagId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Supplier Tag',
    message: 'Are you sure you want to delete this supplier tag? This will unlink it from all suppliers.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  if (!confirmed) {
    return;
  }
  
  const existingTags = JSON.parse(localStorage.getItem('supplier_tags') || '[]');
  const filteredTags = existingTags.filter(tag => tag.id !== tagId);
  localStorage.setItem('supplier_tags', JSON.stringify(filteredTags));
  
  // Remove from all suppliers
  const suppliers = JSON.parse(localStorage.getItem('suppliers') || '[]');
  suppliers.forEach(supplier => {
    const linkedTags = JSON.parse(localStorage.getItem(`supplier_${supplier.id}_tags`) || '[]');
    const filtered = linkedTags.filter(id => id !== tagId);
    localStorage.setItem(`supplier_${supplier.id}_tags`, JSON.stringify(filtered));
  });
  
  loadSupplierTags();
};

const openCreateOrderTagModal = () => {
  showNotification('Order Tag creation - To be implemented', 'info');
};

onMounted(() => {
  loadTags();
  loadSupplierTags();
  
  // Initialize language
  const savedLang = localStorage.getItem('portalLang') || 'en';
  translatePage(savedLang);
  
  // Listen for language changes
  const handleLanguageChange = (event) => {
    if (event.data && event.data.type === 'LANGUAGE_CHANGE') {
      translatePage(event.data.language);
    }
  };
  
  window.addEventListener('message', handleLanguageChange);
  
  // Also listen for storage changes (when language is changed in another component)
  const handleStorageChange = (e) => {
    if (e.key === 'portalLang') {
      translatePage(e.newValue || 'en');
    }
  };
  
  window.addEventListener('storage', handleStorageChange);
  
  // Cleanup
  onUnmounted(() => {
    window.removeEventListener('message', handleLanguageChange);
    window.removeEventListener('storage', handleStorageChange);
  });
});

// Notification helper
const showNotification = (message, type = 'info', duration = 3000) => {
  // Use existing notification system from HomePortal
  if (window.showNotification) {
    window.showNotification(message, type, duration);
  } else {
    // Fallback: create notification element
    const notification = document.createElement('div');
    notification.className = `sakura-notification`;
    notification.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      z-index: 10000;
      min-width: 350px;
      max-width: 500px;
      animation: slideInRight 0.3s ease-out;
    `;
    
    const bgColor = type === 'success' ? '#10b981' : type === 'error' ? '#dc2626' : type === 'warning' ? '#f59e0b' : '#3b82f6';
    
    notification.innerHTML = `
      <div style="background: ${bgColor}; color: white; padding: 16px 20px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);">
        <div style="display: flex; align-items: center; gap: 12px;">
          <i class="fas ${type === 'success' ? 'fa-check-circle' : type === 'error' ? 'fa-exclamation-circle' : type === 'warning' ? 'fa-exclamation-triangle' : 'fa-info-circle'}" style="font-size: 24px;"></i>
          <span style="flex: 1; font-size: 15px; font-weight: 500;">${message}</span>
          <button onclick="this.parentElement.parentElement.parentElement.remove()" style="background: rgba(255, 255, 255, 0.2); border: none; color: white; width: 28px; height: 28px; border-radius: 50%; cursor: pointer;">
            <i class="fas fa-times"></i>
          </button>
        </div>
      </div>
    `;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
      notification.style.animation = 'slideOutRight 0.3s ease-out';
      setTimeout(() => notification.remove(), 300);
    }, duration);
  }
};
</script>

<style scoped>
.tag-item {
  transition: background-color 0.2s;
}
</style>

