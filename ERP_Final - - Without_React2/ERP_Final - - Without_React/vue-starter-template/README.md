# Vue.js Starter Template - Foodics Style

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Run development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## 📁 Project Structure

```
vue-starter-template/
├── src/
│   ├── components/
│   │   ├── Sidebar.vue
│   │   ├── Header.vue
│   │   └── ItemsTable.vue
│   ├── views/
│   │   ├── HomePortal.vue
│   │   ├── Inventory/
│   │   │   ├── Items.vue
│   │   │   ├── Categories.vue
│   │   │   └── More.vue
│   │   ├── Warehouse.vue
│   │   └── UserManagement.vue
│   ├── router/
│   │   └── index.js
│   ├── stores/
│   │   └── inventory.js
│   ├── lib/
│   │   └── supabase.js
│   ├── App.vue
│   └── main.js
├── package.json
└── vite.config.js
```

## 🔧 Configuration

### Supabase Setup
Edit `src/lib/supabase.js` with your credentials:
```javascript
const SUPABASE_URL = 'your-supabase-url'
const SUPABASE_ANON_KEY = 'your-anon-key'
```

## 🌐 Routes

- `/` - Home Portal
- `/Inventory/Items` - Items List
- `/Inventory/Categories` - Categories
- `/Inventory/More` - More Options
- `/Warehouse` - Warehouse Dashboard
- `/UserManagement` - User Management

## 📦 Dependencies

- Vue.js 3
- Vue Router
- Pinia (state management)
- Vuetify (UI components)
- Supabase JS
- Axios

## 🎨 Features

- ✅ Foodics-style architecture
- ✅ Clean URL routing
- ✅ State management with Pinia
- ✅ Supabase integration
- ✅ Responsive design
- ✅ Material Design UI
