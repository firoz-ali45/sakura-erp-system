<template>
  <div class="pa-6">
    <div class="d-flex justify-space-between align-center mb-6">
      <h1 class="text-h4">Inventory Categories</h1>
      <v-btn
        color="purple"
        prepend-icon="mdi-plus"
        @click="openCreateModal"
      >
        Create Category
      </v-btn>
    </div>

    <v-card>
      <v-data-table
        :headers="headers"
        :items="categories"
        :items-per-page="10"
        class="elevation-1"
      >
        <template v-slot:item.actions="{ item }">
          <v-btn
            icon="mdi-pencil"
            size="small"
            @click="editCategory(item)"
          ></v-btn>
          <v-btn
            icon="mdi-delete"
            size="small"
            color="error"
            @click="deleteCategory(item.id)"
          ></v-btn>
        </template>
      </v-data-table>
    </v-card>

    <!-- Create Category Dialog -->
    <v-dialog v-model="createDialog" max-width="500">
      <v-card>
        <v-card-title>Create Category</v-card-title>
        <v-card-text>
          <v-text-field v-model="newCategory.name" label="Name" required></v-text-field>
          <v-text-field v-model="newCategory.name_localized" label="Name Localized"></v-text-field>
          <v-text-field v-model="newCategory.reference" label="Reference"></v-text-field>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="createDialog = false">Cancel</v-btn>
          <v-btn color="primary" @click="saveCategory">Save</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { getCategories, createCategory, deleteCategory as deleteCategoryAPI } from '../../lib/supabase'

const categories = ref([])
const createDialog = ref(false)
const newCategory = ref({
  name: '',
  name_localized: '',
  reference: ''
})

const headers = [
  { title: 'Name', key: 'name' },
  { title: 'Name Localized', key: 'name_localized' },
  { title: 'Reference', key: 'reference' },
  { title: 'Actions', key: 'actions', sortable: false }
]

async function loadCategories() {
  try {
    categories.value = await getCategories()
  } catch (error) {
    alert('Error loading categories: ' + error.message)
  }
}

function openCreateModal() {
  createDialog.value = true
}

async function saveCategory() {
  try {
    await createCategory(newCategory.value)
    createDialog.value = false
    newCategory.value = { name: '', name_localized: '', reference: '' }
    await loadCategories()
  } catch (error) {
    alert('Error creating category: ' + error.message)
  }
}

function editCategory(category) {
  // TODO: Implement edit functionality
  alert('Edit category: ' + category.name)
}

async function deleteCategory(id) {
  if (confirm('Are you sure you want to delete this category?')) {
    try {
      await deleteCategoryAPI(id)
      await loadCategories()
    } catch (error) {
      alert('Error deleting category: ' + error.message)
    }
  }
}

onMounted(() => {
  loadCategories()
})
</script>
