<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.roles') }}</h2>
      <button @click="openCreateRole" class="px-4 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38]">
        <i class="fas fa-plus mr-2"></i>{{ $t('userManagement.createRole') }}
      </button>
    </div>
    <div class="flex gap-2 mb-4">
      <button v-for="t in ['Active','Inactive','Deleted']" :key="t" @click="tab=t" :class="['px-4 py-2 rounded', tab===t?'bg-[#284b44] text-white':'bg-gray-200']">{{ t }}</button>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <div 
        v-for="role in filteredRoles" 
        :key="role.id" 
        class="bg-white rounded-lg shadow p-6 cursor-pointer hover:shadow-lg transition-shadow"
        @click="$router.push(`/homeportal/user-management/role/${role.id}`)"
      >
        <h3 class="font-bold text-lg text-[#284b44]">{{ role.name }}</h3>
        <p class="text-sm text-gray-600 mt-1">{{ role.description || '-' }}</p>
        <span class="text-xs text-gray-500">{{ role.code }}</span>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getRoles } from '@/services/userManagementService';

const roles = ref([]);
const tab = ref('Active');

const filteredRoles = computed(() => {
  const t = tab.value.toLowerCase();
  if (t === 'active') return roles.value.filter(r => r.is_active !== false);
  if (t === 'inactive') return roles.value.filter(r => r.is_active === false);
  return roles.value;
});

function openCreateRole() {
  // TODO: modal
}

onMounted(async () => {
  roles.value = await getRoles();
});
</script>
