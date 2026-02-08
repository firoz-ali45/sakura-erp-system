<!--
  BASE TABLE COMPONENT
  ====================
  
  Enterprise-grade table component with i18n and RTL support.
  
  FEATURES:
  - Automatic RTL/LTR alignment
  - i18n header support
  - Consistent styling
  - Responsive design
  
  USAGE:
  <BaseTable
    :headers="[
      { key: 'name', label: $t('inventory.items.name') },
      { key: 'sku', label: $t('inventory.items.sku') }
    ]"
    :data="items"
  />
-->

<template>
  <div class="base-table-wrapper">
    <table :class="['base-table', { 'base-table--rtl': isRTL }]">
      <thead>
        <tr>
          <th
            v-for="header in headers"
            :key="header.key"
            :class="[
              'base-table__header',
              header.align ? `base-table__header--${header.align}` : textAlignClass
            ]"
          >
            {{ header.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading">
          <td :colspan="headers.length" class="base-table__loading">
            <div class="base-table__loading-content">
              <div class="base-table__spinner"></div>
              <span>{{ $t('common.loading') }}</span>
            </div>
          </td>
        </tr>
        <tr v-else-if="!data || data.length === 0">
          <td :colspan="headers.length" class="base-table__empty">
            {{ $t('common.noData') }}
          </td>
        </tr>
        <tr v-else v-for="(row, index) in data" :key="getRowKey(row, index)">
          <td
            v-for="header in headers"
            :key="header.key"
            :class="[
              'base-table__cell',
              header.align ? `base-table__cell--${header.align}` : textAlignClass
            ]"
          >
            <slot :name="`cell-${header.key}`" :row="row" :value="row[header.key]">
              {{ row[header.key] }}
            </slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from '@/composables/useI18n';

const props = defineProps({
  headers: {
    type: Array,
    required: true,
    validator: (headers) => {
      return headers.every(h => h.key && h.label);
    }
  },
  data: {
    type: Array,
    default: () => []
  },
  loading: {
    type: Boolean,
    default: false
  },
  rowKey: {
    type: [String, Function],
    default: 'id'
  }
});

const { isRTL, textAlign } = useI18n();

const textAlignClass = computed(() => textAlign.value);

function getRowKey(row, index) {
  if (typeof props.rowKey === 'function') {
    return props.rowKey(row, index);
  }
  return row[props.rowKey] || index;
}
</script>

<style scoped>
.base-table-wrapper {
  @apply overflow-x-auto bg-white rounded-lg shadow-md;
}

.base-table {
  @apply w-full border-collapse;
}

.base-table__header {
  @apply px-6 py-3 text-xs font-medium text-gray-500 uppercase tracking-wider;
  @apply bg-gray-50 border-b border-gray-200;
}

.base-table__header--left {
  @apply text-left;
}

.base-table__header--right {
  @apply text-right;
}

.base-table__header--center {
  @apply text-center;
}

.base-table__cell {
  @apply px-6 py-4 text-sm text-gray-700 border-b border-gray-200;
}

.base-table__cell--left {
  @apply text-left;
}

.base-table__cell--right {
  @apply text-right;
}

.base-table__cell--center {
  @apply text-center;
}

.base-table__loading,
.base-table__empty {
  @apply px-6 py-12 text-center;
}

.base-table__loading-content {
  @apply flex flex-col items-center justify-center gap-4;
}

.base-table__spinner {
  @apply w-8 h-8 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin;
}

/* RTL Support */
.base-table--rtl {
  direction: rtl;
}
</style>

