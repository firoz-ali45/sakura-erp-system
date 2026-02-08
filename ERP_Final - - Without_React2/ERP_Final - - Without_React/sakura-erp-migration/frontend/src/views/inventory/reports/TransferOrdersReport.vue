<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6 mb-6"><h1 class="text-2xl font-bold text-gray-800">{{ $t('inventory.reports.transferOrders') }}</h1></div>
    <div class="bg-white rounded-xl shadow-md overflow-hidden">
      <p class="p-4 text-gray-600">{{ $t('inventory.reports.transferOrdersPlaceholder') }}</p>
    </div>
  </div>
</template>

<script setup>
import { useI18n } from 'vue-i18n';
useI18n();
</script>
