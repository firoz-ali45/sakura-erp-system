<template>
  <div class="min-h-screen bg-[#f0e1cd] p-4 md:p-6">
    <div class="mb-6">
      <h2 class="text-2xl font-bold text-gray-800">{{ $t('userManagement.sectionTitle') }} → {{ $t('userManagement.securitySettings') }}</h2>
      <p class="text-gray-600 mt-1">Password policy, session timeout, 2FA</p>
    </div>

    <div v-if="loading" class="text-center py-12">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto"></div>
      <p class="text-gray-600 mt-2">Loading...</p>
    </div>

    <div v-else class="max-w-2xl space-y-6">
      <!-- Password Policy -->
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-bold text-lg mb-4">Password Policy</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Minimum length</label>
            <input v-model.number="form.passwordPolicy.min_length" type="number" min="6" max="32" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div class="space-y-2">
            <label class="flex items-center gap-2 cursor-pointer">
              <input v-model="form.passwordPolicy.require_number" type="checkbox" class="rounded" />
              <span>Require number</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input v-model="form.passwordPolicy.require_special" type="checkbox" class="rounded" />
              <span>Require special character</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input v-model="form.passwordPolicy.require_lowercase" type="checkbox" class="rounded" />
              <span>Require lowercase</span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input v-model="form.passwordPolicy.require_uppercase" type="checkbox" class="rounded" />
              <span>Require uppercase</span>
            </label>
          </div>
        </div>
        <button @click="savePasswordPolicy" class="mt-4 px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="saving">
          {{ saving ? 'Saving...' : 'Save' }}
        </button>
        <span v-if="savedPolicy" class="ml-2 text-green-600 text-sm">Saved</span>
      </div>

      <!-- Session Timeout -->
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-bold text-lg mb-4">Session Timeout</h3>
        <div class="flex items-center gap-4">
          <div class="flex-1">
            <label class="block text-sm font-medium text-gray-700 mb-1">Timeout (minutes)</label>
            <input v-model.number="form.sessionTimeoutMinutes" type="number" min="5" max="1440" class="w-full px-3 py-2 border rounded-lg" />
          </div>
          <div class="flex items-end">
            <button @click="saveSessionTimeout" class="px-4 py-2 bg-[#284b44] text-white rounded-lg" :disabled="saving">
              {{ saving ? 'Saving...' : 'Save' }}
            </button>
            <span v-if="savedTimeout" class="ml-2 text-green-600 text-sm">Saved</span>
          </div>
        </div>
      </div>

      <!-- 2FA / MFA -->
      <div class="bg-white rounded-lg shadow p-6">
        <h3 class="font-bold text-lg mb-4">Two-Factor Authentication</h3>
        <div class="space-y-4">
          <label class="flex items-center justify-between cursor-pointer">
            <span>2FA enabled (global)</span>
            <input v-model="form.twoFaEnabled" type="checkbox" class="rounded" @change="saveTwoFa" />
          </label>
          <label class="flex items-center justify-between cursor-pointer">
            <span>MFA required for all users</span>
            <input v-model="form.mfaRequired" type="checkbox" class="rounded" @change="saveMfaRequired" />
          </label>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue';
import { getSecuritySettings, updateSecuritySetting } from '@/services/userManagementService';

const loading = ref(true);
const saving = ref(false);
const savedPolicy = ref(false);
const savedTimeout = ref(false);

const form = reactive({
  passwordPolicy: {
    min_length: 8,
    require_number: true,
    require_special: false,
    require_lowercase: true,
    require_uppercase: true
  },
  sessionTimeoutMinutes: 30,
  twoFaEnabled: false,
  mfaRequired: false
});

function applySettings(settings) {
  const policy = settings.password_policy;
  if (policy && typeof policy === 'object') {
    form.passwordPolicy.min_length = policy.min_length ?? 8;
    form.passwordPolicy.require_number = policy.require_number ?? true;
    form.passwordPolicy.require_special = policy.require_special ?? false;
    form.passwordPolicy.require_lowercase = policy.require_lowercase ?? true;
    form.passwordPolicy.require_uppercase = policy.require_uppercase ?? true;
  }
  const timeout = settings.session_timeout_minutes;
  form.sessionTimeoutMinutes = (typeof timeout === 'number' ? timeout : parseInt(timeout, 10)) || 30;
  form.twoFaEnabled = !!settings.two_fa_enabled;
  form.mfaRequired = !!settings.mfa_required;
}

async function savePasswordPolicy() {
  saving.value = true;
  savedPolicy.value = false;
  try {
    await updateSecuritySetting('password_policy', form.passwordPolicy);
    savedPolicy.value = true;
    setTimeout(() => { savedPolicy.value = false; }, 2000);
  } catch (e) {
    console.error(e);
  } finally {
    saving.value = false;
  }
}

async function saveSessionTimeout() {
  saving.value = true;
  savedTimeout.value = false;
  try {
    await updateSecuritySetting('session_timeout_minutes', form.sessionTimeoutMinutes);
    savedTimeout.value = true;
    setTimeout(() => { savedTimeout.value = false; }, 2000);
  } catch (e) {
    console.error(e);
  } finally {
    saving.value = false;
  }
}

async function saveTwoFa() {
  try {
    await updateSecuritySetting('two_fa_enabled', form.twoFaEnabled);
  } catch (e) {
    console.error(e);
  }
}

async function saveMfaRequired() {
  try {
    await updateSecuritySetting('mfa_required', form.mfaRequired);
  } catch (e) {
    console.error(e);
  }
}

onMounted(async () => {
  try {
    const settings = await getSecuritySettings();
    applySettings(settings);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.loading-spinner { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
</style>
