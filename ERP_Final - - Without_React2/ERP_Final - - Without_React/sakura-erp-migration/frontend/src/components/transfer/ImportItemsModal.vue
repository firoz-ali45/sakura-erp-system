<template>
  <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto m-4">
      <div class="sticky top-0 bg-white border-b p-6 flex justify-between items-center z-10">
        <h2 class="text-xl font-bold">Import Items</h2>
        <button @click="$emit('close')" class="text-gray-500 hover:text-gray-700"><i class="fas fa-times"></i></button>
      </div>
      <div class="p-6 space-y-4">
        <p class="text-sm text-gray-600">Template columns: <strong>SKU</strong>, <strong>Quantity</strong></p>
        <a href="#" @click.prevent="downloadTemplate" class="text-[#284b44] hover:underline text-sm block">Download Template</a>
        <input
          ref="fileInput"
          type="file"
          accept=".xlsx,.xls,.csv"
          class="hidden"
          @change="onFile"
        />
        <button
          @click="fileInput?.click()"
          class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
        >
          <i class="fas fa-upload"></i>
          Choose File
        </button>
        <span v-if="!fileName" class="text-sm text-gray-500 ml-2">No file chosen</span>
        <span v-else class="text-sm text-gray-700 ml-2">{{ fileName }}</span>
        <div v-if="preview.length > 0" class="border rounded-lg overflow-hidden">
          <p class="p-2 bg-gray-50 text-sm font-medium">Preview</p>
          <table class="w-full text-sm">
            <thead class="bg-gray-100">
              <tr>
                <th class="px-3 py-2 text-left">SKU</th>
                <th class="px-3 py-2 text-right">Quantity</th>
                <th class="px-3 py-2 text-left">Status</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(r, i) in preview" :key="i" class="border-t">
                <td class="px-3 py-2">{{ r.sku }}</td>
                <td class="px-3 py-2 text-right">{{ r.quantity }}</td>
                <td class="px-3 py-2" :class="r.error ? 'text-red-600' : 'text-green-600'">{{ r.error || 'OK' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="errors.length > 0" class="text-red-600 text-sm">
          <p v-for="(e, i) in errors" :key="i">{{ e }}</p>
        </div>
      </div>
      <div class="p-6 border-t flex justify-end gap-3">
        <button @click="$emit('close')" class="px-6 py-2 border rounded-lg hover:bg-gray-50">Close</button>
        <button
          @click="confirm"
          :disabled="preview.length === 0 || !preview.some((r) => !r.error)"
          class="px-6 py-2 rounded-lg text-white disabled:opacity-50"
          style="background-color: #284b44;"
        >
          Confirm
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import * as XLSX from 'xlsx';

const emit = defineEmits(['close', 'import']);

const fileInput = ref(null);
const fileName = ref('');
const preview = ref([]);
const errors = ref([]);
const pendingRows = ref([]);

function downloadTemplate() {
  const ws = XLSX.utils.aoa_to_sheet([['SKU', 'Quantity'], ['sk-12345', '10']]);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Items');
  XLSX.writeFile(wb, 'transfer_order_items_template.xlsx');
}

async function onFile(ev) {
  const f = ev.target?.files?.[0];
  if (!f) return;
  fileName.value = f.name;
  const reader = new FileReader();
  reader.onload = async (e) => {
    const data = e.target?.result;
    const wb = XLSX.read(data, { type: 'binary' });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const rows = XLSX.utils.sheet_to_json(ws, { header: 1 });
    const headers = (rows[0] || []).map((h) => String(h || '').toLowerCase());
    const skuCol = headers.findIndex((h) => h === 'sku');
    const qtyCol = headers.findIndex((h) => ['quantity', 'qty', 'qty.'].includes(h));
    if (skuCol < 0 || qtyCol < 0) {
      emit('close');
      return;
    }
    const parsed = rows
      .slice(1)
      .map((row, i) => {
        const sku = String(row[skuCol] || '').trim();
        const qty = parseFloat(row[qtyCol] || 0);
        return { sku, quantity: qty, rowIndex: i + 2 };
      })
      .filter((r) => r.sku || r.quantity);
    pendingRows.value = parsed;
    await validatePreview();
  };
  reader.readAsBinaryString(f);
  ev.target.value = '';
}

async function validatePreview() {
  const { supabaseClient } = await import('@/services/supabase.js');
  const { data: allItems } = await supabaseClient
    .from('inventory_items')
    .select('id, sku')
    .or('deleted.eq.false,deleted.is.null');
  const skuMap = (allItems || []).reduce((acc, it) => {
    acc[(it.sku || '').toLowerCase()] = it;
    return acc;
  }, {});
  preview.value = pendingRows.value.map((r) => {
    const item = skuMap[r.sku?.toLowerCase()];
    const err = !r.sku ? 'SKU required' : !item ? `SKU "${r.sku}" not found` : r.quantity <= 0 ? 'Invalid quantity' : null;
    return { sku: r.sku, quantity: r.quantity, error: err };
  });
  errors.value = [];
}

function confirm() {
  const valid = pendingRows.value.filter((_, i) => !preview.value[i]?.error);
  if (valid.length === 0) return;
  emit('import', valid);
  emit('close');
}
</script>
