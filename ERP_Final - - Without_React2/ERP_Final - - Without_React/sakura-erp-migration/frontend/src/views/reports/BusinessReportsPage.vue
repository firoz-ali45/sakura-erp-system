<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <h1 class="text-2xl font-bold text-gray-800 mb-6">{{ $t('homePortal.businessReports') }}</h1>
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <router-link
        v-for="card in cards"
        :key="card.route"
        :to="'/homeportal/' + card.route"
        class="report-card bg-white rounded-xl shadow-md p-6 flex items-center justify-between hover:shadow-lg transition-shadow cursor-pointer border border-gray-100"
      >
        <div class="flex items-center gap-4">
          <div class="w-12 h-12 rounded-lg flex items-center justify-center" style="background-color: #284b44;">
            <i :class="['fas', card.icon, 'text-white text-xl']"></i>
          </div>
          <span class="font-semibold text-gray-800">{{ $t(card.i18nKey) }}</span>
        </div>
        <i class="fas fa-chevron-right text-gray-400"></i>
      </router-link>
    </div>
  </div>
</template>

<script setup>
import { useI18n } from 'vue-i18n';
useI18n();

const cards = [
  { route: 'reports-accounts-payable', icon: 'fa-file-invoice-dollar', i18nKey: 'homePortal.reportsAccountsPayable' },
  { route: 'rm-forecasting', icon: 'fa-chart-line', i18nKey: 'homePortal.rmForecasting' },
  { route: 'warehouse-dashboard', icon: 'fa-warehouse', i18nKey: 'homePortal.warehouseDashboard' },
  { route: 'food-quality-traceability', icon: 'fa-shield-alt', i18nKey: 'homePortal.foodQualityTraceability' }
];
</script>
