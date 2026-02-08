# 🚀 Enterprise i18n Installation Guide

## Quick Start

### Step 1: Install Dependencies

```bash
cd sakura-erp-migration/frontend
npm install vue-i18n@^9.8.0
```

### Step 2: Verify Installation

The following files have been created:

- ✅ `src/i18n/index.js` - Global i18n instance
- ✅ `src/composables/useI18n.js` - Composable for components
- ✅ `src/locales/en.json` - English translations
- ✅ `src/locales/ar.json` - Arabic translations
- ✅ `src/components/base/BaseButton.vue` - i18n-aware button
- ✅ `src/components/base/BaseTable.vue` - i18n-aware table
- ✅ `MIGRATION_GUIDE.md` - Complete migration guide

### Step 3: Test the Setup

1. Start the dev server:
   ```bash
   npm run dev
   ```

2. Check the console for any errors

3. Verify language switching works

## What's Been Fixed

1. ✅ **Duplicate `currentLang` error** - Removed duplicate declaration in HomePortal.vue
2. ✅ **Centralized i18n system** - Using vue-i18n (industry standard)
3. ✅ **RTL/LTR handler** - Automatic direction updates
4. ✅ **Base components** - Reusable, i18n-aware components
5. ✅ **Locale files** - Semantic JSON structure

## Next Steps

See `MIGRATION_GUIDE.md` for detailed migration instructions.

## Architecture Overview

```
src/
├── i18n/
│   └── index.js          # Global i18n instance + RTL handler
├── locales/
│   ├── en.json          # English translations
│   └── ar.json          # Arabic translations
├── composables/
│   └── useI18n.js       # Composable for components
└── components/
    └── base/
        ├── BaseButton.vue
        └── BaseTable.vue
```

## Key Features

- ✅ **No hardcoded strings** - All text from locale files
- ✅ **Automatic RTL/LTR** - Direction updates automatically
- ✅ **Type-safe** - Semantic key structure
- ✅ **Scalable** - Easy to add new languages
- ✅ **Enterprise-grade** - Follows SAP/Oracle patterns

