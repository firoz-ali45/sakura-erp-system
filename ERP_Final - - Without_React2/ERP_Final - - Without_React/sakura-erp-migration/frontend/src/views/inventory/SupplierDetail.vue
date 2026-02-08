<template>
  <div class="p-6 bg-gray-50">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div class="flex items-center gap-3">
          <button 
            @click="goBack"
            class="text-gray-600 hover:text-gray-800"
          >
            <i class="fas fa-arrow-left mr-2"></i>
            <span>Back</span>
          </button>
          <h1 class="text-2xl font-bold text-gray-800">{{ supplier?.name || 'Loading...' }}</h1>
          <span v-if="supplier?.deleted || supplier?.deletedAt" class="px-3 py-1 bg-red-100 text-red-800 rounded-full text-sm font-semibold">Deleted</span>
        </div>
        <div class="flex items-center gap-3">
          <button 
            v-if="supplier?.deleted || supplier?.deletedAt"
            @click="restoreSupplier"
            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
          >
            Restore Supplier
          </button>
          <button 
            v-if="!supplier?.deleted && !supplier?.deletedAt"
            @click="openEditModal"
            class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38]"
          >
            Edit Supplier
          </button>
        </div>
      </div>
    </div>

    <!-- Supplier Details -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <h2 class="text-lg font-semibold text-gray-800 mb-4">Supplier Details</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.name || '-' }}
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name Localized</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.nameLocalized || '-' }}
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Phone</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.phone || '-' }}
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Primary Email</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.primaryEmail || '-' }}
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Supplier Code</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.code || '-' }}
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Additional Emails</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier?.additionalEmails || '-' }}
          </div>
        </div>
        <div v-if="supplier?.contactName">
          <label class="block text-sm font-medium text-gray-700 mb-1">Contact Name</label>
          <div class="px-4 py-2 bg-gray-50 rounded-lg border border-gray-200">
            {{ supplier.contactName }}
          </div>
        </div>
      </div>
    </div>

    <!-- Tags Section -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-lg font-semibold text-gray-800">Tags</h2>
        <button 
          @click="openAddTagsModal"
          class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
        >
          Add Tags
        </button>
      </div>
      <p class="text-sm text-gray-600 mb-4">
        Add tags to help you filter and group suppliers easily. You can create tags such as Cash Suppliers, High Quality, etc.
      </p>
      <div v-if="supplierTags.length === 0" class="text-center py-8 text-gray-500">
        No tags added yet. Click "Add Tags" to add tags to this supplier.
      </div>
      <div v-else class="flex flex-wrap gap-2">
        <span 
          v-for="tag in supplierTags" 
          :key="tag.id"
          class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-sm flex items-center gap-2"
        >
          {{ tag.name }}
          <button 
            @click="removeTag(tag.id)"
            class="text-purple-700 hover:text-purple-900"
          >
            <i class="fas fa-times text-xs"></i>
          </button>
        </span>
      </div>
    </div>

    <!-- Inventory Items Section -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-lg font-semibold text-gray-800">Inventory Items</h2>
        <button 
          @click="openLinkItemsModal"
          class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300"
        >
          Link Items
        </button>
      </div>
      <p class="text-sm text-gray-600 mb-4">
        Link this supplier to the inventory items you purchase from them, and you can assign different order units and cost to each item.
      </p>
      <div v-if="linkedItems.length === 0" class="text-center py-8 text-gray-500">
        No items linked yet. Click "Link Items" to link inventory items to this supplier.
      </div>
      <div v-else class="space-y-2">
        <div 
          v-for="item in linkedItems" 
          :key="item.id"
          class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50"
        >
          <div class="flex justify-between items-center">
            <div>
              <h3 class="font-semibold text-gray-800">{{ item.name }}</h3>
              <p class="text-sm text-gray-600">SKU: {{ item.sku }}</p>
            </div>
            <button 
              @click="unlinkItem(item.id)"
              class="text-red-600 hover:text-red-800"
            >
              <i class="fas fa-unlink"></i>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Tags Modal -->
    <div 
      v-if="showAddTagsModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeAddTagsModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-800">Add tags</h2>
          <button 
            @click="closeAddTagsModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">Tags</label>
          <select 
            v-model="selectedTagId"
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
          >
            <option value="">Choose...</option>
            <option v-for="tag in availableSupplierTags" :key="tag.id" :value="tag.id">
              {{ tag.name }}
            </option>
          </select>
        </div>
        <div class="flex justify-end gap-3">
          <button 
            @click="closeAddTagsModal"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Close
          </button>
          <button 
            @click="applyTag"
            class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
          >
            Apply
          </button>
        </div>
      </div>
    </div>

    <!-- Edit Supplier Modal -->
    <div 
      v-if="showEditModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeEditModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">Edit Supplier</h2>
          <button 
            @click="closeEditModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <form @submit.prevent="saveSupplier" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name <span class="text-red-500">*</span>
              <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Supplier name"></i>
            </label>
            <input 
              v-model="editForm.name"
              type="text"
              required
              placeholder="Enter supplier name"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Supplier Code
              <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Unique supplier code"></i>
            </label>
            <input 
              v-model="editForm.code"
              type="text"
              placeholder="Enter supplier code"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Contact Name
              <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Primary contact person name"></i>
            </label>
            <input 
              v-model="editForm.contactName"
              type="text"
              placeholder="Enter contact name"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Phone
              <i class="fas fa-info-circle text-gray-400 ml-1 cursor-help" title="Contact phone number"></i>
            </label>
            <input 
              v-model="editForm.phone"
              type="tel"
              placeholder="Enter phone number"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Primary Email
            </label>
            <input 
              v-model="editForm.primaryEmail"
              type="email"
              placeholder="Enter primary email"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Additional Emails
            </label>
            <input 
              v-model="editForm.additionalEmails"
              type="text"
              placeholder="email1@example.com, email2@example.com"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
            >
          </div>

          <div class="flex justify-between items-center pt-4 border-t border-gray-200 mt-6">
            <button 
              type="button"
              @click="deleteSupplier"
              class="text-red-600 hover:text-red-800 font-semibold"
            >
              Delete Supplier
            </button>
            <div class="flex gap-3">
              <button 
                type="button"
                @click="closeEditModal"
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Close
              </button>
              <button 
                type="submit"
                class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700"
              >
                Save
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>

    <!-- Link Items Modal -->
    <div 
      v-if="showLinkItemsModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeLinkItemsModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6 pb-4 border-b">
          <h2 class="text-2xl font-bold text-gray-800">Link Items</h2>
          <button 
            @click="closeLinkItemsModal"
            class="text-gray-500 hover:text-gray-700 text-2xl"
          >
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="mb-4">
          <input 
            v-model="itemSearchQuery"
            type="text"
            placeholder="Search items by name, SKU..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500"
          >
        </div>

        <div class="border rounded-lg max-h-96 overflow-y-auto">
          <div 
            v-for="item in filteredAvailableItems" 
            :key="item.id"
            @click="toggleItemLink(item.id)"
            :class="['p-3 hover:bg-gray-100 cursor-pointer flex justify-between items-center border-b border-gray-100', isItemLinked(item.id) ? 'bg-[#284b44] bg-opacity-10' : '']"
          >
            <div class="flex-1">
              <div class="font-medium text-gray-900">{{ item.name || item.nameLocalized }}</div>
              <div v-if="item.sku" class="text-sm text-gray-500">SKU: {{ item.sku }}</div>
            </div>
            <i v-if="isItemLinked(item.id)" class="fas fa-check text-[#284b44] ml-3"></i>
          </div>
          <div v-if="filteredAvailableItems.length === 0" class="p-8 text-center text-gray-500">
            No items found
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
          <button 
            type="button"
            @click="closeLinkItemsModal"
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabaseClient, USE_SUPABASE } from '@/services/supabase';

const props = defineProps({
  supplierId: {
    type: String,
    default: null
  }
});

const route = useRoute();
const router = useRouter();

const supplier = ref(null);
const supplierTags = ref([]);
const linkedItems = ref([]);
const showAddTagsModal = ref(false);
const selectedTagId = ref('');
const availableSupplierTags = ref([]);

// Helper function to get supplier ID
const getSupplierId = () => {
  return props.supplierId || route.params.id;
};

const loadSupplier = async () => {
  try {
    const supplierId = getSupplierId();
    
    // Try Supabase first
    const { supabaseClient, USE_SUPABASE } = await import('@/services/supabase');
    if (USE_SUPABASE && supabaseClient) {
      try {
        const { data, error } = await supabaseClient
          .from('suppliers')
          .select('*')
          .eq('id', supplierId)
          .single();
        
        if (error) throw error;
        
        if (data) {
          supplier.value = {
            id: data.id,
            name: data.name,
            nameLocalized: data.name_localized || data.name,
            code: data.code || '',
            contactName: data.contact_name || '',
            phone: data.phone || '',
            primaryEmail: data.primary_email || '',
            additionalEmails: data.additional_emails || '',
            address: data.address || '',
            city: data.city || '',
            state: data.state || '',
            country: data.country || '',
            postalCode: data.postal_code || '',
            taxId: data.tax_id || '',
            paymentTerms: data.payment_terms || 30,
            creditLimit: data.credit_limit || 0,
            currency: data.currency || 'SAR',
            website: data.website || '',
            notes: data.notes || '',
            deleted: data.deleted || false,
            deletedAt: data.deleted_at || null,
            createdAt: data.created_at || new Date().toISOString(),
            updatedAt: data.updated_at || new Date().toISOString()
          };
        }
      } catch (supabaseError) {
        console.warn('Supabase load failed, trying localStorage:', supabaseError);
      }
    }
    
    // Fallback to localStorage
    if (!supplier.value) {
      const stored = localStorage.getItem('suppliers');
      const suppliersList = stored ? JSON.parse(stored) : [];
      supplier.value = suppliersList.find(s => s.id === supplierId);
    }
    
    if (!supplier.value) {
      showNotification('Supplier not found', 'error');
      goBack();
      return;
    }
    
    // Load tags
    loadSupplierTags();
    // Load linked items
    loadLinkedItems();
  } catch (error) {
    console.error('Error loading supplier:', error);
    showNotification('Error loading supplier', 'error');
  }
};

const loadSupplierTags = async () => {
  try {
    // TODO: Load from Supabase
    const stored = localStorage.getItem('supplier_tags');
    const allTags = stored ? JSON.parse(stored) : [];
    
    // Get tags linked to this supplier
    const supplierId = getSupplierId();
    const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
    const tagIds = linkedTags ? JSON.parse(linkedTags) : [];
    
    supplierTags.value = allTags.filter(tag => tagIds.includes(tag.id));
  } catch (error) {
    console.error('Error loading supplier tags:', error);
  }
};

const loadLinkedItems = async () => {
  try {
    // TODO: Load from Supabase
    const supplierId = getSupplierId();
    const linked = localStorage.getItem(`supplier_${supplierId}_items`);
    linkedItems.value = linked ? JSON.parse(linked) : [];
  } catch (error) {
    console.error('Error loading linked items:', error);
  }
};

const openAddTagsModal = async () => {
  // Load available supplier tags
  const stored = localStorage.getItem('supplier_tags');
  availableSupplierTags.value = stored ? JSON.parse(stored) : [];
  showAddTagsModal.value = true;
};

const closeAddTagsModal = () => {
  showAddTagsModal.value = false;
  selectedTagId.value = '';
};

const applyTag = async () => {
  if (!selectedTagId.value) {
    showNotification('Please select a tag', 'warning');
    return;
  }
  
  try {
    const supplierId = getSupplierId();
    const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
    const tagIds = linkedTags ? JSON.parse(linkedTags) : [];
    
    if (!tagIds.includes(selectedTagId.value)) {
      tagIds.push(selectedTagId.value);
      localStorage.setItem(`supplier_${supplierId}_tags`, JSON.stringify(tagIds));
      await loadSupplierTags();
      showNotification('Tag added successfully', 'success');
    } else {
      showNotification('Tag already added', 'warning');
    }
    
    closeAddTagsModal();
  } catch (error) {
    console.error('Error adding tag:', error);
    showNotification('Error adding tag', 'error');
  }
};

const removeTag = async (tagId) => {
  try {
    const supplierId = getSupplierId();
    const linkedTags = localStorage.getItem(`supplier_${supplierId}_tags`);
    const tagIds = linkedTags ? JSON.parse(linkedTags) : [];
    const filtered = tagIds.filter(id => id !== tagId);
    localStorage.setItem(`supplier_${supplierId}_tags`, JSON.stringify(filtered));
    await loadSupplierTags();
    showNotification('Tag removed successfully', 'success');
  } catch (error) {
    console.error('Error removing tag:', error);
    showNotification('Error removing tag', 'error');
  }
};

const showLinkItemsModal = ref(false);
const availableItems = ref([]);
const itemSearchQuery = ref('');
const linkedItemIds = ref([]);

const openLinkItemsModal = async () => {
  // Load available inventory items
  try {
    let items = [];
    
    // Try Supabase first
    if (USE_SUPABASE && supabaseClient) {
      try {
        const { data, error } = await supabaseClient
          .from('inventory_items')
          .select('id, name, name_localized, sku')
          .eq('deleted', false)
          .order('name', { ascending: true });
        
        if (error) {
          console.warn('Supabase query error:', error);
          throw error;
        }
        
        if (data && data.length > 0) {
          items = data.map(item => ({
            id: item.id,
            name: item.name || '',
            nameLocalized: item.name_localized || item.name || '',
            sku: item.sku || ''
          }));
          console.log('✅ Loaded', items.length, 'items from Supabase');
        }
      } catch (supabaseError) {
        console.warn('⚠️ Supabase load failed, trying localStorage:', supabaseError);
      }
    }
    
    // Fallback to localStorage
    if (items.length === 0) {
      const stored = localStorage.getItem('inventory_items');
      if (stored) {
        try {
          const parsedItems = JSON.parse(stored);
          if (Array.isArray(parsedItems) && parsedItems.length > 0) {
            items = parsedItems
              .filter(item => !item.deleted && (item.name || item.nameLocalized || item.name_localized))
              .map(item => ({
                id: item.id,
                name: item.name || item.nameLocalized || item.name_localized || '',
                nameLocalized: item.nameLocalized || item.name_localized || item.name || '',
                sku: item.sku || ''
              }));
            console.log('✅ Loaded', items.length, 'items from localStorage');
          }
        } catch (parseError) {
          console.error('Error parsing localStorage items:', parseError);
        }
      } else {
        console.warn('⚠️ No items found in localStorage');
      }
    }
    
    availableItems.value = items;
    console.log('📦 Total items available for linking:', items.length);
    
    if (items.length === 0) {
      showNotification('No inventory items found. Please create some items first.', 'warning');
    }
    
    // Load already linked items
    const supplierId = getSupplierId();
    const linked = localStorage.getItem(`supplier_${supplierId}_items`);
    const linkedItems = linked ? JSON.parse(linked) : [];
    linkedItemIds.value = linkedItems.map(item => item.id || item);
    
    showLinkItemsModal.value = true;
  } catch (error) {
    console.error('❌ Error loading items:', error);
    showNotification('Error loading items: ' + (error.message || 'Unknown error'), 'error');
  }
};

const closeLinkItemsModal = () => {
  showLinkItemsModal.value = false;
  itemSearchQuery.value = '';
};

const filteredAvailableItems = computed(() => {
  if (!availableItems.value || availableItems.value.length === 0) {
    return [];
  }
  
  if (!itemSearchQuery.value || itemSearchQuery.value.trim() === '') {
    return availableItems.value;
  }
  
  const query = itemSearchQuery.value.toLowerCase().trim();
  return availableItems.value.filter(item => {
    const nameMatch = item.name && item.name.toLowerCase().includes(query);
    const nameLocalizedMatch = item.nameLocalized && item.nameLocalized.toLowerCase().includes(query);
    const skuMatch = item.sku && item.sku.toLowerCase().includes(query);
    return nameMatch || nameLocalizedMatch || skuMatch;
  });
});

const isItemLinked = (itemId) => {
  return linkedItemIds.value.includes(itemId);
};

const toggleItemLink = async (itemId) => {
  try {
    const supplierId = getSupplierId();
    const linked = localStorage.getItem(`supplier_${supplierId}_items`);
    const linkedItems = linked ? JSON.parse(linked) : [];
    
    if (isItemLinked(itemId)) {
      // Unlink
      const filtered = linkedItems.filter(item => item.id !== itemId);
      localStorage.setItem(`supplier_${supplierId}_items`, JSON.stringify(filtered));
      linkedItemIds.value = linkedItemIds.value.filter(id => id !== itemId);
      showNotification('Item unlinked successfully', 'success');
    } else {
      // Link
      const item = availableItems.value.find(i => i.id === itemId);
      if (item) {
        linkedItems.push({
          id: item.id,
          name: item.name,
          sku: item.sku,
          nameLocalized: item.nameLocalized || item.name
        });
        localStorage.setItem(`supplier_${supplierId}_items`, JSON.stringify(linkedItems));
        linkedItemIds.value.push(itemId);
        showNotification('Item linked successfully', 'success');
      }
    }
    
    await loadLinkedItems();
  } catch (error) {
    console.error('Error toggling item link:', error);
    showNotification('Error updating item link', 'error');
  }
};

const unlinkItem = async (itemId) => {
  try {
    const supplierId = route.params.id;
    const linked = localStorage.getItem(`supplier_${supplierId}_items`);
    const items = linked ? JSON.parse(linked) : [];
    const filtered = items.filter(item => item.id !== itemId);
    localStorage.setItem(`supplier_${supplierId}_items`, JSON.stringify(filtered));
    await loadLinkedItems();
    showNotification('Item unlinked successfully', 'success');
  } catch (error) {
    console.error('Error unlinking item:', error);
    showNotification('Error unlinking item', 'error');
  }
};

const showEditModal = ref(false);
const editForm = ref({
  name: '',
  nameLocalized: '',
  code: '',
  contactName: '',
  phone: '',
  primaryEmail: '',
  additionalEmails: ''
});

const openEditModal = () => {
  if (!supplier.value) return;
  editForm.value = {
    name: supplier.value.name || '',
    nameLocalized: supplier.value.nameLocalized || '',
    code: supplier.value.code || '',
    contactName: supplier.value.contactName || '',
    phone: supplier.value.phone || '',
    primaryEmail: supplier.value.primaryEmail || '',
    additionalEmails: supplier.value.additionalEmails || ''
  };
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
};

const saveSupplier = async () => {
  if (!editForm.value.name || !editForm.value.name.trim()) {
    showNotification('Name is required', 'warning');
    return;
  }
  
  try {
    const supplierId = getSupplierId();
    const stored = localStorage.getItem('suppliers');
    const suppliersList = stored ? JSON.parse(stored) : [];
    const index = suppliersList.findIndex(s => s.id === supplierId);
    
    if (index !== -1) {
      suppliersList[index] = {
        ...suppliersList[index],
        ...editForm.value,
        updatedAt: new Date().toISOString()
      };
      localStorage.setItem('suppliers', JSON.stringify(suppliersList));
      await loadSupplier();
      showNotification('Supplier updated successfully', 'success');
      closeEditModal();
    }
  } catch (error) {
    console.error('Error saving supplier:', error);
    showNotification('Error saving supplier', 'error');
  }
};

const deleteSupplier = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Supplier',
    message: 'Are you sure you want to delete this supplier? This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });
  
  if (!confirmed) return;
  
  try {
    const supplierId = getSupplierId();
    // Try Supabase first
    const { deleteSupplierFromSupabase } = await import('@/services/supabase');
    const result = await deleteSupplierFromSupabase(supplierId);
    
    if (result.success) {
      showNotification('Supplier deleted successfully', 'success');
      goBack();
    } else {
      throw new Error(result.error || 'Failed to delete supplier');
    }
  } catch (error) {
    console.error('Error deleting supplier:', error);
    showNotification('Error deleting supplier: ' + (error.message || 'Unknown error'), 'error');
  }
};

const restoreSupplier = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Restore Supplier',
    message: 'Are you sure you want to restore this supplier?',
    confirmText: 'Restore',
    cancelText: 'Cancel',
    type: 'info',
    icon: 'fas fa-undo'
  });
  
  if (!confirmed) return;
  
  try {
    const supplierId = getSupplierId();
    // Try Supabase first
    const { restoreSupplierFromSupabase } = await import('@/services/supabase');
    const result = await restoreSupplierFromSupabase(supplierId);
    
    if (result.success) {
      showNotification('Supplier restored successfully', 'success');
      await loadSupplier();
    } else {
      throw new Error(result.error || 'Failed to restore supplier');
    }
  } catch (error) {
    console.error('Error restoring supplier:', error);
    showNotification('Error restoring supplier: ' + (error.message || 'Unknown error'), 'error');
  }
};

const goBack = () => {
  router.push('/homeportal/suppliers');
};

const showNotification = (message, type = 'info', duration = 3000) => {
  if (window.showNotification) {
    window.showNotification(message, type, duration);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

onMounted(() => {
  loadSupplier();
});
</script>

