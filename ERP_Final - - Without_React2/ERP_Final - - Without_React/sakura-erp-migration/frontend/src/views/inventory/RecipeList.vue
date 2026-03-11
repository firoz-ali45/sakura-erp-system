<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-800">Recipes / BOM</h1>
        <p class="text-sm text-gray-600 mt-1">Bill of materials and ingredients for finished goods</p>
      </div>
      <button
        @click="openNewModal"
        class="px-6 py-3 rounded-lg text-white font-semibold flex items-center gap-2"
        style="background-color: #284b44;"
      >
        <i class="fas fa-plus"></i> New Recipe
      </button>
    </div>

    <!-- New Recipe modal -->
    <div v-if="showNewModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="showNewModal = false">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-md">
        <h3 class="text-lg font-bold mb-4">New Recipe</h3>
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Recipe name *</label>
            <input v-model="newForm.name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg" placeholder="e.g. Chocolate Cake" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Output (FG) item *</label>
            <select v-model="newForm.output_item_id" class="w-full px-3 py-2 border border-gray-300 rounded-lg" required>
              <option value="">Select item...</option>
              <option v-for="i in inventoryItems" :key="i.id" :value="i.id">{{ i.name }} ({{ i.sku }})</option>
            </select>
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Base quantity</label>
              <input v-model.number="newForm.base_quantity" type="number" step="0.0001" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Base unit</label>
              <select v-model="newForm.base_unit" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
                <option v-for="u in COMMON_UNITS" :key="u" :value="u">{{ u }}</option>
              </select>
            </div>
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" @click="showNewModal = false" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button type="button" @click="createRecipeSubmit" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">Create</button>
        </div>
      </div>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading recipes...</p>
    </div>

    <div v-else-if="loadError" class="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6">
      <p class="text-amber-800">{{ loadError }}</p>
    </div>

    <div v-else class="bg-white rounded-xl shadow-md overflow-hidden">
      <table class="w-full">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Recipe</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Output Item</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Version</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Base Qty</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Ingredients</th>
            <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200">
          <tr v-for="r in recipes" :key="r.id" class="hover:bg-gray-50">
            <td class="px-6 py-3 font-medium text-gray-900">{{ r.name || r.code }}</td>
            <td class="px-6 py-3 text-gray-700">{{ r.output_item_name || '—' }}</td>
            <td class="px-6 py-3 text-gray-600">v{{ r.recipe_version ?? 1 }}</td>
            <td class="px-6 py-3 text-gray-600">{{ r.base_quantity ?? r.output_qty_per_batch }} {{ r.base_unit || 'Pcs' }}</td>
            <td class="px-6 py-3">
              <span :class="['px-2 py-1 rounded text-xs font-medium', statusClass(r.status)]">{{ r.status || 'draft' }}</span>
            </td>
            <td class="px-6 py-3 text-gray-600">{{ r.ingredient_count ?? 0 }}</td>
            <td class="px-6 py-3 text-right">
              <router-link :to="`/homeportal/recipes/${r.id}`" class="text-[#284b44] hover:text-[#1e3a36] font-medium">Open</router-link>
            </td>
          </tr>
          <tr v-if="!recipes.length">
            <td colspan="7" class="px-6 py-12 text-center text-gray-500">No recipes. Create a recipe to define BOM for an item.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { fetchRecipes, createRecipe as createRecipeApi, fetchInventoryItemsForRecipe, COMMON_UNITS } from '@/services/recipeService';

const router = useRouter();
const loading = ref(true);
const loadError = ref('');
const recipes = ref([]);
const showNewModal = ref(false);
const inventoryItems = ref([]);
const newForm = ref({ name: '', output_item_id: '', base_quantity: 1, base_unit: 'Pcs' });

async function createRecipeSubmit() {
  if (!newForm.value.name?.trim() || !newForm.value.output_item_id) return;
  try {
    const r = await createRecipeApi({
      name: newForm.value.name.trim(),
      item_id: newForm.value.output_item_id,
      output_item_id: newForm.value.output_item_id,
      base_quantity: newForm.value.base_quantity ?? 1,
      base_unit: newForm.value.base_unit || 'Pcs'
    });
    showNewModal.value = false;
    newForm.value = { name: '', output_item_id: '', base_quantity: 1, base_unit: 'Pcs' };
    router.push(`/homeportal/recipes/${r.id}`);
  } catch (e) {
    alert(e?.message || 'Failed to create recipe');
  }
}

async function openNewModal() {
  showNewModal.value = true;
  try {
    inventoryItems.value = await fetchInventoryItemsForRecipe();
  } catch {
    inventoryItems.value = [];
  }
}

function statusClass(s) {
  if (s === 'active') return 'bg-green-100 text-green-800';
  if (s === 'archived') return 'bg-gray-200 text-gray-700';
  return 'bg-amber-100 text-amber-800';
}

onMounted(async () => {
  try {
    loadError.value = '';
    recipes.value = await fetchRecipes();
  } catch (e) {
    loadError.value = (e?.message || String(e)).slice(0, 200);
    recipes.value = [];
  } finally {
    loading.value = false;
  }
});
</script>
