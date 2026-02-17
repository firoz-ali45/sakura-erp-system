<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <button @click="$router.push('/homeportal/user-management/roles')" class="text-[#284b44] hover:underline mb-4 flex items-center gap-2">
      <i class="fas fa-arrow-left"></i> {{ $t('userManagement.roles') }}
    </button>
    <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.roles') }} → {{ role?.name || '...' }}</h2>
    <p class="text-gray-600 mt-2">Permission matrix & location access (Phase 3)</p>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { getRoles } from '@/services/userManagementService';

const route = useRoute();
const role = ref(null);

onMounted(async () => {
  const id = route.params.id;
  if (id && id !== 'new') {
    const roles = await getRoles({});
    role.value = roles.find(r => r.id === id);
  }
});
</script>
