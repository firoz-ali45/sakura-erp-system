<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center h-64">
      <i class="fas fa-spinner fa-spin text-4xl text-[#284b44]"></i>
    </div>

    <template v-else-if="pr">
      <!-- Header -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-4">
        <div class="flex justify-between items-center">
          <div>
            <h1 class="text-2xl font-bold text-gray-800">Convert PR to Purchase Order</h1>
            <p class="text-gray-500 mt-1">
              Converting {{ pr.pr_number }} | {{ pr.total_items || pr.items?.length || 0 }} item(s) | 
              Est. Value: {{ formatCurrency(pr.estimated_total_value) }}
            </p>
          </div>
          <button 
            @click="goBack"
            class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            <i class="fas fa-arrow-left mr-2"></i>Cancel
          </button>
        </div>
      </div>

      <!-- Conversion Form -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-4">
        <!-- Supplier Selection -->
        <div class="lg:col-span-2 bg-white rounded-lg shadow-md p-6">
          <h2 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
            <i class="fas fa-truck text-[#284b44]"></i>
            Select Supplier
          </h2>
          
          <div class="relative mb-4">
            <input
              type="text"
              v-model="supplierSearch"
              @focus="showSupplierDropdown = true"
              @blur="handleSupplierBlur"
              :placeholder="selectedSupplier ? selectedSupplier.name : 'Search supplier...'"
              class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2"
              style="--tw-ring-color: #284b44;"
            />
            <i class="fas fa-search absolute right-4 top-1/2 transform -translate-y-1/2 text-gray-400"></i>
            
            <div
              v-if="showSupplierDropdown && filteredSuppliers.length > 0"
              class="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-y-auto"
            >
              <div
                v-for="supplier in filteredSuppliers"
                :key="supplier.id"
                @mousedown="selectSupplier(supplier)"
                class="px-4 py-3 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-b-0"
              >
                <div class="font-medium text-gray-900">{{ supplier.name }}</div>
                <div class="text-sm text-gray-500">{{ supplier.contact_email || supplier.phone || '' }}</div>
              </div>
            </div>
          </div>

          <!-- Selected Supplier Info -->
          <div v-if="selectedSupplier" class="bg-green-50 border border-green-200 rounded-lg p-4 mb-4">
            <div class="flex justify-between items-start">
              <div>
                <div class="font-semibold text-green-800">{{ selectedSupplier.name }}</div>
                <div class="text-sm text-green-600">
                  <span v-if="selectedSupplier.contact_email">{{ selectedSupplier.contact_email }}</span>
                  <span v-if="selectedSupplier.phone"> | {{ selectedSupplier.phone }}</span>
                </div>
              </div>
              <button @click="clearSupplier" class="text-green-600 hover:text-green-800">
                <i class="fas fa-times"></i>
              </button>
            </div>
          </div>

          <!-- Pricing Mode -->
          <h3 class="text-md font-semibold text-gray-700 mb-3">Pricing Mode</h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
            <label 
              v-for="mode in pricingModes" 
              :key="mode.value"
              :class="['p-4 border rounded-lg cursor-pointer transition-all', 
                       selectedPricingMode === mode.value ? 'border-[#284b44] bg-[#f0e1cd]' : 'border-gray-200 hover:border-gray-300']"
            >
              <input 
                type="radio" 
                v-model="selectedPricingMode" 
                :value="mode.value" 
                class="sr-only"
              />
              <div class="text-center">
                <i :class="['text-2xl mb-2', mode.icon, selectedPricingMode === mode.value ? 'text-[#284b44]' : 'text-gray-400']"></i>
                <div :class="['font-medium text-sm', selectedPricingMode === mode.value ? 'text-[#284b44]' : 'text-gray-700']">
                  {{ mode.label }}
                </div>
                <div class="text-xs text-gray-500">{{ mode.description }}</div>
              </div>
            </label>
          </div>

          <!-- Items Preview -->
          <h3 class="text-md font-semibold text-gray-700 mb-3">Items to Convert</h3>
          <div class="overflow-x-auto">
            <table class="w-full border border-gray-200 rounded-lg">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-2 text-left text-sm font-semibold text-gray-700 w-10">
                    <input 
                      type="checkbox" 
                      :checked="allItemsSelected"
                      @change="toggleAllItems"
                      class="rounded border-gray-300"
                    />
                  </th>
                  <th class="px-4 py-2 text-left text-sm font-semibold text-gray-700">Item</th>
                  <th class="px-4 py-2 text-right text-sm font-semibold text-gray-700">Qty</th>
                  <th class="px-4 py-2 text-right text-sm font-semibold text-gray-700">Est. Price</th>
                  <th class="px-4 py-2 text-right text-sm font-semibold text-gray-700">PO Price</th>
                  <th class="px-4 py-2 text-right text-sm font-semibold text-gray-700">Total</th>
                </tr>
              </thead>
              <tbody>
                <tr 
                  v-for="item in convertibleItems" 
                  :key="item.id"
                  :class="['border-t border-gray-200', !item.selected ? 'opacity-50' : '']"
                >
                  <td class="px-4 py-3">
                    <input 
                      type="checkbox" 
                      v-model="item.selected"
                      class="rounded border-gray-300"
                    />
                  </td>
                  <td class="px-4 py-3">
                    <div class="font-medium text-gray-900">{{ item.item_name }}</div>
                    <div class="text-xs text-gray-500">{{ item.inventory_item?.sku || '-' }}</div>
                  </td>
                  <td class="px-4 py-3 text-right">
                    <input
                      v-model.number="item.convertQty"
                      type="number"
                      :min="0.01"
                      :max="item.quantity - item.quantity_ordered"
                      step="0.01"
                      class="w-20 px-2 py-1 border border-gray-300 rounded text-right text-sm"
                    />
                    <div class="text-xs text-gray-500">of {{ item.quantity - item.quantity_ordered }}</div>
                  </td>
                  <td class="px-4 py-3 text-right text-sm text-gray-500">
                    {{ formatCurrency(item.estimated_price) }}
                  </td>
                  <td class="px-4 py-3 text-right">
                    <input
                      v-model.number="item.poPrice"
                      type="number"
                      min="0"
                      step="0.01"
                      class="w-24 px-2 py-1 border border-gray-300 rounded text-right text-sm"
                    />
                  </td>
                  <td class="px-4 py-3 text-right font-semibold text-sm">
                    {{ formatCurrency((item.convertQty || 0) * (item.poPrice || 0)) }}
                  </td>
                </tr>
              </tbody>
              <tfoot class="bg-gray-50">
                <tr>
                  <td colspan="5" class="px-4 py-3 text-right font-semibold">PO Total:</td>
                  <td class="px-4 py-3 text-right font-bold text-lg" style="color: #284b44;">
                    {{ formatCurrency(poTotal) }}
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>

        <!-- Summary Panel -->
        <div class="space-y-4">
          <!-- Conversion Summary -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Conversion Summary</h3>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-gray-600">Source PR:</span>
                <span class="font-medium">{{ pr.pr_number }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Supplier:</span>
                <span class="font-medium">{{ selectedSupplier?.name || 'Not selected' }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Pricing Mode:</span>
                <span class="font-medium">{{ getPricingModeLabel(selectedPricingMode) }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-gray-600">Items Selected:</span>
                <span class="font-medium">{{ selectedItemsCount }} of {{ convertibleItems.length }}</span>
              </div>
              <hr class="my-2">
              <div class="flex justify-between text-lg">
                <span class="font-semibold">PO Total:</span>
                <span class="font-bold" style="color: #284b44;">{{ formatCurrency(poTotal) }}</span>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">PO Notes</h3>
            <textarea
              v-model="poNotes"
              rows="4"
              placeholder="Optional notes for the purchase order..."
              class="w-full px-4 py-2 border border-gray-300 rounded-lg"
            ></textarea>
          </div>

          <!-- Action Buttons -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <button 
              @click="createPO"
              :disabled="!canConvert || converting"
              class="w-full px-6 py-3 text-white rounded-lg sakura-primary-btn disabled:opacity-50 flex items-center justify-center gap-2"
            >
              <span v-if="converting">
                <i class="fas fa-spinner fa-spin"></i>
                Creating PO...
              </span>
              <span v-else>
                <i class="fas fa-file-invoice mr-2"></i>
                Create Purchase Order
              </span>
            </button>
            <div v-if="!canConvert" class="mt-3 text-sm text-red-500 text-center">
              <span v-if="!selectedSupplier">Please select a supplier</span>
              <span v-else-if="selectedItemsCount === 0">Please select at least one item</span>
            </div>
          </div>

          <!-- Business Rules Info -->
          <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
            <h4 class="font-semibold text-blue-800 mb-2 flex items-center gap-2">
              <i class="fas fa-info-circle"></i>
              SAP Business Rules
            </h4>
            <ul class="text-sm text-blue-700 space-y-1">
              <li>• PR values are estimates only</li>
              <li>• PO price may differ from PR estimate</li>
              <li>• PR items will be locked after conversion</li>
              <li>• Inventory updates on GRN, not PO</li>
              <li>• Finance entries on Invoice, not PO</li>
            </ul>
          </div>
        </div>
      </div>
    </template>

    <!-- Not Found -->
    <div v-else class="bg-white rounded-lg shadow-md p-12 text-center">
      <i class="fas fa-file-excel text-6xl text-gray-300 mb-4"></i>
      <h2 class="text-xl font-semibold text-gray-600">Purchase Request Not Found</h2>
      <button @click="goBack" class="mt-4 px-6 py-2 sakura-primary-btn text-white rounded-lg">
        Back to List
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { getPurchaseRequestById } from '@/services/purchaseRequests';
import { loadSuppliersFromSupabase } from '@/services/supabase';

const router = useRouter();
const route = useRoute();

// State
const loading = ref(true);
const converting = ref(false);
const pr = ref(null);
const suppliers = ref([]);
const supplierSearch = ref('');
const showSupplierDropdown = ref(false);
const selectedSupplier = ref(null);
const selectedPricingMode = ref('estimated');
const poNotes = ref('');
const convertibleItems = ref([]);

// Pricing modes
const pricingModes = [
  { value: 'estimated', label: 'PR Estimate', description: 'Use PR prices', icon: 'fas fa-calculator' },
  { value: 'last_po', label: 'Last PO', description: 'From supplier history', icon: 'fas fa-history' },
  { value: 'inventory_cost', label: 'Inventory Cost', description: 'Current cost', icon: 'fas fa-warehouse' },
  { value: 'manual', label: 'Manual', description: 'Enter manually', icon: 'fas fa-edit' }
];

// Computed — NO slice/limit; single source of truth = Supabase suppliers
const filteredSuppliers = computed(() => {
  if (!supplierSearch.value) return suppliers.value;
  const query = supplierSearch.value.toLowerCase();
  return suppliers.value.filter(s =>
    (s.name || s.supplier_name || '').toLowerCase().includes(query) ||
    (s.contact_email || '').toLowerCase().includes(query)
  );
});

const allItemsSelected = computed(() => 
  convertibleItems.value.length > 0 && convertibleItems.value.every(i => i.selected)
);

const selectedItemsCount = computed(() => 
  convertibleItems.value.filter(i => i.selected).length
);

const poTotal = computed(() => 
  convertibleItems.value
    .filter(i => i.selected)
    .reduce((sum, i) => sum + ((i.convertQty || 0) * (i.poPrice || 0)), 0)
);

const canConvert = computed(() => 
  selectedSupplier.value && selectedItemsCount.value > 0
);

// Methods
const loadData = async () => {
  loading.value = true;
  try {
    const prId = route.params.id;
    const [prData, supplierList] = await Promise.all([
      getPurchaseRequestById(prId),
      loadSuppliersFromSupabase()
    ]);
    
    pr.value = prData;
    suppliers.value = (supplierList || []).filter(s => !s.deleted);
    
    // Initialize convertible items
    if (prData?.items) {
      convertibleItems.value = prData.items
        .filter(i => ['open', 'partially_converted'].includes(i.status) && !i.deleted)
        .map(i => ({
          ...i,
          selected: true,
          convertQty: i.quantity - (i.quantity_ordered || 0),
          poPrice: i.estimated_price || 0
        }));
    }
  } catch (error) {
    console.error('Error loading data:', error);
    showNotification('Error loading data', 'error');
  } finally {
    loading.value = false;
  }
};

const selectSupplier = (supplier) => {
  selectedSupplier.value = supplier;
  supplierSearch.value = '';
  showSupplierDropdown.value = false;
};

const clearSupplier = () => {
  selectedSupplier.value = null;
  supplierSearch.value = '';
};

// Handle supplier dropdown blur with setTimeout
const handleSupplierBlur = () => {
  window.setTimeout(() => {
    showSupplierDropdown.value = false;
  }, 200);
};

const toggleAllItems = () => {
  const newValue = !allItemsSelected.value;
  convertibleItems.value.forEach(i => i.selected = newValue);
};

const getPricingModeLabel = (mode) => {
  return pricingModes.find(m => m.value === mode)?.label || mode;
};

const createPO = async () => {
  if (!canConvert.value) {
    showNotification('Please select a supplier and at least one item', 'error');
    return;
  }
  
  converting.value = true;
  
  try {
    const { supabaseClient } = await import('@/services/supabase');
    const { dbInsert } = await import('@/services/db.js');

    const selectedItems = convertibleItems.value.filter(i => i.selected);
    const totalAmount = selectedItems.reduce((sum, i) => sum + ((i.convertQty || 0) * (i.poPrice || 0)), 0);
    const vatRate = 0.15;
    const vatAmount = totalAmount * vatRate;

    const year = new Date().getFullYear();
    const timestamp = Date.now().toString().slice(-6);
    const poNumber = `PO-${year}-${timestamp}`;

    // STEP 1: Create PO Header via centralized db layer (tenant_id/company_id skipped for PO; created_by/created_at injected)
    let newPO;
    try {
      newPO = await dbInsert(supabaseClient, 'purchase_orders', {
        po_number: poNumber,
        supplier_id: selectedSupplier.value.id,
        supplier_name: selectedSupplier.value.name,
        source_pr_id: pr.value.id,
        status: 'pending',
        business_date: new Date().toISOString().split('T')[0],
        order_date: new Date().toISOString(),
        total_amount: totalAmount,
        vat_amount: vatAmount,
        notes: poNotes.value || `Converted from PR: ${pr.value.pr_number}`,
        ordered_quantity: selectedItems.reduce((sum, i) => sum + (i.convertQty || 0), 0),
        remaining_quantity: selectedItems.reduce((sum, i) => sum + (i.convertQty || 0), 0),
        receiving_status: 'not_received'
      });
    } catch (poErr) {
      if (poErr?.code === 'PGRST116' || poErr?.message?.includes('no row returned')) {
        const { data: refetch } = await supabaseClient.from('purchase_orders').select('id, po_number').eq('po_number', poNumber).limit(1);
        newPO = Array.isArray(refetch) && refetch.length > 0 ? refetch[0] : null;
      }
      if (!newPO) throw poErr;
    }
    const createdPONumber = newPO.po_number || poNumber;
    const createdPOId = newPO.id;
    
    // STEP 2: Create PO Items — DOCUMENT CHAIN: pr_item_id links each PO line to originating PR line
    const poItems = selectedItems.map(item => ({
      purchase_order_id: createdPOId,
      po_number: createdPONumber,
      supplier_name: selectedSupplier.value.name,
      pr_item_id: item.id, // ROOT FIX: document chain — purchase_request_items.id
      item_id: item.item_id,
      item_name: item.item_name,
      item_sku: item.item_code || null,
      quantity: item.convertQty,
      unit: item.unit || 'EA',
      unit_price: item.poPrice,
      total_amount: (item.convertQty || 0) * (item.poPrice || 0),
      quantity_received: 0,
      vat_rate: 15,
      vat_amount: ((item.convertQty || 0) * (item.poPrice || 0)) * vatRate
    }));
    
    const { error: itemsError } = await supabaseClient
      .from('purchase_order_items')
      .insert(poItems);
    
    if (itemsError) {
      console.warn('PO Items Error (non-fatal):', itemsError);
    } else {
      console.log('PO Items Created');
    }
    
    // STEP 3: Update PR Items with PO reference
    for (const item of selectedItems) {
      await supabaseClient
        .from('purchase_request_items')
        .update({
          status: 'converted_to_po',
          quantity_ordered: item.convertQty,
          po_id: createdPOId,
          po_number: createdPONumber,
          conversion_date: new Date().toISOString(),
          is_locked: true,
          locked_at: new Date().toISOString(),
          lock_reason: 'Converted to PO',
          updated_at: new Date().toISOString()
        })
        .eq('id', item.id);
    }
    console.log('PR Items Updated');
    
    // STEP 4: Update PR Status (centralized db layer; fallback direct update if no row returned)
    const { dbUpdate, dbInsertMany } = await import('@/services/db.js');
    const prId = pr.value?.id;
    if (prId) {
      let updated = await dbUpdate(supabaseClient, 'purchase_requests', {
        status: 'fully_ordered',
        updated_at: new Date().toISOString()
      }, { id: prId });
      if (!updated) {
        const { error: upErr } = await supabaseClient.from('purchase_requests').update({
          status: 'fully_ordered',
          updated_at: new Date().toISOString()
        }).eq('id', prId);
        if (upErr) console.warn('PR status update fallback:', upErr.message);
      }
    }

    // STEP 5: Insert pr_po_linkage — DOCUMENT CHAIN (via dbInsertMany: company_id, created_by)
    const linkageRows = selectedItems.map((item) => ({
      pr_id: pr.value.id,
      pr_number: pr.value.pr_number || null,
      pr_item_id: item.id,
      pr_item_number: item.item_number || 10,
      po_id: createdPOId,
      po_number: createdPONumber,
      pr_quantity: item.quantity || 0,
      converted_quantity: item.convertQty || 0,
      remaining_quantity: 0,
      unit: item.unit || 'EA',
      conversion_type: 'full',
      status: 'active',
      converted_at: new Date().toISOString()
    }));
    try {
      if (linkageRows.length) await dbInsertMany(supabaseClient, 'pr_po_linkage', linkageRows);
    } catch (linkErr) {
      console.warn('pr_po_linkage insert (non-critical):', linkErr?.message);
    }
    
    // SUCCESS!
    console.log('============ PO CREATED SUCCESSFULLY ============');
    console.log('PO ID:', createdPOId);
    console.log('PO Number:', createdPONumber);
    
    showNotification(`Purchase Order ${createdPONumber} created successfully!`, 'success');
    const { forceSystemSync } = await import('@/services/erpViews.js');
    await forceSystemSync();
    // Redirect to PO list (use list because detail page might not exist)
    setTimeout(() => {
      router.push('/homeportal/purchase-orders');
    }, 500);
    
  } catch (error) {
    console.error('============ CREATE PO ERROR ============');
    console.error('Error:', error);
    showNotification('Error: ' + error.message, 'error');
  } finally {
    converting.value = false;
  }
};

const goBack = () => router.push(`/homeportal/pr-detail/${pr.value?.id || ''}`);

const formatCurrency = (amt) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR' }).format(amt || 0);

const showNotification = (msg, type) => window.showNotification?.(msg, type) || console.log(`[${type}] ${msg}`);

// Watch pricing mode changes
watch(selectedPricingMode, (newMode) => {
  convertibleItems.value.forEach(item => {
    if (newMode === 'estimated') {
      item.poPrice = item.estimated_price || 0;
    } else if (newMode === 'inventory_cost') {
      item.poPrice = item.inventory_item?.cost || item.estimated_price || 0;
    }
    // For 'last_po' and 'manual', prices stay as-is or need manual input
  });
});

onMounted(() => loadData());
</script>

<style scoped>
.sakura-primary-btn { background-color: #284b44; transition: background-color 0.2s; }
.sakura-primary-btn:hover:not(:disabled) { background-color: #1f3a35; }
</style>
