<template>
  <div class="pa-6">
    <div class="d-flex justify-space-between align-center mb-6">
      <h1 class="text-h4">Inventory Items</h1>
      <v-btn
        color="purple"
        prepend-icon="mdi-plus"
        @click="openCreateModal"
      >
        Create Item
      </v-btn>
    </div>

    <v-card v-if="inventoryStore.loading">
      <v-card-text>
        <v-progress-linear indeterminate></v-progress-linear>
      </v-card-text>
    </v-card>

    <v-card v-else>
      <v-data-table
        :headers="headers"
        :items="inventoryStore.items"
        :items-per-page="10"
        class="elevation-1"
      >
        <template v-slot:item.name="{ item }">
          <div>
            <div class="font-weight-medium">{{ item.name_localized || item.name }}</div>
            <div class="text-caption text-grey">{{ item.name }}</div>
          </div>
        </template>

        <template v-slot:item.category="{ item }">
          <v-chip size="small" :color="getCategoryColor(item.category)">
            {{ item.category || 'Uncategorized' }}
          </v-chip>
        </template>

        <template v-slot:item.actions="{ item }">
          <v-btn
            icon="mdi-pencil"
            size="small"
            @click="editItem(item.id)"
          ></v-btn>
          <v-btn
            icon="mdi-delete"
            size="small"
            color="error"
            @click="deleteItem(item.id)"
          ></v-btn>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create Item Dialog -->
    <v-dialog v-model="createDialog" max-width="800">
      <v-card>
        <v-card-title>Create Item</v-card-title>
        <v-card-text>
          <v-text-field v-model="newItem.name" label="Name" required></v-text-field>
          <v-text-field v-model="newItem.name_localized" label="Name Localized"></v-text-field>
          <v-text-field v-model="newItem.sku" label="SKU" required></v-text-field>
          <v-text-field v-model="newItem.category" label="Category"></v-text-field>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" @click="saveItem">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useInventoryStore } from '../../stores/inventory'

const router = useRouter()
const inventoryStore = useInventoryStore()

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'SKU', key: 'sku' },
  { title: 'Category', key: 'category' },
  { title: 'Actions', key: 'actions', sortable: false }
]

const createDialog = ref(false)
const newItem = ref({
  name: '',
  name_localized: '',
  sku: '',
  category: '',
  storage_unit: 'Pcs',
  ingredient_unit: 'Pcs',
  storage_to_ingredient: 1,
  costing_method: 'From Transactions',
  cost: 0
})

function getCategoryColor(category) {
  const colors = {
    'Equipments': 'blue',
    'Packaging': 'green',
    'FG & WIP Items from Production Section': 'purple'
  }
  return colors[category] || 'grey'
}

function openCreateModal() {
  createDialog.value = true
}

async function saveItem() {
  try {
    await inventoryStore.addItem(newItem.value)
    createDialog.value = false
    newItem.value = {
      name: '',
      name_localized: '',
      sku: '',
      category: '',
      storage_unit: 'Pcs',
      ingredient_unit: 'Pcs',
      storage_to_ingredient: 1,
      costing_method: 'From Transactions',
      cost: 0
    }
  } catch (error) {
    alert('Error creating item: ' + error.message)
  }
}

function editItem(id) {
  router.push({ name: 'ItemDetail', params: { id } })
}

async function deleteItem(id) {
  if (confirm('Are you sure you want to delete this item?')) {
    try {
      await inventoryStore.removeItem(id)
    } catch (error) {
      alert('Error deleting item: ' + error.message)
    }
  }
}

onMounted(() => {
  inventoryStore.loadItems()
})
</script>
