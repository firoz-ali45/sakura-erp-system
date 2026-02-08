# 🚀 Quick i18n Reference Guide

## ✅ Core System is Ready!

The global i18n system is **fully implemented and working**. The language store is the single source of truth.

## 📝 Quick Usage

### In Vue Templates
```vue
<template>
  <div>
    <h1>{{ $t('homePortal.title') }}</h1>
    <button>{{ $t('common.save') }}</button>
  </div>
</template>
```

### In Script Setup
```js
import { useI18n } from '@/composables/useI18n';

const { t, locale, setLocale, isRTL } = useI18n();

// Use translation
const title = t('homePortal.welcome');

// Change language (updates entire system)
setLocale('ar');
```

### Change Language Programmatically
```js
import { useLanguageStore } from '@/stores/language';

const languageStore = useLanguageStore();
languageStore.setLanguage('en'); // Changes to English + LTR
```

## 🔄 Migration Checklist for Remaining Components

The following components still use the old system and should be migrated:

- [ ] `views/inventory/GRNs.vue`
- [ ] `views/inventory/PurchaseOrderDetail.vue`
- [ ] `views/inventory/Suppliers.vue`
- [ ] `views/inventory/PurchaseOrders.vue`
- [ ] `views/inventory/Items.vue`
- [ ] `views/inventory/TransferOrders.vue`
- [ ] `views/manage/Tags.vue`
- [ ] `views/manage/More.vue`
- [ ] `views/UserManagement.vue`

### Migration Steps:

1. **Remove old imports:**
   ```js
   // DELETE
   import { t, getCurrentLanguage } from '@/utils/translations';
   import { translatePage, broadcastLanguageChange } from '@/utils/i18n';
   ```

2. **Add new import:**
   ```js
   // ADD
   import { useI18n } from '@/composables/useI18n';
   const { t, locale, setLocale } = useI18n();
   ```

3. **Replace translation calls:**
   ```js
   // OLD
   t('KEY', getCurrentLanguage())
   
   // NEW
   t('key.path')
   ```

4. **Remove translatePage calls:**
   ```js
   // DELETE - No longer needed!
   translatePage(savedLang);
   ```

5. **Update language switching:**
   ```js
   // OLD
   broadcastLanguageChange('ar');
   
   // NEW
   setLocale('ar');
   ```

## ✅ What's Already Working

- ✅ Global language store (single source of truth)
- ✅ HomePortal.vue fully migrated
- ✅ RTL/LTR direction enforcement
- ✅ Language persistence (localStorage)
- ✅ Cross-tab synchronization
- ✅ Iframe communication
- ✅ All translations in JSON files

## 🎯 Current Status

**Core System:** ✅ Complete and Production Ready
**Component Migration:** ⚠️ In Progress (9 components remaining)

The core system works globally. Remaining components will automatically benefit once migrated.

