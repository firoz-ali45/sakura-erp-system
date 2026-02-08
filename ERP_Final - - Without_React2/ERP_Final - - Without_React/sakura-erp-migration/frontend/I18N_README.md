# 🌐 i18n System - Quick Start

**Status:** ✅ Production Ready & Locked

---

## 📖 Documentation

1. **[I18N_PATTERN_LOCK.md](./I18N_PATTERN_LOCK.md)** - Locked pattern standard (READ THIS FIRST)
2. **[I18N_REGRESSION_PROTECTION.md](./I18N_REGRESSION_PROTECTION.md)** - How to prevent regressions
3. **[I18N_TASK_CLOSED.md](./I18N_TASK_CLOSED.md)** - Task completion status
4. **[I18N_MIGRATION_FINAL_REPORT.md](./I18N_MIGRATION_FINAL_REPORT.md)** - Migration details
5. **[QUICK_I18N_REFERENCE.md](./QUICK_I18N_REFERENCE.md)** - Quick reference guide

---

## ⚡ Quick Start

### For New Components

1. **Import the composable:**
   ```js
   import { useI18n } from '@/composables/useI18n';
   const { t, locale, textAlign } = useI18n();
   ```

2. **Use in template:**
   ```vue
   <template>
     <h1>{{ $t('inventory.section.title') }}</h1>
     <th :class="textAlign">{{ $t('inventory.section.header') }}</th>
   </template>
   ```

3. **Use in script:**
   ```js
   const message = t('inventory.section.message');
   ```

4. **Add translations:**
   - Add to `src/locales/en.json`
   - Add to `src/locales/ar.json`

5. **Follow GRNs.vue as reference:**
   - See `src/views/inventory/GRNs.vue`

---

## 🚫 What NOT to Do

❌ **NEVER:**
- Hardcode English strings
- Use old translation system (`@/utils/translations`)
- Use manual RTL/LTR conditionals
- Skip Arabic translations

✅ **ALWAYS:**
- Use `useI18n()` composable
- Use `$t()` in templates
- Use `textAlign` for RTL/LTR
- Add keys to both languages

---

## 🛡️ Regression Protection

### ESLint Rules
The project includes ESLint rules to catch violations:
- Location: `.eslintrc-i18n.js`
- Blocks old translation system imports
- Warns about hardcoded strings

### Code Review
Before merging PRs, check:
- No hardcoded strings
- Uses `useI18n()` composable
- Translation keys exist in both languages
- Follows GRNs.vue pattern

**See:** [I18N_REGRESSION_PROTECTION.md](./I18N_REGRESSION_PROTECTION.md)

---

## 📋 Reference Standard

**All components must follow:** `src/views/inventory/GRNs.vue`

This component demonstrates:
- ✅ Correct composable usage
- ✅ Template translation pattern
- ✅ RTL/LTR handling
- ✅ Common key reuse
- ✅ Zero hardcoded strings

---

## ✅ Approved Components

These components follow the locked pattern:
- ✅ `GRNs.vue` (Reference)
- ✅ `PurchaseOrderDetail.vue`
- ✅ `PurchaseOrders.vue`
- ✅ `Suppliers.vue`
- ✅ `Items.vue`

---

## 🔒 Pattern Status

**LOCKED** - This pattern cannot be changed without:
1. Architecture review
2. Team approval
3. Full regression testing
4. Documentation update

**See:** [I18N_PATTERN_LOCK.md](./I18N_PATTERN_LOCK.md)

---

**Last Updated:** 2025-01-27  
**Status:** Production Ready ✅

