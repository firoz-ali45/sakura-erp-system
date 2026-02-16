<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-w-lg m-4">
      <div class="sticky top-0 bg-white border-b p-6 flex justify-between items-center z-10">
        <h2 class="text-xl font-bold">Edit Item</h2>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-700"><i class="fas fa-times"></i></button>
      </div>
      <div class="p-6 space-y-4">
        <div v-if="item">
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ item.item_name }} ({{ item.sku }}) ({{ item.storage_unit || 'Pcs' }})*</label>
          <input v-model.number="qty" type="number" min="0" step="0.01" class="w-full px-4 py-2 border rounded-lg" />
          <p class="text-xs text-gray-500 mt-1">Available: {{ formatNum(item.available_qty) }}</p>
        </div>
      </div>
      <div class="p-6 border-t flex justify-between">
        <button
          @click="deleteItem"
          v-if="item"
          class="px-4 py-2 border border-red-300 rounded-lg text-red-600 hover:bg-red-50"
        >
          <i class="fas fa-trash mr-1"></i> Delete Item
        </button>
        <div class="flex gap-3 ml-auto">
          <button @click="$emit('close')" class="px-6 py-2 border rounded-lg hover:bg-gray-50">Close</button>
          <button
            @click="save"
            :disabled="qty < 0 || saving"
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
import { ref, watch } from 'vue';

const props = defineProps({
  modelValue: { type: Boolean, default: false },
  item: { type: Object, default: null }
});
const emit = defineEmits(['close', 'save', 'delete']);

const qty = ref(0);
const saving = ref(false);

function formatNum(n) {
  const v = Number(n);
  return isNaN(v) ? '—' : v.toLocaleString('en', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

function save() {
  if (qty.value < 0) return;
  saving.value = true;
  emit('save', qty.value);
  emit('close');
  saving.value = false;
}

function deleteItem() {
  emit('delete');
  emit('close');
}

watch(() => props.item, (item) => {
  qty.value = item ? (Number(item.requested_qty) || 0) : 0;
}, { immediate: true });
</script>
