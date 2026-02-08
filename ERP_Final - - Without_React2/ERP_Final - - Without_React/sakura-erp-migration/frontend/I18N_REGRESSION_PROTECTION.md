# 🛡️ i18n Regression Protection Guide

**Purpose:** Prevent hardcoded strings and maintain i18n pattern consistency.

---

## 🔍 Automated Checks

### ESLint Configuration
Location: `.eslintrc-i18n.js`

**What it checks:**
- ❌ Blocks imports from old translation system (`@/utils/translations`)
- ⚠️ Warns about common hardcoded strings (Save, Cancel, Edit, etc.)
- ⚠️ Warns about hardcoded placeholders and titles

**How to use:**
```bash
# Add to your .eslintrc.js
extends: ['./.eslintrc-i18n.js']

# Or run separately
npx eslint --config .eslintrc-i18n.js src/views/
```

---

## 📋 Pre-Commit Checklist

Before committing any component changes:

### Template Checks
- [ ] No hardcoded English text in `<template>`
- [ ] All text uses `{{ $t('namespace.key') }}`
- [ ] All placeholders use `:placeholder="$t('key')"`
- [ ] All titles use `:title="$t('key')"`
- [ ] RTL/LTR uses `textAlign` (not manual conditionals)

### Script Checks
- [ ] Uses `useI18n()` composable (not old system)
- [ ] No hardcoded strings in notifications
- [ ] No hardcoded strings in error messages
- [ ] All user-facing text uses `t('key')`

### Translation Files
- [ ] All new keys added to `en.json`
- [ ] All new keys added to `ar.json`
- [ ] Keys follow namespace structure
- [ ] Common keys reused where applicable

---

## 🔎 Manual Review Patterns

### Search for Violations
```bash
# Find hardcoded strings in templates
grep -r '>Save<' src/views/
grep -r '>Cancel<' src/views/
grep -r '>Edit<' src/views/

# Find hardcoded placeholders
grep -r 'placeholder="[A-Z]' src/views/

# Find old translation system usage
grep -r 'from.*@/utils/translations' src/views/
grep -r 'getCurrentLanguage' src/views/
grep -r 'currentLang ===' src/views/
```

### Common Violations to Watch For

1. **Hardcoded Button Text**
   ```vue
   ❌ <button>Save</button>
   ✅ <button>{{ $t('common.save') }}</button>
   ```

2. **Hardcoded Placeholders**
   ```vue
   ❌ <input placeholder="Search...">
   ✅ <input :placeholder="$t('common.search')">
   ```

3. **Hardcoded Titles**
   ```vue
   ❌ <i title="Help">
   ✅ <i :title="$t('common.help')">
   ```

4. **Old Translation System**
   ```js
   ❌ import { t, getCurrentLanguage } from '@/utils/translations';
   ✅ import { useI18n } from '@/composables/useI18n';
   ```

5. **Manual RTL/LTR**
   ```vue
   ❌ :class="locale === 'ar' ? 'text-right' : 'text-left'"
   ✅ :class="textAlign"
   ```

---

## 🚨 PR Review Checklist

When reviewing PRs, check:

### Must Have
- [ ] Uses `useI18n()` composable
- [ ] No hardcoded strings
- [ ] Translation keys exist in both languages
- [ ] RTL/LTR uses `textAlign`

### Should Have
- [ ] Follows GRNs.vue pattern
- [ ] Reuses common keys
- [ ] Proper namespace structure
- [ ] No linter errors

### Must Not Have
- [ ] Old translation system imports
- [ ] Hardcoded English strings
- [ ] Manual RTL/LTR conditionals
- [ ] Missing Arabic translations

---

## 🧪 Testing Checklist

Before marking PR as ready:

### Language Switching
- [ ] Switch to Arabic → All text in Arabic
- [ ] Switch to English → All text in English
- [ ] No mixed language content
- [ ] Direction switches correctly (RTL/LTR)

### Translation Coverage
- [ ] All UI elements translated
- [ ] All buttons translated
- [ ] All form labels translated
- [ ] All table headers translated
- [ ] All error messages translated

### RTL/LTR Layout
- [ ] Tables align correctly in RTL
- [ ] Forms align correctly in RTL
- [ ] Modals align correctly in RTL
- [ ] Buttons align correctly in RTL

---

## 📝 Quick Reference

### Approved Pattern
```vue
<script setup>
import { useI18n } from '@/composables/useI18n';
const { t, locale, textAlign } = useI18n();
</script>

<template>
  <h1>{{ $t('inventory.section.title') }}</h1>
  <th :class="textAlign">{{ $t('inventory.section.header') }}</th>
  <input :placeholder="$t('common.search')" />
</template>
```

### Reference Component
**Always follow:** `src/views/inventory/GRNs.vue`

---

## 🔒 Enforcement

**Violations will:**
1. Block PR merge
2. Require refactor to match pattern
3. Require translation key additions
4. Require RTL/LTR verification

**No exceptions. Pattern is locked.**

---

**Last Updated:** 2025-01-27  
**Status:** ACTIVE ✅

