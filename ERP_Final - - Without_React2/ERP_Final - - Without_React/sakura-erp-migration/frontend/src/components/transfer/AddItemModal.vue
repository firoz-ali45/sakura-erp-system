<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto m-4">
      <div class="sticky top-0 bg-white border-b p-6 flex justify-between items-center z-10">
        <h2 class="text-xl font-bold">Add Items</h2>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-700"><i class="fas fa-times"></i></button>
      </div>
      <div class="p-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Search Item</label>
          <p class="text-xs text-gray-500 mb-1">Search by name, SKU, barcode.</p>
          <input
            v-model="searchQuery"
            type="text"
            placeholder="Search item"
            class="w-full px-4 py-2 border rounded-lg"
            @input="debouncedSearch"
          />
          <div v-if="searchResults.length > 0" class="mt-2 border rounded-lg max-h-48 overflow-y-auto">
            <button
              v-for="it in searchResults"
              :key="it.id"
              type="button"
              @click="selectItem(it)"
              class="w-full px-4 py-2 text-left hover:bg-gray-50 flex justify-between items-center border-b last:border-b-0"
            >
              <span class="text-sm">{{ it.name }} / {{ it.sku }}</span>
              <span v-if="selectedItem?.id === it.id" class="text-xs text-[#284b44] font-semibold">Selected</span>
            </button>
          </div>
        </div>

        <div v-if="selectedItem" class="border rounded-lg p-4 bg-gray-50">
          <p class="font-medium">{{ selectedItem.name }} ({{ selectedItem.sku }})</p>
          <p class="text-sm text-gray-600 mt-1">Available: {{ formatNum(stock?.available_qty) }}</p>
          <div class="mt-3">
            <label class="text-sm font-medium">Quantity <span class="text-red-500">*</span></label>
            <input v-model.number="qty" type="number" min="0.01" step="0.01" class="w-full mt-1 px-3 py-2 border rounded-lg" />
          </div>
        </div>
      </div>
      <div class="p-6 border-t flex justify-end gap-3">
        <button @click="$emit('close')" class="px-6 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
        <button
          @click="save"
          :disabled="!selectedItem || !qty || qty <= 0 || saving"
          class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
          style="background-color: #284b44;"
        >
          {{ saving ? 'Saving...' : 'Save' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { searchInventoryItems, fetchItemStockAtLocation } from '@/services/transferEngine.js';

const props = defineProps({
  fromLocationId: { type: String, default: '' }
});
const emit = defineEmits(['close', 'save']);

const searchQuery = ref('');
const searchResults = ref([]);
const selectedItem = ref(null);
const stock = ref(null);
const qty = ref(1);
const saving = ref(false);
let searchTimeout = null;

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

function debouncedSearch() {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(async () => {
    searchResults.value = await searchInventoryItems(searchQuery.value || '', 50);
  }, 200);
}

async function selectItem(it) {
  selectedItem.value = it;
  if (props.fromLocationId) {
    const list = await fetchItemStockAtLocation(props.fromLocationId);
    stock.value = list.find((s) => s.item_id === it.id) || { available_qty: 0 };
  } else {
    stock.value = { available_qty: 0 };
  }
  qty.value = 1;
}

function save() {
  if (!selectedItem.value || !qty.value || qty.value <= 0) return;
  saving.value = true;
  emit('save', { item_id: selectedItem.value.id, requested_qty: qty.value });
  emit('close');
  saving.value = false;
}

onMounted(async () => {
  searchResults.value = await searchInventoryItems('', 50);
});
</script>
