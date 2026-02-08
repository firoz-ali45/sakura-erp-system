<template>
  <div class="pa-6" v-if="item">
    <div class="d-flex justify-space-between align-center mb-6">
      <div class="d-flex align-center">
        <v-btn icon="mdi-arrow-left" @click="goBack" class="mr-4"></v-btn>
        <h1 class="text-h4">{{ item.name_localized || item.name }} / {{ item.name }}</h1>
      </div>
      <v-btn color="blue" prepend-icon="mdi-pencil" @click="openEditModal">
        Edit Item
      </v-btn>
    </div>

    <v-card>
      <v-card-text>
        <v-row>
          <v-col cols="12" md="6">
            <div class="mb-4">
              <strong>Name:</strong> {{ item.name }}
            </div>
            <div class="mb-4">
              <strong>Name Localized:</strong> {{ item.name_localized || item.name }}
            </div>
            <div class="mb-4">
              <strong>SKU:</strong> {{ item.sku }}
            </div>
            <div class="mb-4">
              <strong>Category:</strong> {{ item.category || 'Uncategorized' }}
            </div>
          </v-col>
          <v-col cols="12" md="6">
            <div class="mb-4">
              <strong>Storage Unit:</strong> {{ item.storage_unit }}
            </div>
            <div class="mb-4">
              <strong>Ingredient Unit:</strong> {{ item.ingredient_unit }}
            </div>
            <div class="mb-4">
              <strong>Costing Method:</strong> {{ item.costing_method }}
            </div>
            <div class="mb-4">
              <strong>Cost:</strong> ₹{{ item.cost || 0 }}
            </div>
          </v-col>
        </v-row>
      </v-card-text>
    </v-card>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getItemById } from '../../lib/supabase'

const route = useRoute()
const router = useRouter()
const item = ref(null)

onMounted(async () => {
  const itemId = route.params.id
  try {
    item.value = await getItemById(itemId)
  } catch (error) {
    alert('Error loading item: ' + error.message)
    router.push({ name: 'Items' })
  }
})

function goBack() {
  router.push({ name: 'Items' })
}

function openEditModal() {
  // TODO: Implement edit modal
  alert('Edit functionality coming soon')
}
</script>
