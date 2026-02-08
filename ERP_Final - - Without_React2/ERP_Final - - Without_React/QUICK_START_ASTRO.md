# Quick Start: Astro Implementation (Fastest Migration)

## 🚀 Why Astro?
- ✅ Can use your existing HTML/JS/CSS
- ✅ Ultra-fast (< 1 second load)
- ✅ Clean URLs automatically
- ✅ Easy migration (1 week)

---

## Step 1: Setup (5 minutes)

```bash
# Create Astro project
npm create astro@latest sakura-factory

# Choose options:
# - Template: Empty
# - TypeScript: Yes
# - Install dependencies: Yes

cd sakura-factory
npm install @supabase/supabase-js
```

---

## Step 2: Project Structure

```
sakura-factory/
├── src/
│   ├── layouts/
│   │   └── Layout.astro (Main layout with sidebar)
│   ├── components/
│   │   ├── Sidebar.astro
│   │   ├── Header.astro
│   │   └── ItemsTable.astro
│   └── pages/
│       ├── index.astro (Home Portal)
│       ├── Inventory/
│       │   ├── Items.astro
│       │   ├── Categories.astro
│       │   └── More.astro
│       ├── Warehouse.astro
│       ├── UserManagement.astro
│       └── QualityTraceability.astro
├── public/
│   └── (your assets)
└── package.json
```

---

## Step 3: Main Layout

```astro
---
// src/layouts/Layout.astro
---

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sakura Factory ERP</title>
  <script src="https://cdn.tailwindcss.com"></script>
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
</head>
<body>
  <div class="flex h-screen">
    <!-- Sidebar -->
    <aside class="w-64 bg-[#284b44] text-white">
      <nav>
        <a href="/" class="nav-link">Home Portal</a>
        <a href="/Inventory/Items" class="nav-link">Items</a>
        <a href="/Inventory/Categories" class="nav-link">Categories</a>
        <a href="/Warehouse" class="nav-link">Warehouse</a>
        <a href="/UserManagement" class="nav-link">User Management</a>
      </nav>
    </aside>
    
    <!-- Main Content -->
    <main class="flex-1 overflow-auto">
      <slot />
    </main>
  </div>
</body>
</html>
```

---

## Step 4: Home Portal Page

```astro
---
// src/pages/index.astro
import Layout from '../layouts/Layout.astro';
---

<Layout>
  <div class="p-6">
    <h1 class="text-3xl font-bold">Home Portal</h1>
    <!-- Your existing home portal content -->
  </div>
</Layout>
```

**URL:** `sakurafactory.com/` ✅

---

## Step 5: Inventory Items Page

```astro
---
// src/pages/Inventory/Items.astro
import Layout from '../../layouts/Layout.astro';
import ItemsTable from '../../components/ItemsTable.astro';
---

<Layout>
  <div class="p-6">
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-3xl font-bold">Inventory Items</h1>
      <button onclick="openCreateModal()" class="px-4 py-2 bg-purple-600 text-white rounded">
        + Create Item
      </button>
    </div>
    <ItemsTable client:load />
  </div>
</Layout>

<script>
  // Your existing items.html JavaScript
  function openCreateModal() {
    // Modal logic
  }
</script>
```

**URL:** `sakurafactory.com/Inventory/Items` ✅

---

## Step 6: Item Detail Page (Dynamic Route)

```astro
---
// src/pages/Inventory/Items/[id].astro
import Layout from '../../../layouts/Layout.astro';
import { getItemById } from '../../../lib/supabase';

const { id } = Astro.params;
const item = await getItemById(id);
---

<Layout>
  <div class="p-6">
    <h1 class="text-3xl font-bold">{item.name}</h1>
    <!-- Item details -->
  </div>
</Layout>
```

**URL:** `sakurafactory.com/Inventory/Items/123` ✅

---

## Step 7: Supabase Integration

```typescript
// src/lib/supabase.ts
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://kexwnurwavszvmlpifsf.supabase.co';
const supabaseKey = 'your-anon-key';

export const supabase = createClient(supabaseUrl, supabaseKey);

export async function getItems() {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*');
  return data;
}

export async function getItemById(id: string) {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*')
    .eq('id', id)
    .single();
  return data;
}
```

---

## Step 8: Build & Deploy

```bash
# Build for production
npm run build

# Preview locally
npm run preview

# Deploy to Vercel
npm install -g vercel
vercel deploy

# Or deploy to Netlify
npm install -g netlify-cli
netlify deploy
```

---

## 🎯 Result

✅ Clean URLs: `sakurafactory.com/Inventory/Items`
✅ < 1 second load time
✅ SEO-friendly
✅ No iframes needed
✅ Production-ready

---

## 📝 Migration Checklist

- [ ] Setup Astro project
- [ ] Create layout with sidebar
- [ ] Migrate Home Portal
- [ ] Migrate Inventory/Items
- [ ] Migrate Inventory/Categories
- [ ] Migrate other modules
- [ ] Test all routes
- [ ] Deploy to production
- [ ] Setup custom domain

---

## 🚀 Performance Tips

1. **Use `client:load`** only for interactive components
2. **Static pages** load instantly
3. **Islands architecture** - only load JS when needed
4. **Image optimization** with Astro's Image component

---

## Next Steps

1. Run `npm create astro@latest`
2. Copy your existing HTML to `.astro` files
3. Add `<Layout>` wrapper
4. Deploy!

**Time to production: 1 week** ⚡
