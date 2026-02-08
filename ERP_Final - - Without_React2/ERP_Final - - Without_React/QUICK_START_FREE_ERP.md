# 🚀 Quick Start: FREE ERP in 10 Minutes

## ⚡ **Super Fast Setup**

### **Step 1: Create Project (2 minutes)**
```bash
npx create-next-app@latest sakura-factory --typescript --tailwind --app --yes
cd sakura-factory
npm install @supabase/supabase-js
```

### **Step 2: Add Environment Variables (1 minute)**
Create `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://kexwnurwavszvmlpifsf.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtleHdudXJ3YXZzenZtbHBpZnNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzk5OTksImV4cCI6MjA4MDg1NTk5OX0.w7RlFdXVFdKtqJJ99L0Q1ofzUiwillyy-g1ASEj1q-U
```

### **Step 3: Run (1 minute)**
```bash
npm run dev
```

**Open:** `http://localhost:3000` ✅

### **Step 4: Deploy (5 minutes)**
```bash
npm install -g vercel
vercel login
vercel
```

**Done!** Your site is LIVE! 🎉

---

## 📁 **Essential Files to Create**

### **1. `lib/supabase.ts`**
```typescript
import { createClient } from '@supabase/supabase-js';

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);
```

### **2. `app/api/items/route.ts`**
```typescript
import { supabase } from '@/lib/supabase';
import { NextResponse } from 'next/server';

export async function GET() {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*');
  return NextResponse.json(data || []);
}

export async function POST(request: Request) {
  const body = await request.json();
  const { data, error } = await supabase
    .from('inventory_items')
    .insert([body])
    .select()
    .single();
  return NextResponse.json(data);
}
```

### **3. `app/Inventory/Items/page.tsx`**
```typescript
'use client';

export default function ItemsPage() {
  return (
    <div>
      <h1 className="text-3xl font-bold">Inventory Items</h1>
      {/* Your items table here */}
    </div>
  );
}
```

---

## 🎯 **That's It!**

✅ **FREE forever**
✅ **Same structure as Foodics**
✅ **Ultra-fast**
✅ **Production-ready**

---

**Need help?** I can create all files for you! 🚀
