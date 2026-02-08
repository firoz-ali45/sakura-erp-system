<template>
  <div class="min-h-screen bg-[#f0e1cd] p-6">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-4">
          <button @click="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
            <i class="fas fa-arrow-left"></i>
            <span>← Back</span>
          </button>
          <div class="flex items-center gap-2">
            <h1 class="text-3xl font-bold text-gray-800">Inventory Categories</h1>
            <i class="fas fa-question-circle text-gray-400 cursor-help" title="Manage inventory categories"></i>
          </div>
        </div>
        <button @click="openCreateCategoryModal" class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 flex items-center gap-2">
          <i class="fas fa-plus"></i>
          <span>+ Create Category</span>
        </button>
      </div>
    </div>

    <!-- Tabs and Filter -->
    <div class="bg-white rounded-lg shadow-md p-4 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex gap-6 border-b border-gray-200">
          <button 
            @click="switchTab('all')"
            :class="['tab-button px-4 py-2 text-gray-700', { 'active': activeTab === 'all' }]"
          >
            All
          </button>
          <button 
            @click="switchTab('deleted')"
            :class="['tab-button px-4 py-2 text-gray-700', { 'active': activeTab === 'deleted' }]"
          >
            Deleted
          </button>
        </div>
        <button @click="openFilter" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2">
          <i class="fas fa-filter"></i>
          <span>Filter</span>
        </button>
      </div>
    </div>

    <!-- Categories Table -->
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full">
          <thead class="bg-[#284b44] text-white">
            <tr>
              <th class="px-6 py-4 text-left">
                <input 
                  type="checkbox" 
                  :checked="allCategoriesSelected"
                  @change="toggleSelectAllCategories"
                  class="rounded"
                >
              </th>
              <th class="px-6 py-4 text-left font-semibold">Name</th>
              <th class="px-6 py-4 text-left font-semibold">Reference</th>
              <th class="px-6 py-4 text-left font-semibold">Created</th>
              <th class="px-6 py-4 text-left font-semibold">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-if="loading">
              <td colspan="5" class="px-6 py-12 text-center">
                <div class="flex flex-col items-center justify-center space-y-4">
                  <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin"></div>
                  <p class="text-gray-600">Loading categories...</p>
                </div>
              </td>
            </tr>
            <tr v-else-if="filteredCategories.length === 0">
              <td colspan="5" class="px-6 py-12 text-center">
                <div class="flex flex-col items-center justify-center space-y-4">
                  <div class="text-6xl mb-4">📁</div>
                  <h3 class="text-2xl font-bold text-gray-800 mb-2">No categories found</h3>
                  <p class="text-gray-600 text-lg">
                    {{ activeTab === 'deleted' ? 'No deleted categories found.' : 'No categories found. Click "Create Category" to add your first category.' }}
                  </p>
                </div>
              </td>
            </tr>
            <tr 
              v-else 
              v-for="category in filteredCategories" 
              :key="category.id"
              class="category-row hover:bg-gray-50"
            >
              <td class="px-6 py-4">
                <input 
                  type="checkbox" 
                  :value="category.id"
                  v-model="selectedCategories"
                  class="rounded"
                >
              </td>
              <td class="px-6 py-4 font-medium text-gray-900">{{ category.name }}</td>
              <td class="px-6 py-4 text-gray-700">{{ category.reference || '-' }}</td>
              <td class="px-6 py-4 text-gray-700">{{ formatDate(category.createdAt) }}</td>
              <td class="px-6 py-4">
                <div class="flex items-center gap-2">
                  <button 
                    @click="editCategory(category)"
                    class="text-blue-600 hover:text-blue-800"
                    title="Edit"
                  >
                    <i class="fas fa-edit"></i>
                  </button>
                  <button 
                    v-if="activeTab === 'deleted'"
                    @click="restoreCategory(category.id)"
                    class="text-green-600 hover:text-green-800"
                    title="Restore"
                  >
                    <i class="fas fa-undo"></i>
                  </button>
                  <button 
                    v-else
                    @click="deleteCategory(category.id)"
                    class="text-red-600 hover:text-red-800"
                    title="Delete"
                  >
                    <i class="fas fa-trash"></i>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Create/Edit Category Modal -->
    <div v-if="showCategoryModal" class="modal show" @click.self="closeCategoryModal">
      <div class="modal-content" style="max-width: 600px;">
        <div class="p-6">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-800">
              {{ editingCategory ? 'Edit Category' : 'Create Category' }}
            </h2>
            <button @click="closeCategoryModal" class="text-gray-500 hover:text-gray-700 text-2xl">
              <i class="fas fa-times"></i>
            </button>
          </div>
          <form @submit.prevent="saveCategory">
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Name <span class="text-red-500">*</span>
                </label>
                <input 
                  v-model="categoryForm.name" 
                  type="text" 
                  required 
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Name Localized
                </label>
                <input 
                  v-model="categoryForm.nameLocalized" 
                  type="text" 
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">
                  Reference
                </label>
                <input 
                  v-model="categoryForm.reference" 
                  type="text" 
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
                >
              </div>
            </div>
            <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
              <button 
                type="button" 
                @click="closeCategoryModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Cancel
              </button>
              <button 
                type="submit" 
                class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
              >
                Save
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { inventoryService } from '@/services/inventory';

const router = useRouter();

// State
const categories = ref([]);
const loading = ref(false);
const activeTab = ref('all');
const selectedCategories = ref([]);
const showCategoryModal = ref(false);
const editingCategory = ref(null);

const categoryForm = ref({
  name: '',
  nameLocalized: '',
  reference: ''
});

// Computed
const filteredCategories = computed(() => {
  let filtered = categories.value;
  
  if (activeTab.value === 'deleted') {
    filtered = filtered.filter(cat => cat.deleted === true);
  } else {
    filtered = filtered.filter(cat => cat.deleted !== true);
  }
  
  return filtered;
});

const allCategoriesSelected = computed(() => {
  return filteredCategories.value.length > 0 && 
         filteredCategories.value.every(cat => selectedCategories.value.includes(cat.id));
});

// Methods
const loadCategories = async () => {
  loading.value = true;
  try {
    const response = await inventoryService.getCategories(activeTab.value === 'deleted');
    categories.value = response.data || [];
  } catch (error) {
    console.error('Error loading categories:', error);
    showNotification('Error loading categories', 'error');
  } finally {
    loading.value = false;
  }
};

const switchTab = (tabName) => {
  activeTab.value = tabName;
  selectedCategories.value = [];
  loadCategories();
};

const toggleSelectAllCategories = () => {
  if (allCategoriesSelected.value) {
    selectedCategories.value = [];
  } else {
    selectedCategories.value = filteredCategories.value.map(cat => cat.id);
  }
};

const openCreateCategoryModal = () => {
  editingCategory.value = null;
  categoryForm.value = {
    name: '',
    nameLocalized: '',
    reference: ''
  };
  showCategoryModal.value = true;
};

const closeCategoryModal = () => {
  showCategoryModal.value = false;
  editingCategory.value = null;
  categoryForm.value = {
    name: '',
    nameLocalized: '',
    reference: ''
  };
};

const editCategory = (category) => {
  editingCategory.value = category;
  categoryForm.value = {
    name: category.name || '',
    nameLocalized: category.nameLocalized || '',
    reference: category.reference || ''
  };
  showCategoryModal.value = true;
};

const saveCategory = async () => {
  try {
    if (editingCategory.value) {
      await inventoryService.updateCategory(editingCategory.value.id, categoryForm.value);
      showNotification('Category updated successfully!', 'success');
    } else {
      await inventoryService.createCategory(categoryForm.value);
      showNotification('Category created successfully!', 'success');
    }
    closeCategoryModal();
    await loadCategories();
  } catch (error) {
    console.error('Error saving category:', error);
    showNotification(error.response?.data?.error || error.error || 'Error saving category', 'error');
  }
};

const deleteCategory = async (categoryId) => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Category',
    message: 'Are you sure you want to delete this category?',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  if (!confirmed) return;
  
  try {
    await inventoryService.deleteCategory(categoryId);
    showNotification('Category deleted successfully', 'success');
    await loadCategories();
  } catch (error) {
    console.error('Error deleting category:', error);
    showNotification(error.response?.data?.error || error.error || 'Error deleting category', 'error');
  }
};

const restoreCategory = async (categoryId) => {
  try {
    await inventoryService.restoreCategory(categoryId);
    showNotification('Category restored successfully', 'success');
    await loadCategories();
  } catch (error) {
    console.error('Error restoring category:', error);
    showNotification(error.response?.data?.error || error.error || 'Error restoring category', 'error');
  }
};

const openFilter = () => {
  console.log('Open filter');
};

const goBack = () => {
  router.push('/homeportal');
};

const formatDate = (dateString) => {
  if (!dateString) return 'Never';
  try {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-US', { 
      month: 'long', 
      day: 'numeric', 
      year: 'numeric',
      hour: 'numeric',
      minute: 'numeric'
    });
  } catch {
    return 'Invalid Date';
  }
};

const showNotification = (message, type = 'success') => {
  const notification = document.createElement('div');
  notification.className = `fixed top-4 right-4 z-[10000] px-6 py-3 rounded-lg shadow-lg flex items-center gap-2 animate-slide-in`;
  
  const colors = {
    success: 'bg-green-500 text-white',
    error: 'bg-red-500 text-white',
    warning: 'bg-yellow-500 text-white',
    info: 'bg-blue-500 text-white'
  };
  
  notification.className += ' ' + (colors[type] || colors.success);
  
  const icons = {
    success: 'fa-check-circle',
    error: 'fa-exclamation-circle',
    warning: 'fa-exclamation-triangle',
    info: 'fa-info-circle'
  };
  
  notification.innerHTML = `
    <i class="fas ${icons[type] || icons.success}"></i>
    <span>${message}</span>
  `;
  
  document.body.appendChild(notification);
  
  setTimeout(() => {
    notification.style.opacity = '0';
    notification.style.transform = 'translateX(100%)';
    setTimeout(() => {
      if (notification.parentNode) {
        notification.parentNode.removeChild(notification);
      }
    }, 300);
  }, 3000);
};

// Lifecycle
onMounted(() => {
  loadCategories();
});
</script>

<style scoped>
.tab-button.active {
  border-bottom: 2px solid #284b44;
  color: #284b44;
  font-weight: 600;
}

.category-row {
  transition: background-color 0.2s;
  cursor: pointer;
}

.category-row:hover {
  background-color: #f9fafb;
}
</style>
