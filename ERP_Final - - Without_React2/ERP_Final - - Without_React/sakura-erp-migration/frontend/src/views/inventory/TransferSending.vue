<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="bg-white rounded-xl shadow-md p-6">
      <button @click="goBack" class="text-[#284b44] hover:text-[#1e3a36] flex items-center gap-2 font-medium mb-4">
        <i class="fas fa-arrow-left"></i>
        Back
      </button>
      <h1 class="text-2xl font-bold text-gray-800 mb-4">Transfer Sending</h1>
      <p class="text-gray-600">Transfer Sending module — routing placeholder. Full implementation in next phase.</p>
      <p class="text-sm text-gray-500 mt-2">Transfer ID: {{ transferId || '—' }}</p>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';

const route = useRoute();
const router = useRouter();
const transferId = computed(() => route.params.id);

function goBack() {
  router.push('/homeportal/transfer-orders');
}
</script>
