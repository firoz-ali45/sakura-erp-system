<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <button @click="$router.push('/homeportal/user-management/users')" class="text-[#284b44] hover:underline mb-4 flex items-center gap-2">
        <i class="fas fa-arrow-left"></i> {{ $t('common.back') }}
      </button>
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.users') }} → {{ user?.name || '...' }}</h2>
    </div>
    <div v-if="loading" class="text-center py-12">Loading...</div>
    <div v-else-if="user" class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-bold text-lg mb-4">Basic Info</h3>
        <p><strong>Name:</strong> {{ user.name }}</p>
        <p><strong>Email:</strong> {{ user.email }}</p>
        <p><strong>Phone:</strong> {{ user.phone || '-' }}</p>
        <p><strong>Employee ID:</strong> {{ user.employee_id || '-' }}</p>
        <p><strong>Department:</strong> {{ user.department || '-' }}</p>
      </div>
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-bold text-lg mb-4">Role & Status</h3>
        <p><strong>Primary role:</strong> {{ user.role }}</p>
        <p><strong>Status:</strong> {{ user.status }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import { getUsers } from '@/services/supabase';

const route = useRoute();
const user = ref(null);
const loading = ref(true);

onMounted(async () => {
  if (route.params.id === 'new') {
    loading.value = false;
    return;
  }
  const users = await getUsers();
  user.value = users?.find(u => u.id === route.params.id) || null;
  loading.value = false;
});
</script>
