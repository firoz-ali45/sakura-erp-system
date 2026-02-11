<template>
  <div class="report-table-wrapper">
    <div v-if="showToolbar" class="flex flex-wrap gap-2 items-center justify-between mb-4">
      <div class="flex gap-2">
        <input
          v-if="searchable"
          v-model="searchLocal"
          type="text"
          :placeholder="$t('common.search')"
          class="px-3 py-2 border border-gray-300 rounded-lg text-sm w-56 focus:ring-2 focus:ring-[#284b44]"
        />
        <button
          v-if="exportable"
          @click="$emit('export-excel')"
          class="px-3 py-2 rounded-lg text-sm text-white flex items-center gap-1"
          style="background-color: #284b44;"
        >
          <i class="fas fa-file-excel"></i> Excel
        </button>
        <button
          v-if="exportable"
          @click="$emit('export-pdf')"
          class="px-3 py-2 rounded-lg text-sm bg-gray-600 text-white flex items-center gap-1"
        >
          <i class="fas fa-file-pdf"></i> PDF
        </button>
        <button
          @click="$emit('refresh')"
          class="px-3 py-2 rounded-lg text-sm border border-gray-300 hover:bg-gray-50 flex items-center gap-1"
        >
          <i class="fas fa-sync-alt"></i> {{ $t('common.search') }}
        </button>
      </div>
      <span v-if="totalCount !== null" class="text-sm text-gray-600">{{ totalCount }} {{ $t('common.selected') || 'rows' }}</span>
    </div>
    <div class="overflow-x-auto bg-white rounded-xl shadow-md">
      <table class="w-full text-sm">
        <thead class="bg-gray-50 sticky top-0 z-10">
          <tr>
            <th
              v-for="col in columns"
              :key="col.key"
              class="px-4 py-3 text-left text-xs font-semibold text-gray-700 uppercase whitespace-nowrap"
              :class="{ 'text-right': col.align === 'right', 'cursor-pointer': col.sortable }"
              @click="col.sortable && sortBy(col.key)"
            >
              {{ col.label }}
              <i v-if="col.sortable && sortKey === col.key" :class="['fas ml-1', sortAsc ? 'fa-sort-up' : 'fa-sort-down']"></i>
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-if="loading">
            <td :colspan="columns.length" class="px-4 py-12 text-center">
              <i class="fas fa-spinner fa-spin text-2xl text-[#284b44]"></i>
            </td>
          </tr>
          <tr v-else-if="!paginatedRows.length">
            <td :colspan="columns.length" class="px-4 py-12 text-center text-gray-500">{{ $t('common.noData') }}</td>
          </tr>
          <tr
            v-else
            v-for="(row, i) in paginatedRows"
            :key="rowKey ? row[rowKey] : i"
            class="hover:bg-gray-50"
            :class="{ 'cursor-pointer': rowClickable }"
            @click="rowClickable && $emit('row-click', row)"
          >
            <td
              v-for="col in columns"
              :key="col.key"
              class="px-4 py-3"
              :class="{ 'text-right': col.align === 'right', 'font-medium': col.bold }"
            >
              {{ col.format ? col.format(row[col.key]) : (row[col.key] ?? '—') }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    <div v-if="paginate && totalPages > 1" class="flex items-center justify-between mt-4 text-sm">
      <span class="text-gray-600">{{ $t('common.selected') || 'Showing' }} {{ (currentPage - 1) * pageSize + 1 }}-{{ Math.min(currentPage * pageSize, filteredRows.length) }} {{ $t('common.selected') ? '' : 'of' }} {{ filteredRows.length }}</span>
      <div class="flex gap-2">
        <button
          :disabled="currentPage <= 1"
          class="px-3 py-1 rounded border disabled:opacity-50"
          @click="currentPage--"
        >{{ $t('common.previous') }}</button>
        <button
          :disabled="currentPage >= totalPages"
          class="px-3 py-1 rounded border disabled:opacity-50"
          @click="currentPage++"
        >{{ $t('common.next') }}</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  columns: { type: Array, required: true },
  data: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  rowKey: { type: String, default: 'id' },
  searchable: { type: Boolean, default: true },
  exportable: { type: Boolean, default: true },
  showToolbar: { type: Boolean, default: true },
  paginate: { type: Boolean, default: true },
  pageSize: { type: Number, default: 50 },
  searchKeys: { type: Array, default: () => [] },
  rowClickable: { type: Boolean, default: false }
});

const emit = defineEmits(['export-excel', 'export-pdf', 'refresh', 'row-click']);

const searchLocal = ref('');
const sortKey = ref(null);
const sortAsc = ref(true);
const currentPage = ref(1);

const filteredRows = computed(() => {
  let list = props.data || [];
  const q = (searchLocal.value || '').trim().toLowerCase();
  if (q && props.searchKeys.length) {
    list = list.filter(r =>
      props.searchKeys.some(k => String(r[k] || '').toLowerCase().includes(q))
    );
  } else if (q && props.columns.length) {
    list = list.filter(r =>
      props.columns.some(c => String(r[c.key] || '').toLowerCase().includes(q))
    );
  }
  if (sortKey.value) {
    list = [...list].sort((a, b) => {
      const av = a[sortKey.value];
      const bv = b[sortKey.value];
      const cmp = (av == null && bv == null) ? 0 : (av == null ? 1 : (bv == null ? -1 : String(av).localeCompare(String(bv), undefined, { numeric: true })));
      return sortAsc.value ? cmp : -cmp;
    });
  }
  return list;
});

const totalPages = computed(() => Math.ceil(filteredRows.value.length / props.pageSize) || 1);
const paginatedRows = computed(() => {
  if (!props.paginate) return filteredRows.value;
  const start = (currentPage.value - 1) * props.pageSize;
  return filteredRows.value.slice(start, start + props.pageSize);
});
const totalCount = computed(() => filteredRows.value.length);

function sortBy(key) {
  if (sortKey.value === key) sortAsc.value = !sortAsc.value;
  else { sortKey.value = key; sortAsc.value = true; }
  currentPage.value = 1;
}

watch(() => props.data, () => { currentPage.value = 1; });
</script>
