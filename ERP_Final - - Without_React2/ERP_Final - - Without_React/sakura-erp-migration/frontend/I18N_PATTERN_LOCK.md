# 🔒 i18n Pattern Lock - Single Approved Standard

**Status:** LOCKED ✅  
**Effective Date:** 2025-01-27  
**Reference Standard:** `GRNs.vue`

---

## 🚫 LOCKED RULES (NON-NEGOTIABLE)

### 1. **NO Hardcoded Strings**
❌ **FORBIDDEN:**
```vue
<!-- ❌ NEVER DO THIS -->
<button>Save</button>
<span>No items found</span>
:placeholder="'Type to search...'"
title="Click to edit"
```

✅ **REQUIRED:**
```vue
<!-- ✅ ALWAYS DO THIS -->
<button>{{ $t('common.save') }}</button>
<span>{{ $t('common.noItemsFound') }}</span>
:placeholder="$t('common.typeToSearch')"
:title="$t('common.edit')"
```

### 2. **NO Alternate i18n Logic**
❌ **FORBIDDEN:**
```js
// ❌ NEVER DO THIS
import { t, getCurrentLanguage } from '@/utils/translations';
const currentLang = ref(getCurrentLanguage());
watch(() => window.currentLang, ...);
```

✅ **REQUIRED:**
```js
// ✅ ALWAYS DO THIS
import { useI18n } from '@/composables/useI18n';
const { t, locale, textAlign } = useI18n();
```

### 3. **NO Manual RTL/LTR Conditionals**
❌ **FORBIDDEN:**
```vue
<!-- ❌ NEVER DO THIS -->
:class="locale === 'ar' ? 'text-right' : 'text-left'"
```

✅ **REQUIRED:**
```vue
<!-- ✅ ALWAYS DO THIS -->
:class="textAlign"
```

### 4. **NO Direct Translation Calls**
❌ **FORBIDDEN:**
```vue
<!-- ❌ NEVER DO THIS -->
{{ t('Key', currentLang) }}
```

✅ **REQUIRED:**
```vue
<!-- ✅ ALWAYS DO THIS -->
{{ $t('namespace.key') }}
```

---

## ✅ APPROVED PATTERN (MANDATORY)

### Step 1: Imports
```js
import { useI18n } from '@/composables/useI18n';
```

### Step 2: Setup
```js
const { t, locale, textAlign } = useI18n();
```

### Step 3: Template Usage
```vue
<template>
  <!-- Use $t() in templates -->
  <h1>{{ $t('inventory.section.title') }}</h1>
  
  <!-- Use textAlign for RTL/LTR -->
  <th :class="['px-4 py-2', textAlign]">{{ $t('inventory.section.header') }}</th>
  
  <!-- Use :placeholder and :title bindings -->
  <input :placeholder="$t('common.search')" :title="$t('common.help')" />
</template>
```

### Step 4: Script Usage
```js
// Use t() from composable in script
const message = t('inventory.section.message');
showNotification(t('common.error'), 'error');
```

### Step 5: Translation Keys
```json
// Always add to both en.json and ar.json
{
  "inventory": {
    "section": {
      "title": "Section Title",
      "header": "Header",
      "message": "Message"
    }
  },
  "common": {
    "search": "Search",
    "help": "Help",
    "error": "Error"
  }
}
```

---

## 📋 REFERENCE STANDARD

**All new components MUST follow `GRNs.vue` as the reference standard.**

Location: `src/views/inventory/GRNs.vue`

**Key Features:**
- ✅ Uses `useI18n()` composable
- ✅ Uses `$t()` in templates
- ✅ Uses `t()` in script
- ✅ Uses `textAlign` for RTL/LTR
- ✅ Reuses `common.*` keys
- ✅ Zero hardcoded strings
- ✅ Proper namespace structure

---

## 🛡️ REGRESSION PROTECTION

### Code Review Checklist
Before merging any PR, verify:
- [ ] No hardcoded English strings in templates
- [ ] No hardcoded strings in script (notifications, messages)
- [ ] All placeholders use `:placeholder="$t('key')"`
- [ ] All titles use `:title="$t('key')"`
- [ ] Uses `useI18n()` composable (not old translation system)
- [ ] Uses `textAlign` for RTL/LTR (not manual conditionals)
- [ ] Translation keys exist in both `en.json` and `ar.json`
- [ ] Follows namespace structure (inventory.*, common.*, etc.)

### ESLint Rules
See `.eslintrc.js` for automated checks.

---

## 🚨 VIOLATION HANDLING

If a component violates this pattern:
1. **Block the PR** - Do not merge
2. **Request Refactor** - Follow GRNs.vue pattern
3. **Add Missing Keys** - Ensure translations exist
4. **Verify RTL/LTR** - Test in both languages

---

## 📝 TRANSLATION KEY NAMESPACES

### Common Keys (`common.*`)
Use for reusable UI elements:
- `common.save`, `common.cancel`, `common.edit`, `common.delete`
- `common.all`, `common.filter`, `common.actions`
- `common.previous`, `common.next`, `common.close`

### Module Keys (`inventory.*`, `purchase.*`, etc.)
Use for module-specific content:
- `inventory.items.title`
- `inventory.suppliers.name`
- `inventory.purchaseOrders.status`

---

## ✅ APPROVED COMPONENTS

These components follow the locked pattern:
- ✅ `GRNs.vue` (Reference Standard)
- ✅ `PurchaseOrderDetail.vue`
- ✅ `PurchaseOrders.vue`
- ✅ `Suppliers.vue`
- ✅ `Items.vue`

**All new components must match this standard.**

---

## 🔒 LOCK STATUS

**This pattern is LOCKED and cannot be changed without:**
1. Architecture review
2. Team approval
3. Full regression testing
4. Documentation update

**No exceptions. No shortcuts. No deviations.**

---

**Last Updated:** 2025-01-27  
**Locked By:** i18n Migration Team  
**Status:** PRODUCTION READY ✅

