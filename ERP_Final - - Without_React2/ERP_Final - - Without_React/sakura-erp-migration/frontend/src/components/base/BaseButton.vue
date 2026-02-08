<!--
  BASE BUTTON COMPONENT
  =====================
  
  Enterprise-grade button component with i18n support.
  
  FEATURES:
  - Automatic RTL/LTR alignment
  - i18n text support (no hardcoded strings)
  - Consistent styling
  - Accessible (ARIA support)
  
  USAGE:
  <BaseButton 
    :label="$t('common.save')" 
    @click="handleSave"
    variant="primary"
  />
  
  PROPS:
  - label: Translation key (required)
  - variant: 'primary' | 'secondary' | 'danger' | 'success' | 'warning'
  - size: 'sm' | 'md' | 'lg'
  - disabled: Boolean
  - loading: Boolean
  - icon: FontAwesome icon class (optional)
  - iconPosition: 'left' | 'right'
-->

<template>
  <button
    :class="[
      'base-button',
      `base-button--${variant}`,
      `base-button--${size}`,
      { 'base-button--disabled': disabled || loading },
      { 'base-button--loading': loading },
      textAlignClass
    ]"
    :disabled="disabled || loading"
    :aria-label="ariaLabel || label"
    @click="$emit('click', $event)"
  >
    <i v-if="icon && iconPosition === 'left' && !loading" :class="icon" class="base-button__icon"></i>
    <span v-if="loading" class="base-button__spinner"></span>
    <span v-if="!loading" class="base-button__text">{{ label }}</span>
    <i v-if="icon && iconPosition === 'right' && !loading" :class="icon" class="base-button__icon"></i>
  </button>
</template>

<script setup>
import { computed } from 'vue';
import { useI18n } from '@/composables/useI18n';

const props = defineProps({
  label: {
    type: String,
    required: true,
    validator: (value) => {
      // Label should be a translation key, not hardcoded text
      if (typeof value === 'string' && value.length > 0) {
        return true;
      }
      console.warn('BaseButton: label should be a translation key');
      return true; // Don't block, just warn
    }
  },
  variant: {
    type: String,
    default: 'primary',
    validator: (value) => ['primary', 'secondary', 'danger', 'success', 'warning'].includes(value)
  },
  size: {
    type: String,
    default: 'md',
    validator: (value) => ['sm', 'md', 'lg'].includes(value)
  },
  disabled: {
    type: Boolean,
    default: false
  },
  loading: {
    type: Boolean,
    default: false
  },
  icon: {
    type: String,
    default: null
  },
  iconPosition: {
    type: String,
    default: 'left',
    validator: (value) => ['left', 'right'].includes(value)
  },
  ariaLabel: {
    type: String,
    default: null
  }
});

defineEmits(['click']);

const { isRTL, textAlign } = useI18n();

const textAlignClass = computed(() => textAlign.value);
</script>

<style scoped>
.base-button {
  @apply px-4 py-2 rounded-lg font-semibold transition-all duration-200;
  @apply flex items-center justify-center gap-2;
  @apply focus:outline-none focus:ring-2 focus:ring-offset-2;
}

.base-button--primary {
  @apply bg-[#284b44] text-white;
  @apply hover:bg-[#1f3a35] active:bg-[#1a2f2a];
  @apply focus:ring-[#284b44];
}

.base-button--secondary {
  @apply bg-white border border-gray-300 text-gray-700;
  @apply hover:bg-gray-50 active:bg-gray-100;
  @apply focus:ring-gray-300;
}

.base-button--danger {
  @apply bg-red-600 text-white;
  @apply hover:bg-red-700 active:bg-red-800;
  @apply focus:ring-red-600;
}

.base-button--success {
  @apply bg-green-600 text-white;
  @apply hover:bg-green-700 active:bg-green-800;
  @apply focus:ring-green-600;
}

.base-button--warning {
  @apply bg-yellow-600 text-white;
  @apply hover:bg-yellow-700 active:bg-yellow-800;
  @apply focus:ring-yellow-600;
}

.base-button--sm {
  @apply px-3 py-1.5 text-sm;
}

.base-button--md {
  @apply px-4 py-2 text-base;
}

.base-button--lg {
  @apply px-6 py-3 text-lg;
}

.base-button--disabled {
  @apply opacity-50 cursor-not-allowed;
}

.base-button--loading {
  @apply cursor-wait;
}

.base-button__spinner {
  @apply inline-block w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin;
}

.base-button__icon {
  @apply text-inherit;
}

/* RTL Support */
.rtl .base-button {
  @apply flex-row-reverse;
}
</style>

