<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-800">{{ t('homePortal.financeMore') }}</h1>
      <p class="text-gray-600 mt-1">Finance configuration. Manage ATM & Bank masters used by Purchasing and Payments.</p>
    </div>

    <!-- Single configuration card: Payment Configuration -->
    <div class="max-w-2xl">
      <div
        class="bg-white rounded-xl shadow-md overflow-hidden border-2 border-transparent hover:border-[#284b44] hover:shadow-lg transition-all cursor-pointer group"
        @click="goToPaymentConfiguration"
      >
        <div class="p-8 flex items-start gap-6">
          <div class="w-16 h-16 rounded-xl bg-gradient-to-br from-[#284b44] to-[#1e3a35] flex items-center justify-center text-white text-3xl group-hover:scale-105 transition-transform">
            <i class="fas fa-credit-card"></i>
          </div>
          <div class="flex-1">
            <h2 class="text-xl font-bold text-gray-800 group-hover:text-[#284b44] transition-colors">
              💳 {{ t('homePortal.paymentConfiguration') }}
            </h2>
            <p class="text-gray-600 mt-2">
              Manage ATM & Bank accounts. Used across Purchasing & Payments.
            </p>
            <p class="text-sm text-gray-500 mt-3 flex items-center gap-2">
              <i class="fas fa-arrow-right text-[#284b44]"></i>
              Click to open ATM Master and Bank Master
            </p>
          </div>
          <i class="fas fa-chevron-right text-gray-400 group-hover:text-[#284b44] group-hover:translate-x-1 transition-all text-xl"></i>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const router = useRouter();

const goToPaymentConfiguration = () => {
  router.push('/homeportal/finance-more/payment-configuration');
};
</script>
