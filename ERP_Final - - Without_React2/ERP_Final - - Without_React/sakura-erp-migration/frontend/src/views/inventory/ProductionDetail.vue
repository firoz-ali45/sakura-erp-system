<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading...</p>
    </div>

    <template v-else-if="order">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <router-link to="/homeportal/production" class="text-gray-600 hover:text-[#284b44]"><i class="fas fa-arrow-left"></i></router-link>
          <h1 class="text-2xl font-bold text-gray-800">Production ({{ order.production_number }})</h1>
          <span :class="['px-2 py-1 rounded text-xs font-medium', statusClass(order.status)]">{{ order.status }}</span>
        </div>
        <div class="flex gap-2">
          <button v-if="canProduce" @click="runProduce" class="px-4 py-2 rounded-lg text-white font-medium" style="background-color: #284b44;">
            <i class="fas fa-play mr-2"></i>Produce Items
          </button>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-sm font-semibold text-gray-500 uppercase mb-3">Summary</h2>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div><span class="text-gray-500 text-sm">Branch</span><p class="font-medium">{{ branchName }}</p></div>
          <div><span class="text-gray-500 text-sm">Business date</span><p class="font-medium">{{ formatDate(order.production_date) }}</p></div>
          <div><span class="text-gray-500 text-sm">Creator</span><p class="font-medium">{{ order.created_by_name || '—' }}</p></div>
          <div><span class="text-gray-500 text-sm">Number of items</span><p class="font-medium">{{ order.items?.length || 0 }}</p></div>
        </div>
        <div v-if="totalCost != null" class="mt-4 pt-4 border-t">
          <span class="text-gray-500 text-sm">Total cost (RM consumed)</span>
          <p class="font-medium text-lg">{{ formatCost(totalCost) }}</p>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold text-gray-800">Items</h2>
          <button v-if="order.status === 'draft'" @click="showAddItemModal = true" class="px-4 py-2 rounded-lg text-white text-sm" style="background-color: #284b44;">
            <i class="fas fa-plus mr-2"></i>Add Items
          </button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">SKU</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Quantity planned</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Quantity produced</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="item in order.items" :key="item.id">
                <td class="px-4 py-2 text-sm">{{ item.inventory_items?.name || item.item_id }}</td>
                <td class="px-4 py-2 text-sm text-gray-600">{{ item.inventory_items?.sku || '—' }}</td>
                <td class="px-4 py-2 text-sm text-right">{{ item.quantity_planned }} {{ item.inventory_items?.storage_unit || '' }}</td>
                <td class="px-4 py-2 text-sm text-right">{{ item.quantity_produced }} {{ item.inventory_items?.storage_unit || '' }}</td>
              </tr>
              <tr v-if="!order.items?.length">
                <td colspan="4" class="px-4 py-8 text-center text-gray-500">No items. Add items to this production order.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-semibold text-gray-800">Raw material consumption</h2>
          <button v-if="order.status === 'draft' && order.items?.length" @click="openAddConsumption" class="px-4 py-2 rounded-lg border border-gray-300 hover:bg-gray-50 text-sm">Add consumption</button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Item</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Batch</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Quantity</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Cost</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="c in order.consumption" :key="c.id">
                <td class="px-4 py-2 text-sm">{{ c.inventory_items?.name || c.item_id }}</td>
                <td class="px-4 py-2 text-sm text-gray-600">{{ c.batches?.batch_number || c.batch_id }}</td>
                <td class="px-4 py-2 text-sm text-right">{{ c.quantity }}</td>
                <td class="px-4 py-2 text-sm text-right">{{ formatCost(c.cost) }}</td>
              </tr>
              <tr v-if="!order.consumption?.length">
                <td colspan="4" class="px-4 py-8 text-center text-gray-500">No consumption lines. Add consumption before producing.</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Add Item modal -->
      <div v-if="showAddItemModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showAddItemModal = false">
        <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-lg">
          <h3 class="text-lg font-bold mb-4">Add Items</h3>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Item (FG) *</label>
              <select v-model="addItemForm.item_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg" required>
                <option value="">Select item...</option>
                <option v-for="i in inventoryItems" :key="i.id" :value="i.id">{{ i.name }} ({{ i.sku }})</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Recipe (optional)</label>
              <select v-model="addItemForm.recipe_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option value="">None</option>
                <option v-for="r in recipes" :key="r.id" :value="r.id">{{ r.name }} ({{ r.code }})</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Quantity planned *</label>
              <input v-model.number="addItemForm.quantity_planned" type="number" min="0" step="any" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
            </div>
          </div>
          <div class="flex justify-end gap-2 mt-6">
            <button type="button" @click="showAddItemModal = false" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Close</button>
            <button type="button" @click="saveAddItem" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
          </div>
        </div>
      </div>

      <!-- Add consumption modal -->
      <div v-if="showAddConsumptionModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showAddConsumptionModal = false">
        <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-lg">
          <h3 class="text-lg font-bold mb-4">Add consumption</h3>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Item (RM) *</label>
              <select v-model="consumptionForm.item_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg" @change="onConsumptionItemChange">
                <option value="">Select item...</option>
                <option v-for="i in inventoryItems" :key="i.id" :value="i.id">{{ i.name }} ({{ i.sku }})</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Batch *</label>
              <select v-model="consumptionForm.batch_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option value="">Select batch...</option>
                <option v-for="b in batchOptions" :key="b.batch_id" :value="b.batch_id">{{ b.batch_no }} — {{ b.current_qty }} available</option>
              </select>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Quantity *</label>
              <input v-model.number="consumptionForm.quantity" type="number" min="0" step="any" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Cost</label>
              <input v-model.number="consumptionForm.cost" type="number" min="0" step="any" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
            </div>
          </div>
          <div class="flex justify-end gap-2 mt-6">
            <button type="button" @click="showAddConsumptionModal = false" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Close</button>
            <button type="button" @click="saveConsumption" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">Save</button>
          </div>
        </div>
      </div>
    </template>

    <div v-else class="bg-white rounded-xl shadow-md p-12 text-center text-gray-500">
      Production order not found.
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import {
  fetchProductionOrderById,
  addProductionItem,
  addProductionConsumption,
  executeProduction,
  fetchRecipes,
  fetchInventoryItems,
  fetchBatchBalances,
  fetchBranches
} from '@/services/productionService';

const route = useRoute();
const loading = ref(true);
const order = ref(null);
const branches = ref([]);
const recipes = ref([]);
const inventoryItems = ref([]);
const batchOptions = ref([]);
const showAddItemModal = ref(false);
const showAddConsumptionModal = ref(false);
const addItemForm = ref({ item_id: '', recipe_id: '', quantity_planned: 0 });
const consumptionForm = ref({ item_id: '', batch_id: '', quantity: 0, cost: 0, production_item_id: null });

const branchName = computed(() => {
  if (!order.value?.branch_id) return '—';
  const b = branches.value.find((x) => x.id === order.value.branch_id);
  return b ? `${b.branch_name || b.branch_code} (${b.branch_code || ''})` : '—';
});

const totalCost = computed(() => {
  const c = order.value?.consumption;
  if (!c?.length) return null;
  return c.reduce((sum, x) => sum + Number(x.cost || 0), 0);
});

const canProduce = computed(() => {
  const o = order.value;
  if (!o || o.status !== 'draft' && o.status !== 'released') return false;
  const hasItems = o.items?.length > 0;
  const hasConsumption = o.consumption?.length > 0;
  return hasItems && hasConsumption;
});

function statusClass(s) {
  if (s === 'closed') return 'bg-gray-200 text-gray-700';
  if (s === 'released') return 'bg-blue-100 text-blue-800';
  return 'bg-amber-100 text-amber-800';
}

function formatDate(d) {
  if (!d) return '—';
  return new Date(d).toLocaleDateString();
}

function formatCost(v) {
  if (v == null) return '—';
  return new Intl.NumberFormat(undefined, { minimumFractionDigits: 2 }).format(v);
}

async function loadOrder() {
  const id = route.params.id;
  if (!id) return;
  try {
    order.value = await fetchProductionOrderById(id);
    const br = await fetchBranches();
    branches.value = br || [];
  } catch (e) {
    order.value = null;
  }
}

async function onConsumptionItemChange() {
  const itemId = consumptionForm.value.item_id;
  const locId = order.value?.branch_id;
  if (!itemId || !locId) { batchOptions.value = []; return; }
  try {
    batchOptions.value = await fetchBatchBalances(itemId, locId);
  } catch {
    batchOptions.value = [];
  }
}

function openAddConsumption() {
  consumptionForm.value = { item_id: '', batch_id: '', quantity: 0, cost: 0, production_item_id: null };
  batchOptions.value = [];
  showAddConsumptionModal.value = true;
}

async function saveAddItem() {
  if (!addItemForm.value.item_id || (addItemForm.value.quantity_planned || 0) <= 0) return;
  try {
    await addProductionItem(order.value.id, {
      item_id: addItemForm.value.item_id,
      recipe_id: addItemForm.value.recipe_id || null,
      quantity_planned: addItemForm.value.quantity_planned
    });
    showAddItemModal.value = false;
    addItemForm.value = { item_id: '', recipe_id: '', quantity_planned: 0 };
    await loadOrder();
  } catch (e) {
    alert(e?.message || 'Failed to add item');
  }
}

async function saveConsumption() {
  if (!consumptionForm.value.item_id || !consumptionForm.value.batch_id || (consumptionForm.value.quantity || 0) <= 0) return;
  try {
    await addProductionConsumption(order.value.id, {
      item_id: consumptionForm.value.item_id,
      batch_id: consumptionForm.value.batch_id,
      quantity: consumptionForm.value.quantity,
      cost: consumptionForm.value.cost || 0,
      production_item_id: consumptionForm.value.production_item_id
    });
    showAddConsumptionModal.value = false;
    await loadOrder();
  } catch (e) {
    alert(e?.message || 'Failed to add consumption');
  }
}

async function runProduce() {
  if (!canProduce.value) return;
  if (!confirm('Execute production? This will deduct raw materials and create finished goods batches.')) return;
  try {
    await executeProduction(order.value.id);
    await loadOrder();
  } catch (e) {
    alert(e?.message || 'Execute failed');
  }
}

onMounted(async () => {
  try {
    const [rec, items] = await Promise.all([fetchRecipes(), fetchInventoryItems()]);
    recipes.value = rec || [];
    inventoryItems.value = items || [];
  } catch {
    recipes.value = [];
    inventoryItems.value = [];
  }
  await loadOrder();
  loading.value = false;
});

watch(() => route.params.id, () => { if (route.params.id) loadOrder(); });
</script>
