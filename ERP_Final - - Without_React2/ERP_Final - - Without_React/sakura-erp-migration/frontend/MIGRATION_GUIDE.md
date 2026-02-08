# 🚀 Enterprise i18n Migration Guide

## Overview

This guide will help you migrate from the old translation system to the new **enterprise-grade vue-i18n** system.

## ✅ Migration Checklist

### Phase 1: Setup (COMPLETED)
- [x] Install vue-i18n
- [x] Create locale JSON files (en.json, ar.json)
- [x] Set up global i18n instance
- [x] Create RTL/LTR handler
- [x] Create base components

### Phase 2: Component Migration (IN PROGRESS)

#### Priority 1: Core Components
- [ ] HomePortal.vue
- [ ] Items.vue
- [ ] PurchaseOrders.vue
- [ ] GRNs.vue
- [ ] Suppliers.vue
- [ ] TransferOrders.vue

#### Priority 2: Detail Pages
- [ ] PurchaseOrderDetail.vue
- [ ] GRNDetail.vue
- [ ] TransferOrderDetail.vue

#### Priority 3: Other Components
- [ ] All remaining components

### Phase 3: Testing
- [ ] Test all pages in English
- [ ] Test all pages in Arabic
- [ ] Verify RTL layout
- [ ] Test language switching
- [ ] Test persistence across sessions

## 📋 Step-by-Step Migration Process

### Step 1: Remove Old Translation Imports

**BEFORE:**
```javascript
import { t, getCurrentLanguage } from '@/utils/translations';
const currentLang = ref(getCurrentLanguage());
```

**AFTER:**
```javascript
import { useI18n } from '@/composables/useI18n';
const { t, locale, isRTL, textAlign } = useI18n();
```

### Step 2: Replace Template Strings

**BEFORE:**
```vue
<h1>{{ t('Purchase Orders', currentLang) }}</h1>
<button>{{ t('Filter', currentLang) }}</button>
```

**AFTER:**
```vue
<h1>{{ $t('inventory.purchaseOrders.title') }}</h1>
<button>{{ $t('common.filter') }}</button>
```

### Step 3: Replace Script Strings

**BEFORE:**
```javascript
const title = t('Purchase Orders', currentLang);
```

**AFTER:**
```javascript
const { t } = useI18n();
const title = t('inventory.purchaseOrders.title');
```

### Step 4: Replace Status Translations

**BEFORE:**
```javascript
const statusText = translateStatus(order.status, currentLang);
```

**AFTER:**
```javascript
const { t } = useI18n();
const statusText = t(`status.${order.status}`);
```

### Step 5: Update Alignment Classes

**BEFORE:**
```vue
<th :class="currentLang === 'ar' ? 'text-right' : 'text-left'">
```

**AFTER:**
```vue
<th :class="textAlign">
```

### Step 6: Remove Language Watchers

**BEFORE:**
```javascript
watch(() => window.currentLang || localStorage.getItem('portalLang'), (newLang) => {
  if (newLang) {
    currentLang.value = newLang;
  }
}, { immediate: true });
```

**AFTER:**
```javascript
// No need - handled automatically by useI18n composable
```

## 🔍 Finding Hardcoded Strings

### Search Patterns

Use these regex patterns to find hardcoded strings:

1. **Template strings:**
   ```
   >[^<]*[A-Za-z]{3,}[^<]*<
   ```

2. **JavaScript strings:**
   ```
   ['"`][A-Z][a-z]+ [A-Z][a-z]+['"`]
   ```

3. **Common hardcoded patterns:**
   - `"Filter"`
   - `"Clear"`
   - `"Apply"`
   - `"Save"`
   - `"Cancel"`
   - `"Delete"`
   - `"Edit"`
   - `"View"`

### ESLint Rule (Future)

We'll add a custom ESLint rule to prevent hardcoded strings:

```javascript
// .eslintrc.js
rules: {
  'no-hardcoded-strings': 'error'
}
```

## 📝 Translation Key Naming Convention

### Structure
```
{module}.{section}.{item}
```

### Examples

**GOOD:**
- `inventory.items.title`
- `inventory.purchaseOrders.filter.status`
- `common.actions`
- `status.approved`

**BAD:**
- `itemsTitle`
- `poFilterStatus`
- `actionsButton`
- `approvedStatus`

### Guidelines

1. **Use semantic keys**, not screen-based
2. **Group related keys** under common parent
3. **Use dot notation** for hierarchy
4. **Keep keys short** but descriptive
5. **Reuse common keys** (common.*)

## 🎯 Component Migration Example

### BEFORE (Old System)

```vue
<template>
  <div>
    <h1>{{ t('Purchase Orders', currentLang) }}</h1>
    <button 
      :class="currentLang === 'ar' ? 'text-right' : 'text-left'"
      @click="openFilter"
    >
      {{ t('Filter', currentLang) }}
    </button>
    <table>
      <thead>
        <tr>
          <th :class="currentLang === 'ar' ? 'text-right' : 'text-left'">
            {{ t('Reference', currentLang) }}
          </th>
        </tr>
      </thead>
    </table>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';
import { t, getCurrentLanguage } from '@/utils/translations';

const currentLang = ref(getCurrentLanguage());

watch(() => window.currentLang || localStorage.getItem('portalLang'), (newLang) => {
  if (newLang) {
    currentLang.value = newLang;
  }
}, { immediate: true });
</script>
```

### AFTER (New System)

```vue
<template>
  <div>
    <h1>{{ $t('inventory.purchaseOrders.title') }}</h1>
    <BaseButton 
      :label="$t('common.filter')"
      @click="openFilter"
    />
    <BaseTable
      :headers="[
        { key: 'reference', label: $t('inventory.purchaseOrders.reference') }
      ]"
      :data="orders"
    />
  </div>
</template>

<script setup>
import { useI18n } from '@/composables/useI18n';
import BaseButton from '@/components/base/BaseButton.vue';
import BaseTable from '@/components/base/BaseTable.vue';

const { t, textAlign } = useI18n();
</script>
```

## 🚨 Common Pitfalls to Avoid

### ❌ DON'T

1. **Hardcode strings:**
   ```vue
   <button>Save</button> <!-- BAD -->
   ```

2. **Use conditional language logic:**
   ```vue
   <span>{{ currentLang === 'ar' ? 'حفظ' : 'Save' }}</span> <!-- BAD -->
   ```

3. **Access locale directly:**
   ```javascript
   const lang = i18n.global.locale.value; // BAD - use composable
   ```

4. **Mix translation systems:**
   ```javascript
   import { t } from '@/utils/translations'; // OLD
   import { useI18n } from '@/composables/useI18n'; // NEW
   // Don't use both!
   ```

### ✅ DO

1. **Always use translation keys:**
   ```vue
   <button>{{ $t('common.save') }}</button> <!-- GOOD -->
   ```

2. **Use composable for script:**
   ```javascript
   const { t } = useI18n();
   const message = t('common.save'); // GOOD
   ```

3. **Use base components:**
   ```vue
   <BaseButton :label="$t('common.save')" /> <!-- GOOD -->
   ```

## 📊 Migration Progress Tracking

### Module Status

| Module | Status | Progress |
|--------|--------|----------|
| HomePortal | 🔄 In Progress | 50% |
| Items | ⏳ Pending | 0% |
| PurchaseOrders | ⏳ Pending | 0% |
| GRNs | ⏳ Pending | 0% |
| Suppliers | ⏳ Pending | 0% |
| TransferOrders | ⏳ Pending | 0% |

## 🧪 Testing Checklist

After migrating each component:

- [ ] Component renders in English
- [ ] Component renders in Arabic
- [ ] All text is translated (no English in Arabic mode)
- [ ] RTL layout works correctly
- [ ] Language switching works
- [ ] No console errors
- [ ] No missing translation warnings

## 📚 Additional Resources

- [Vue I18n Documentation](https://vue-i18n.intlify.dev/)
- [RTL Support Guide](./RTL_GUIDE.md)
- [Base Components Documentation](./BASE_COMPONENTS.md)

## 🆘 Need Help?

If you encounter issues during migration:

1. Check the console for translation key warnings
2. Verify the key exists in both en.json and ar.json
3. Ensure you're using the composable correctly
4. Check that i18n is installed in main.js

---

**Last Updated:** 2025-12-22
**Version:** 1.0.0

