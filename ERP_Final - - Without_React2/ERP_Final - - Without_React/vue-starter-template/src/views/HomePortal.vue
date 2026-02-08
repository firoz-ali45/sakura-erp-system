<template>
  <div class="pa-4 pa-md-6">
    <h1 class="text-h4 mb-6 font-weight-bold text-grey-darken-2">Home Portal</h1>
    
    <v-row>
      <v-col cols="12" md="4">
        <div class="kpi-card">
          <div class="icon" style="background-color: #284b44;">
            <i class="fas fa-boxes"></i>
          </div>
          <div>
            <p class="title">Inventory</p>
            <div class="value">Total Items: {{ itemCount }}</div>
          </div>
        </div>
      </v-col>
      
      <v-col cols="12" md="4">
        <div class="kpi-card">
          <div class="icon" style="background-color: #956c2a;">
            <i class="fas fa-folder"></i>
          </div>
          <div>
            <p class="title">Categories</p>
            <div class="value">Total Categories: {{ categoryCount }}</div>
          </div>
        </div>
      </v-col>
      
      <v-col cols="12" md="4">
        <div class="kpi-card">
          <div class="icon" style="background-color: #ea8990;">
            <i class="fas fa-warehouse"></i>
          </div>
          <div>
            <p class="title">Warehouse</p>
            <div class="value">Status: Active</div>
          </div>
        </div>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useInventoryStore } from '../stores/inventory'
import { getCategories } from '../lib/supabase'
import { ref, onMounted } from 'vue'

const inventoryStore = useInventoryStore()
const categoryCount = ref(0)

const itemCount = computed(() => inventoryStore.items.length)

onMounted(async () => {
  await inventoryStore.loadItems()
  const categories = await getCategories()
  categoryCount.value = categories.length
})
</script>
