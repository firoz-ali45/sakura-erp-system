<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-w-md m-4">
      <div class="p-6 border-b">
        <h3 class="text-lg font-bold">Select Batch (FEFO)</h3>
        <p class="text-sm text-gray-600 mt-1">{{ item?.item_name }} ({{ item?.sku }})</p>
      </div>
      <div class="p-6 space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Batch *</label>
          <select v-model="selectedBatchId" class="w-full px-3 py-2 border rounded-lg" @change="onBatchChange">
            <option value="">Select batch</option>
            <option v-for="b in batches" :key="b.batch_id" :value="b.batch_id">
              {{ b.batch_no || b.batch_id }} - Qty: {{ formatNum(b.current_qty) }}{{ b.expiry_date ? ' | Exp: ' + formatDate(b.expiry_date) : '' }}
            </option>
          </select>
          <p v-if="!batches.length && !loadingBatches" class="text-sm text-amber-600 mt-1">No stock at source warehouse</p>
        </div>
        <div v-if="selectedBatch">
          <label class="block text-sm font-medium text-gray-700 mb-1">Expiry</label>
          <p class="text-sm text-gray-600">{{ formatDate(selectedBatch.expiry_date) }}</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Available in batch</label>
          <p class="text-sm font-mono">{{ formatNum(selectedBatch?.current_qty) }}</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Pick qty *</label>
          <input v-model.number="pickQty" type="number" min="0" :max="maxPickQty" step="0.01" class="w-full px-3 py-2 border rounded-lg" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Damaged qty</label>
          <input v-model.number="damagedQty" type="number" min="0" step="0.01" class="w-full px-3 py-2 border rounded-lg" />
        </div>
      </div>
      <div class="p-6 border-t flex justify-between">
        <button
          v-if="allowRemove"
          @click="removeItem"
          class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50"
        >
          Remove item
        </button>
        <div v-else></div>
        <div class="flex gap-2">
          <button @click="$emit('close')" class="px-4 py-2 border rounded-lg hover:bg-gray-50">Cancel</button>
          <button
            @click="save"
            :disabled="!selectedBatchId || !pickQty || pickQty <= 0 || saving"
            class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
            style="background-color: #284b44;"
          >
            {{ saving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { fetchBatchesFefoAtLocation } from '@/services/transferEngine.js';

const props = defineProps({
  item: { type: Object, default: null },
  transferId: { type: String, default: '' },
  fromLocationId: { type: String, default: '' },
  allowRemove: { type: Boolean, default: false }
});
const emit = defineEmits(['close', 'save', 'remove']);

const batches = ref([]);
const loadingBatches = ref(false);
const selectedBatchId = ref(props.item?.batch_id || '');
const pickQty = ref(Number(props.item?.picked_qty || props.item?.transfer_qty) || 0);
const damagedQty = ref(Number(props.item?.damaged_qty) || 0);
const saving = ref(false);

const selectedBatch = computed(() => batches.value.find((b) => b.batch_id === selectedBatchId.value));

const maxPickQty = computed(() => {
  const b = selectedBatch.value;
  if (!b) return Number(props.item?.transfer_qty) || 999;
  return Math.min(Number(b.current_qty || 0), Number(props.item?.transfer_qty) || 999);
});

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}
function formatDate(d) {
  if (!d) return '—';
  try { return new Date(d).toLocaleDateString('en-GB'); } catch { return d; }
}

async function loadBatches() {
  if (!props.fromLocationId || !props.item?.item_id) return;
  loadingBatches.value = true;
  try {
    batches.value = await fetchBatchesFefoAtLocation(props.fromLocationId, props.item.item_id);
    if (!selectedBatchId.value && batches.value.length) {
      selectedBatchId.value = batches.value[0].batch_id;
    }
  } finally {
    loadingBatches.value = false;
  }
}

function onBatchChange() {
  const b = selectedBatch.value;
  if (b && pickQty.value > Number(b.current_qty || 0)) {
    pickQty.value = Math.min(pickQty.value, Number(b.current_qty));
  }
}

function removeItem() {
  emit('remove');
}

function save() {
  if (!props.transferId || !props.item?.item_id || !selectedBatchId.value || !pickQty.value) return;
  saving.value = true;
  emit('save', {
    batchId: selectedBatchId.value,
    pickedQty: pickQty.value,
    damagedQty: damagedQty.value,
    unitCost: selectedBatch.value?.avg_cost
  });
  emit('close');
  saving.value = false;
}

watch(() => props.item, (v) => {
  if (v) {
    selectedBatchId.value = v.batch_id || '';
    pickQty.value = Number(v.picked_qty || v.transfer_qty) || 0;
    damagedQty.value = Number(v.damaged_qty) || 0;
    loadBatches();
  }
}, { immediate: true });
</script>
