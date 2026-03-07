<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-w-2xl m-4 max-h-[90vh] flex flex-col">
      <div class="p-6 border-b flex-shrink-0">
        <h3 class="text-lg font-bold">Select Batch (FEFO) — Multiple batches allowed</h3>
        <p class="text-sm text-gray-600 mt-1">{{ item?.item_name }} ({{ item?.sku }})</p>
        <p class="text-sm text-gray-500 mt-1">Total to pick: <strong>{{ formatNum(requiredTotal) }}</strong> — Allocated: <strong :class="totalAllocated === requiredTotal ? 'text-green-600' : 'text-amber-600'">{{ formatNum(totalAllocated) }}</strong></p>
      </div>
      <div class="p-6 space-y-4 overflow-y-auto flex-1">
        <div v-for="(row, index) in allocationRows" :key="index" class="flex flex-wrap items-end gap-3 p-3 bg-gray-50 rounded-lg">
          <div class="flex-1 min-w-[180px]">
            <label class="block text-xs font-medium text-gray-600 mb-1">Batch</label>
            <select v-model="row.batchId" class="w-full px-3 py-2 border rounded-lg text-sm" @change="onRowBatchChange(row)">
              <option value="">Select batch</option>
              <option v-for="b in batchesForRow(row)" :key="b.batch_id" :value="b.batch_id">
                {{ b.batch_no || b.batch_id }} — Avail: {{ formatNum(b.current_qty) }}{{ b.expiry_date ? ' | Exp: ' + formatDate(b.expiry_date) : '' }}
              </option>
            </select>
          </div>
          <div class="w-24">
            <label class="block text-xs font-medium text-gray-600 mb-1">Qty</label>
            <input v-model.number="row.qty" type="number" min="0" :max="maxQtyForRow(row)" step="0.01" class="w-full px-3 py-2 border rounded-lg text-sm" />
          </div>
          <div class="w-20">
            <label class="block text-xs font-medium text-gray-600 mb-1">Damaged</label>
            <input v-model.number="row.damagedQty" type="number" min="0" step="0.01" class="w-full px-3 py-2 border rounded-lg text-sm" />
          </div>
          <button type="button" @click="removeRow(index)" class="p-2 text-red-600 hover:bg-red-50 rounded" title="Remove batch row">
            <i class="fas fa-times"></i>
          </button>
        </div>
        <button type="button" @click="addRow" class="w-full py-2 border-2 border-dashed border-gray-300 rounded-lg text-gray-600 hover:border-[#284b44] hover:text-[#284b44] text-sm font-medium">
          <i class="fas fa-plus mr-1"></i> Add another batch
        </button>
        <p v-if="!batches.length && !loadingBatches" class="text-sm text-amber-600">No stock at source warehouse</p>
      </div>
      <div class="p-6 border-t flex justify-between flex-shrink-0">
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
            :disabled="!canSave || saving"
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
  /** Current rows for this item (when already picked with multiple batches) */
  existingRows: { type: Array, default: () => [] },
  transferId: { type: String, default: '' },
  fromLocationId: { type: String, default: '' },
  allowRemove: { type: Boolean, default: false }
});
const emit = defineEmits(['close', 'save', 'remove']);

const batches = ref([]);
const loadingBatches = ref(false);
const allocationRows = ref([{ batchId: '', qty: 0, damagedQty: 0 }]);
const saving = ref(false);

const requiredTotal = computed(() => Number(props.item?.transfer_qty) || 0);

const totalAllocated = computed(() =>
  allocationRows.value.reduce((s, r) => s + (Number(r.qty) || 0), 0)
);

function batchesForRow(row) {
  const used = new Set(allocationRows.value.filter((r) => r !== row && r.batchId).map((r) => r.batchId));
  return batches.value.filter((b) => !used.has(b.batch_id));
}

function maxQtyForRow(row) {
  const b = batches.value.find((x) => x.batch_id === row.batchId);
  if (!b) return requiredTotal.value;
  return Math.min(Number(b.current_qty || 0), requiredTotal.value);
}

const canSave = computed(() => {
  if (requiredTotal.value <= 0) return false;
  if (totalAllocated.value !== requiredTotal.value) return false;
  const hasInvalid = allocationRows.value.some((r) => !r.batchId || (Number(r.qty) || 0) <= 0);
  return !hasInvalid;
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
  } finally {
    loadingBatches.value = false;
  }
}

function addRow() {
  allocationRows.value.push({ batchId: '', qty: 0, damagedQty: 0 });
}

function removeRow(index) {
  allocationRows.value.splice(index, 1);
  if (allocationRows.value.length === 0) allocationRows.value.push({ batchId: '', qty: 0, damagedQty: 0 });
}

function onRowBatchChange(row) {
  const b = batches.value.find((x) => x.batch_id === row.batchId);
  if (b && (Number(row.qty) || 0) > Number(b.current_qty || 0)) {
    row.qty = Math.min(Number(b.current_qty || 0), requiredTotal.value);
  }
}

function removeItem() {
  emit('remove');
}

function save() {
  if (!props.transferId || !props.item?.item_id || !canSave.value) return;
  saving.value = true;
  const allocations = allocationRows.value
    .filter((r) => r.batchId && (Number(r.qty) || 0) > 0)
    .map((r) => {
      const b = batches.value.find((x) => x.batch_id === r.batchId);
      return {
        batchId: r.batchId,
        pickedQty: Number(r.qty) || 0,
        damagedQty: Number(r.damagedQty) || 0,
        unitCost: b?.avg_cost
      };
    });
  emit('save', { allocations });
  emit('close');
  saving.value = false;
}

watch(() => [props.item, props.existingRows], () => {
  if (props.item) {
    const total = Number(props.item.transfer_qty) || 0;
    if (props.existingRows?.length) {
      allocationRows.value = props.existingRows.map((r) => ({
        batchId: r.batch_id || '',
        qty: Number(r.picked_qty || r.transfer_qty) || 0,
        damagedQty: Number(r.damaged_qty) || 0
      }));
    } else {
      allocationRows.value = [{ batchId: '', qty: total, damagedQty: 0 }];
      if (allocationRows.value[0].qty > 0) {
        loadBatches().then(() => {
          if (batches.value.length && !allocationRows.value[0].batchId) {
            allocationRows.value[0].batchId = batches.value[0].batch_id;
            const maxQ = Math.min(Number(batches.value[0].current_qty || 0), total);
            if (allocationRows.value[0].qty > maxQ) allocationRows.value[0].qty = maxQ;
          }
        });
      }
    }
    loadBatches();
  }
}, { immediate: true });
</script>
