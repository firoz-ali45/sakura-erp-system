<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Header -->
    <div class="bg-white rounded-lg shadow-md p-6 mb-4">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-2xl font-bold text-gray-800">
            {{ isEditMode ? 'Edit Purchase Request' : 'Create Purchase Request' }}
          </h1>
          <p class="text-gray-500 mt-1">
            {{ isEditMode ? `Editing ${formData.prNumber}` : `Next PR: ${nextPRNumber}` }}
          </p>
        </div>
        <button 
          @click="goBack"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
        >
          <i class="fas fa-arrow-left"></i>
          <span>Back to List</span>
        </button>
      </div>
    </div>

    <!-- Form -->
    <form @submit.prevent class="space-y-6">
      <!-- Header Information -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <h2 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
          <i class="fas fa-info-circle text-[#284b44]"></i>
          Request Information
        </h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Department <span class="text-red-500">*</span>
            </label>
            <select 
              v-model="formData.department" 
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            >
              <option value="">Select Department</option>
              <option v-for="dept in departments" :key="dept" :value="dept">{{ dept }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Cost Center</label>
            <input 
              v-model="formData.costCenter" 
              type="text"
              placeholder="e.g., CC001"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Priority <span class="text-red-500">*</span>
            </label>
            <select 
              v-model="formData.priority" 
              required
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            >
              <option value="low">Low</option>
              <option value="normal">Normal</option>
              <option value="high">High</option>
              <option value="urgent">Urgent</option>
              <option value="critical">Critical</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Business Date
              <span class="text-xs text-gray-400 ml-1">(System Date - Auto)</span>
            </label>
            <input 
              :value="formData.businessDate" 
              type="date"
              disabled
              readonly
              class="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-100 text-gray-600 cursor-not-allowed"
              title="Business Date is automatically set to today's date (SAP BUDAT standard)"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Required Date <span class="text-red-500">*</span>
            </label>
            <input 
              v-model="formData.requiredDate" 
              type="date"
              required
              :min="formData.businessDate"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            />
          </div>
        </div>
        <div class="mt-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
          <textarea 
            v-model="formData.notes" 
            rows="3"
            placeholder="Additional notes or instructions..."
            class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
            style="--tw-ring-color: #284b44;"
          ></textarea>
        </div>
      </div>

      <!-- Items Section -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold text-gray-800 flex items-center gap-2">
            <i class="fas fa-list text-[#284b44]"></i>
            Request Items
          </h2>
          <button 
            type="button"
            @click="addItem"
            class="px-4 py-2 text-white rounded-lg flex items-center gap-2 sakura-primary-btn"
          >
            <i class="fas fa-plus"></i>
            <span>Add Item</span>
          </button>
        </div>

        <div v-if="formData.items.length === 0" class="text-center py-12 border-2 border-dashed border-gray-300 rounded-lg">
          <i class="fas fa-box-open text-5xl text-gray-300 mb-4"></i>
          <p class="text-gray-500">No items added yet</p>
          <button 
            type="button"
            @click="addItem"
            class="mt-4 px-4 py-2 text-[#284b44] border border-[#284b44] rounded-lg hover:bg-[#284b44] hover:text-white transition-colors"
          >
            Add First Item
          </button>
        </div>

        <!-- Enterprise SAP-Style Data Grid -->
        <div v-else class="pr-items-grid-container">
          <table class="pr-items-grid">
            <thead>
              <tr>
                <th class="col-num">#</th>
                <th class="col-item">Item Name</th>
                <th class="col-sku">SKU</th>
                <th class="col-qty">Qty</th>
                <th class="col-unit">Unit</th>
                <th class="col-price">Est. Price</th>
                <th class="col-total">Line Total</th>
                <th class="col-supplier">Supplier</th>
                <th class="col-actions">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr 
                v-for="(item, index) in formData.items" 
                :key="index" 
                :class="['pr-item-row', index % 2 === 0 ? 'row-even' : 'row-odd']"
              >
                <td class="col-num">{{ (index + 1) * 10 }}</td>
                <td class="col-item">
                  <div class="item-search-wrapper">
                    <input
                      type="text"
                      :value="itemSearchQueries[index] !== undefined ? itemSearchQueries[index] : getItemDisplayName(index)"
                      @input="itemSearchQueries[index] = $event.target.value; showItemDropdowns[index] = true"
                      @focus="showItemDropdowns[index] = true; itemSearchQueries[index] = itemSearchQueries[index] || ''"
                      @blur="handleItemBlur(index)"
                      placeholder="Search item..."
                      class="grid-input"
                    />
                    <div
                      v-if="showItemDropdowns[index] && getFilteredItems(index).length > 0"
                      class="item-dropdown"
                    >
                      <div
                        v-for="invItem in getFilteredItems(index)"
                        :key="invItem.id"
                        @mousedown="selectItem(index, invItem)"
                        class="dropdown-item"
                      >
                        <div class="item-name">{{ invItem.name }}</div>
                        <div class="item-meta">SKU: {{ invItem.sku || 'N/A' }} | {{ formatCurrency(invItem.cost) }}</div>
                      </div>
                    </div>
                  </div>
                </td>
                <td class="col-sku">
                  <span class="sku-display">{{ item.sku || '-' }}</span>
                </td>
                <td class="col-qty">
                  <input 
                    v-model.number="item.quantity"
                    type="number"
                    min="0.01"
                    step="0.01"
                    required
                    @input="calculateItemTotal(index)"
                    class="grid-input grid-input-number"
                  />
                </td>
                <td class="col-unit">
                  <select v-model="item.unit" class="grid-select">
                    <option value="EA">EA</option>
                    <option value="KG">KG</option>
                    <option value="L">L</option>
                    <option value="BOX">BOX</option>
                    <option value="CS">CS</option>
                    <option value="PCS">PCS</option>
                  </select>
                </td>
                <td class="col-price">
                  <input 
                    v-model.number="item.estimatedPrice"
                    type="number"
                    min="0"
                    step="0.01"
                    @input="calculateItemTotal(index)"
                    class="grid-input grid-input-number"
                  />
                </td>
                <td class="col-total">
                  <span class="total-display">{{ formatCurrency(item.total || 0) }}</span>
                </td>
                <td class="col-supplier">
                  <select v-model="item.suggestedSupplierId" class="grid-select">
                    <option value="">-</option>
                    <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">
                      {{ supplier.name }}
                    </option>
                  </select>
                </td>
                <td class="col-actions">
                  <button 
                    type="button"
                    @click="removeItem(index)"
                    class="btn-delete"
                    title="Remove Item"
                  >
                    <i class="fas fa-trash-alt"></i>
                  </button>
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="totals-row">
                <td colspan="6" class="totals-label">Estimated Total Value:</td>
                <td class="totals-value">{{ formatCurrency(estimatedTotal) }}</td>
                <td colspan="2"></td>
              </tr>
            </tfoot>
          </table>
        </div>
      </div>

      <!-- Actions -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="flex justify-between items-center">
          <div class="text-sm text-gray-500">
            <span v-if="!isEditMode">This PR will be saved as <strong>Draft</strong> and can be edited before submission.</span>
            <span v-else>Save changes to update the purchase request.</span>
          </div>
          <div class="flex gap-3">
            <button 
              type="button"
              @click="goBack"
              class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              Cancel
            </button>
            <button 
              type="button"
              @click="handleSaveDraft"
              :disabled="saving || formData.items.length === 0"
              class="px-6 py-2 text-white rounded-lg sakura-primary-btn disabled:opacity-50"
            >
              <span v-if="saving">
                <i class="fas fa-spinner fa-spin mr-2"></i>
                Saving...
              </span>
              <span v-else>
                <i class="fas fa-save mr-2"></i>
                {{ isEditMode ? 'Update PR' : 'Save as Draft' }}
              </span>
            </button>
            <button 
              v-if="!isEditMode"
              type="button"
              @click="handleSaveSubmit"
              :disabled="saving || formData.items.length === 0"
              class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50"
            >
              <i class="fas fa-paper-plane mr-2"></i>
              Save & Submit
            </button>
          </div>
        </div>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { 
  createPurchaseRequest, 
  updatePurchaseRequest,
  getPurchaseRequestById,
  submitPRForApproval,
  getNextPRNumberPreview
} from '@/services/purchaseRequests';
import { loadItemsFromSupabase, loadSuppliersFromSupabase, loadDepartmentsFromSupabase } from '@/services/supabase';

const router = useRouter();
const route = useRoute();

// State
const loading = ref(false);
const saving = ref(false);
const isEditMode = ref(false);
const nextPRNumber = ref('PR-XXXX-XXXXXX');
const inventoryItems = ref([]);
const suppliers = ref([]);

// Item search state
const itemSearchQueries = reactive({});
const showItemDropdowns = reactive({});

// Form data
const formData = ref({
  id: null,
  prNumber: '',
  department: '',
  costCenter: '',
  priority: 'normal',
  businessDate: new Date().toISOString().split('T')[0],
  requiredDate: '',
  notes: '',
  items: []
});

// Departments from DB (single source of truth) - loaded in loadInitialData
const departments = ref([]);

// Computed
const estimatedTotal = computed(() => {
  return formData.value.items.reduce((sum, item) => sum + (item.total || 0), 0);
});

// Methods
const loadInitialData = async () => {
  loading.value = true;
  try {
    const [items, supplierList, deptList, prNumber] = await Promise.all([
      loadItemsFromSupabase(),
      loadSuppliersFromSupabase(),
      loadDepartmentsFromSupabase(),
      getNextPRNumberPreview()
    ]);

    inventoryItems.value = (items || []).filter(i => !i.deleted);
    suppliers.value = (supplierList || []).filter(s => !s.deleted);
    departments.value = (deptList || []).map(d => (typeof d === 'object' ? (d.name || d.code || '') : String(d))).filter(Boolean);
    nextPRNumber.value = prNumber;
    
    // Check if editing existing PR
    const editId = route.query.edit;
    if (editId) {
      await loadExistingPR(editId);
    }
  } catch (error) {
    console.error('Error loading data:', error);
    showNotification('Error loading data', 'error');
  } finally {
    loading.value = false;
  }
};

const loadExistingPR = async (prId) => {
  try {
    const pr = await getPurchaseRequestById(prId);
    if (pr) {
      isEditMode.value = true;
      formData.value = {
        id: pr.id,
        prNumber: pr.pr_number,
        department: pr.department,
        costCenter: pr.cost_center || '',
        priority: pr.priority,
        businessDate: pr.business_date,
        requiredDate: pr.required_date,
        notes: pr.notes || '',
        items: (pr.items || []).map(item => ({
          itemId: item.item_id,
          itemName: item.item_name,
          sku: item.inventory_item?.sku || '',
          quantity: item.quantity,
          unit: item.unit || 'EA',
          estimatedPrice: item.estimated_price || 0,
          total: item.quantity * (item.estimated_price || 0),
          suggestedSupplierId: item.suggested_supplier_id || ''
        }))
      };
    }
  } catch (error) {
    console.error('Error loading PR:', error);
    showNotification('Error loading purchase request', 'error');
  }
};

const addItem = () => {
  const newIndex = formData.value.items.length;
  formData.value.items.push({
    itemId: null,
    itemName: '',
    sku: '',
    quantity: 1,
    unit: 'EA',
    estimatedPrice: 0,
    total: 0,
    suggestedSupplierId: ''
  });
  itemSearchQueries[newIndex] = '';
  showItemDropdowns[newIndex] = false;
};

const removeItem = (index) => {
  formData.value.items.splice(index, 1);
  delete itemSearchQueries[index];
  delete showItemDropdowns[index];
};

const getFilteredItems = (index) => {
  const query = (itemSearchQueries[index] || '').toLowerCase();
  const selectedIds = formData.value.items
    .filter((_, i) => i !== index && formData.value.items[i]?.itemId)
    .map(item => item.itemId);
  
  let filtered = inventoryItems.value.filter(item => !selectedIds.includes(item.id));
  
  if (query) {
    filtered = filtered.filter(item => 
      (item.name || '').toLowerCase().includes(query) ||
      (item.sku || '').toLowerCase().includes(query)
    );
  }
  
  return filtered;
};

const getItemDisplayName = (index) => {
  const item = formData.value.items[index];
  return item?.itemName || '';
};

const selectItem = (index, invItem) => {
  formData.value.items[index].itemId = invItem.id;
  formData.value.items[index].itemName = invItem.name;
  formData.value.items[index].sku = invItem.sku || '';
  formData.value.items[index].estimatedPrice = invItem.cost || 0;
  formData.value.items[index].unit = invItem.storage_unit || 'EA';
  calculateItemTotal(index);
  
  itemSearchQueries[index] = invItem.name;
  showItemDropdowns[index] = false;
};

// Handle blur with delay to allow dropdown click
const handleItemBlur = (index) => {
  window.setTimeout(() => {
    showItemDropdowns[index] = false;
  }, 200);
};

const calculateItemTotal = (index) => {
  const item = formData.value.items[index];
  item.total = (item.quantity || 0) * (item.estimatedPrice || 0);
};

const validateForm = () => {
  console.log('🔍 validateForm() called');
  console.log('Department:', formData.value.department);
  console.log('Required Date:', formData.value.requiredDate);
  console.log('Items count:', formData.value.items.length);
  console.log('Items:', formData.value.items);
  
  if (!formData.value.department) {
    const msg = 'Please select a department';
    showNotification(msg, 'warning');
    alert('Validation Error: ' + msg);
    return false;
  }
  if (!formData.value.requiredDate) {
    const msg = 'Please select a required date';
    showNotification(msg, 'warning');
    alert('Validation Error: ' + msg);
    return false;
  }
  if (formData.value.items.length === 0) {
    const msg = 'Please add at least one item';
    showNotification(msg, 'warning');
    alert('Validation Error: ' + msg);
    return false;
  }
  
  for (let i = 0; i < formData.value.items.length; i++) {
    const item = formData.value.items[i];
    console.log(`Item ${i}:`, item);
    if (!item.itemName) {
      const msg = `Please select an item for row ${i + 1}`;
      showNotification(msg, 'warning');
      alert('Validation Error: ' + msg);
      return false;
    }
    if (item.quantity <= 0) {
      const msg = `Please enter a valid quantity for ${item.itemName}`;
      showNotification(msg, 'warning');
      alert('Validation Error: ' + msg);
      return false;
    }
  }
  
  console.log('✅ All validations passed');
  return true;
};

const savePR = async () => {
  console.log('🔵 savePR() called');
  
  if (!validateForm()) {
    console.log('❌ Form validation failed');
    return;
  }
  
  console.log('✅ Form validation passed');
  saving.value = true;
  
  try {
    // Get current user info - with fallback
    let currentUser = {};
    try {
      currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
    } catch (e) {
      console.warn('Could not parse user from localStorage');
    }
    
    console.log('👤 Current User:', currentUser);
    
    // Force business date to today (SAP BUDAT standard)
    const today = new Date().toISOString().split('T')[0];
    
    const prData = {
      requesterId: currentUser.id || null, // Allow null for user ID
      requesterName: currentUser.name || currentUser.email || 'System User',
      department: formData.value.department,
      costCenter: formData.value.costCenter || null,
      priority: formData.value.priority || 'normal',
      businessDate: today, // Always use system date
      requiredDate: formData.value.requiredDate,
      notes: formData.value.notes || null,
      items: formData.value.items.map(item => ({
        itemId: item.itemId || null,
        itemName: item.itemName,
        description: '',
        quantity: parseFloat(item.quantity) || 1,
        unit: item.unit || 'EA',
        estimatedPrice: parseFloat(item.estimatedPrice) || 0,
        suggestedSupplierId: item.suggestedSupplierId || null
      }))
    };
    
    // DEBUG: Log data being saved
    console.log('========== SAVING PR (DRAFT) ==========');
    console.log('PR Header Data:', JSON.stringify(prData, null, 2));
    console.log('PR Items:', JSON.stringify(prData.items, null, 2));
    console.log('=========================================');
    
    let result;
    if (isEditMode.value) {
      console.log('📝 Updating existing PR:', formData.value.id);
      result = await updatePurchaseRequest(formData.value.id, prData);
    } else {
      console.log('📝 Creating new PR...');
      result = await createPurchaseRequest(prData);
    }
    
    // DEBUG: Log result
    console.log('📦 Save PR Result:', result);
    
    if (result && result.success) {
      showNotification(
        isEditMode.value ? 'Purchase request updated' : `Purchase request ${result.data?.pr_number || ''} created as draft`,
        'success'
      );
      router.push('/homeportal/pr');
    } else {
      const errorMsg = result?.error || 'Failed to save purchase request';
      console.error('❌ PR Save Failed:', errorMsg);
      showNotification(errorMsg, 'error');
      alert('PR Save Error: ' + errorMsg); // Also show alert for visibility
    }
  } catch (error) {
    console.error('❌ Exception saving PR:', error);
    const errorMsg = 'Error saving purchase request: ' + (error.message || String(error));
    showNotification(errorMsg, 'error');
    alert('PR Save Exception: ' + errorMsg); // Also show alert for visibility
  } finally {
    saving.value = false;
  }
};

const saveAndSubmit = async () => {
  console.log('🔵 saveAndSubmit() called');
  
  if (!validateForm()) {
    console.log('❌ Form validation failed');
    return;
  }
  
  console.log('✅ Form validation passed');
  saving.value = true;
  
  try {
    // Get current user info - with fallback
    let currentUser = {};
    try {
      currentUser = JSON.parse(localStorage.getItem('sakura_current_user') || '{}');
    } catch (e) {
      console.warn('Could not parse user from localStorage');
    }
    
    console.log('👤 Current User:', currentUser);
    
    // Force business date to today (SAP BUDAT standard)
    const today = new Date().toISOString().split('T')[0];
    
    const prData = {
      requesterId: currentUser.id || null,
      requesterName: currentUser.name || currentUser.email || 'System User',
      department: formData.value.department,
      costCenter: formData.value.costCenter || null,
      priority: formData.value.priority || 'normal',
      businessDate: today, // Always use system date
      requiredDate: formData.value.requiredDate,
      notes: formData.value.notes || null,
      status: 'submitted', // Set to submitted directly
      items: formData.value.items.map(item => ({
        itemId: item.itemId || null,
        itemName: item.itemName,
        description: '',
        quantity: parseFloat(item.quantity) || 1,
        unit: item.unit || 'EA',
        estimatedPrice: parseFloat(item.estimatedPrice) || 0,
        suggestedSupplierId: item.suggestedSupplierId || null
      }))
    };
    
    // DEBUG: Log data being saved
    console.log('========== SAVING PR (SUBMIT) ==========');
    console.log('PR Header Data:', JSON.stringify(prData, null, 2));
    console.log('PR Items:', JSON.stringify(prData.items, null, 2));
    console.log('=========================================');
    
    // Create the PR first
    console.log('📝 Creating new PR with submitted status...');
    const createResult = await createPurchaseRequest(prData);
    
    console.log('📦 Create PR Result:', createResult);
    
    if (createResult && createResult.success) {
      // Then try to submit it (may fail if RPC doesn't exist - that's OK)
      try {
        const submitResult = await submitPRForApproval(createResult.data.id);
        console.log('📦 Submit PR Result:', submitResult);
        
        if (submitResult && submitResult.success) {
          showNotification(`Purchase request ${createResult.data.pr_number} created and submitted for approval`, 'success');
        } else {
          // Still show success but note the submission status
          showNotification(`PR ${createResult.data.pr_number} created. Status: draft (manual submit may be required)`, 'warning');
        }
      } catch (submitError) {
        console.warn('Submit RPC failed (PR still created):', submitError);
        showNotification(`PR ${createResult.data.pr_number} created successfully`, 'success');
      }
      router.push('/homeportal/pr');
    } else {
      const errorMsg = createResult?.error || 'Failed to create purchase request';
      console.error('❌ Create PR Failed:', errorMsg);
      showNotification(errorMsg, 'error');
      alert('PR Create Error: ' + errorMsg); // Also show alert for visibility
    }
  } catch (error) {
    console.error('❌ Exception in saveAndSubmit:', error);
    const errorMsg = 'Error processing request: ' + (error.message || String(error));
    showNotification(errorMsg, 'error');
    alert('PR Submit Exception: ' + errorMsg); // Also show alert for visibility
  } finally {
    saving.value = false;
  }
};

const goBack = () => {
  router.push('/homeportal/pr');
};

// EXPLICIT CLICK HANDLERS WITH LOGGING
const handleSaveDraft = async () => {
  console.log('🔵🔵🔵 SAVE AS DRAFT BUTTON CLICKED 🔵🔵🔵');
  alert('Save as Draft button clicked! Check console for details.');
  await savePR();
};

const handleSaveSubmit = async () => {
  console.log('🟢🟢🟢 SAVE & SUBMIT BUTTON CLICKED 🟢🟢🟢');
  alert('Save & Submit button clicked! Check console for details.');
  await saveAndSubmit();
};

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'SAR'
  }).format(amount || 0);
};

const showNotification = (message, type = 'info') => {
  if (window.showNotification) {
    window.showNotification(message, type);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

onMounted(() => {
  loadInitialData();
});
</script>

<style scoped>
.sakura-primary-btn {
  background-color: #284b44;
  transition: background-color 0.2s ease;
}

.sakura-primary-btn:hover:not(:disabled) {
  background-color: #1f3a35;
}

/* ============================================
   ENTERPRISE SAP-STYLE DATA GRID
   ============================================ */

.pr-items-grid-container {
  overflow-x: auto;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  background: #fff;
}

.pr-items-grid {
  width: 100%;
  min-width: 1000px;
  border-collapse: collapse;
  font-size: 13px;
}

/* Sticky Header */
.pr-items-grid thead {
  position: sticky;
  top: 0;
  z-index: 10;
  background: linear-gradient(180deg, #f8fafc 0%, #f1f5f9 100%);
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.pr-items-grid thead th {
  padding: 12px 8px;
  text-align: center;
  font-weight: 600;
  color: #374151;
  border-bottom: 2px solid #284b44;
  white-space: nowrap;
  text-transform: uppercase;
  font-size: 11px;
  letter-spacing: 0.5px;
}

/* Column Widths */
.col-num { width: 50px; }
.col-item { width: 22%; min-width: 180px; }
.col-sku { width: 100px; }
.col-qty { width: 80px; }
.col-unit { width: 70px; }
.col-price { width: 100px; }
.col-total { width: 110px; }
.col-supplier { width: 140px; }
.col-actions { width: 60px; }

/* Zebra Rows */
.pr-item-row {
  transition: background-color 0.15s ease;
}

.row-even {
  background-color: #ffffff;
}

.row-odd {
  background-color: #f9fafb;
}

.pr-item-row:hover {
  background-color: #e8f5e9 !important;
}

/* Table Cells */
.pr-items-grid tbody td {
  padding: 8px;
  text-align: center;
  vertical-align: middle;
  border-bottom: 1px solid #e5e7eb;
  white-space: normal;
  word-wrap: break-word;
}

/* Grid Inputs */
.grid-input {
  width: 100%;
  padding: 6px 8px;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  font-size: 13px;
  text-align: center;
  transition: border-color 0.2s, box-shadow 0.2s;
  background: #fff;
}

.grid-input:focus {
  outline: none;
  border-color: #284b44;
  box-shadow: 0 0 0 2px rgba(40, 75, 68, 0.15);
}

.grid-input-number {
  text-align: right;
  font-family: 'Roboto Mono', monospace;
}

/* Grid Select */
.grid-select {
  width: 100%;
  padding: 6px 4px;
  border: 1px solid #d1d5db;
  border-radius: 4px;
  font-size: 12px;
  text-align: center;
  background: #fff;
  cursor: pointer;
}

.grid-select:focus {
  outline: none;
  border-color: #284b44;
}

/* Item Search Wrapper */
.item-search-wrapper {
  position: relative;
  width: 100%;
}

.item-dropdown {
  position: absolute;
  z-index: 100;
  width: 100%;
  max-height: 200px;
  overflow-y: auto;
  background: #fff;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  margin-top: 2px;
}

.dropdown-item {
  padding: 8px 10px;
  cursor: pointer;
  border-bottom: 1px solid #f3f4f6;
  text-align: left;
}

.dropdown-item:hover {
  background: #e8f5e9;
}

.dropdown-item:last-child {
  border-bottom: none;
}

.item-name {
  font-weight: 500;
  color: #1f2937;
  font-size: 13px;
}

.item-meta {
  font-size: 11px;
  color: #6b7280;
  margin-top: 2px;
}

/* SKU Display */
.sku-display {
  font-family: 'Roboto Mono', monospace;
  font-size: 12px;
  color: #6b7280;
  background: #f3f4f6;
  padding: 4px 8px;
  border-radius: 4px;
  display: inline-block;
}

/* Total Display */
.total-display {
  font-weight: 600;
  color: #284b44;
  font-family: 'Roboto Mono', monospace;
}

/* Delete Button */
.btn-delete {
  padding: 6px 10px;
  background: transparent;
  border: none;
  color: #dc2626;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.2s;
}

.btn-delete:hover {
  background: #fef2f2;
  color: #b91c1c;
}

/* Footer Totals */
.pr-items-grid tfoot {
  background: linear-gradient(180deg, #f0fdf4 0%, #dcfce7 100%);
}

.totals-row td {
  padding: 14px 8px;
  border-top: 2px solid #284b44;
}

.totals-label {
  text-align: right !important;
  font-weight: 600;
  color: #374151;
  font-size: 14px;
}

.totals-value {
  text-align: center !important;
  font-weight: 700;
  color: #284b44;
  font-size: 16px;
  font-family: 'Roboto Mono', monospace;
}

/* Responsive adjustments */
@media (max-width: 1200px) {
  .pr-items-grid {
    font-size: 12px;
  }
  
  .pr-items-grid thead th {
    padding: 10px 6px;
    font-size: 10px;
  }
  
  .pr-items-grid tbody td {
    padding: 6px;
  }
}
</style>
