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
            <input
              v-model="newForm.name"
              type="text"
              class="w-full px-3 py-2 border rounded-lg"
              :class="validationErrors.name ? 'border-red-500 bg-red-50' : 'border-gray-300'"
              placeholder="e.g. Chocolate Cake"
            />
            <p v-if="validationErrors.name" class="text-sm text-red-600 mt-1">{{ validationErrors.name }}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Output (FG) item *</label>
            <p v-if="selectedOutputItem" class="text-sm text-[#284b44] font-medium mb-1">Selected: {{ selectedOutputItem }}</p>
            <input
              v-model="outputItemSearch"
              type="text"
              class="w-full px-3 py-2 border rounded-lg mb-1"
              :class="validationErrors.output_item ? 'border-red-500 bg-red-50' : 'border-gray-300'"
              placeholder="Type here to search by name or SKU (1000+ items)..."
              autocomplete="off"
            />
            <div class="border border-gray-300 rounded-lg max-h-52 overflow-y-auto bg-white">
              <div
                v-for="i in filteredOutputItems"
                :key="i.id"
                @click="selectOutputItem(i)"
                class="px-3 py-2 hover:bg-[#284b44]/10 cursor-pointer border-b border-gray-100 last:border-0"
              >
                <div class="font-medium text-gray-900">{{ i.name }}</div>
                <div class="text-xs text-gray-500">{{ i.sku }}</div>
              </div>
              <div v-if="outputItemSearch && filteredOutputItems.length === 0" class="px-3 py-4 text-center text-gray-500 text-sm">No items match</div>
              <div v-else-if="!outputItemSearch && inventoryItems.length === 0" class="px-3 py-4 text-center text-gray-500 text-sm">Loading items...</div>
            </div>
            <p v-if="validationErrors.output_item" class="text-sm text-red-600 mt-1">{{ validationErrors.output_item }}</p>
            <p v-else class="text-xs text-gray-500 mt-1">Search by name or SKU to quickly find from {{ inventoryItems.length }} items.</p>
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
        <p v-if="createSuccess" class="text-sm text-green-600 mt-2">Recipe created. Add another below or close.</p>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" @click="showNewModal = false" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button type="button" @click="createRecipeSubmit(true)" class="px-4 py-2 border border-[#284b44] text-[#284b44] rounded-lg hover:bg-[#284b44] hover:text-white">Create & add another</button>
          <button type="button" @click="createRecipeSubmit(false)" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">Create & open</button>
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
      <div class="p-4 border-b border-gray-200 bg-gray-50 flex items-center gap-3">
        <label for="recipe-list-search" class="text-sm font-medium text-gray-700 whitespace-nowrap">Search recipes</label>
        <input
          id="recipe-list-search"
          v-model="listSearchQuery"
          type="text"
          class="flex-1 max-w-md px-3 py-2 border border-gray-300 rounded-lg"
          placeholder="Type to filter by recipe name, output item or status..."
          autocomplete="off"
        />
        <span v-if="listSearchQuery" class="text-sm text-gray-500">{{ filteredRecipes.length }} of {{ recipes.length }}</span>
      </div>
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
          <tr v-for="r in filteredRecipes" :key="r.id" class="hover:bg-gray-50">
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
          <tr v-if="!filteredRecipes.length">
            <td colspan="7" class="px-6 py-12 text-center text-gray-500">
              {{ listSearchQuery ? 'No recipes match your search.' : 'No recipes. Create a recipe to define BOM for an item.' }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { fetchRecipes, createRecipe as createRecipeApi, fetchInventoryItemsForRecipe, COMMON_UNITS } from '@/services/recipeService';

const router = useRouter();
const loading = ref(true);
const loadError = ref('');
const recipes = ref([]);
const showNewModal = ref(false);
const createSuccess = ref(false);
const inventoryItems = ref([]);
const outputItemSearch = ref('');
const listSearchQuery = ref('');
const validationErrors = ref({ name: '', output_item: '' });
const newForm = ref({ name: '', output_item_id: '', base_quantity: 1, base_unit: 'Pcs' });

const filteredRecipes = computed(() => {
  const q = (listSearchQuery.value || '').toLowerCase().trim();
  if (!q) return recipes.value;
  return recipes.value.filter(
    (r) =>
      (r.name && r.name.toLowerCase().includes(q)) ||
      (r.code && r.code.toLowerCase().includes(q)) ||
      (r.output_item_name && r.output_item_name.toLowerCase().includes(q)) ||
      (r.output_item_sku && r.output_item_sku.toLowerCase().includes(q)) ||
      (r.status && r.status.toLowerCase().includes(q))
  );
});

const selectedOutputItem = computed(() => {
  if (!newForm.value.output_item_id) return null;
  const i = inventoryItems.value.find((x) => x.id === newForm.value.output_item_id);
  return i ? `${i.name} (${i.sku})` : null;
});

const filteredOutputItems = computed(() => {
  const q = (outputItemSearch.value || '').toLowerCase().trim();
  if (!q) return inventoryItems.value.slice(0, 80);
  return inventoryItems.value.filter(
    (i) =>
      (i.name && i.name.toLowerCase().includes(q)) ||
      (i.sku && i.sku.toLowerCase().includes(q))
  ).slice(0, 80);
});

function selectOutputItem(item) {
  newForm.value.output_item_id = item.id;
  outputItemSearch.value = item.name || item.sku || '';
}

/** @param {boolean} addAnother - if true, keep modal open and reset form for another recipe */
async function createRecipeSubmit(addAnother = false) {
  validationErrors.value = { name: '', output_item: '' };
  const missingName = !newForm.value.name?.trim();
  const missingItem = !newForm.value.output_item_id;
  if (missingName) validationErrors.value.name = 'Recipe name is required.';
  if (missingItem) validationErrors.value.output_item = 'Please select an Output (FG) item from the list above.';
  if (missingName || missingItem) return;
  try {
    const r = await createRecipeApi({
      name: newForm.value.name.trim(),
      item_id: newForm.value.output_item_id,
      output_item_id: newForm.value.output_item_id,
      base_quantity: newForm.value.base_quantity ?? 1,
      base_unit: newForm.value.base_unit || 'Pcs'
    });
    createSuccess.value = true;
    recipes.value = await fetchRecipes();
    newForm.value = { name: '', output_item_id: '', base_quantity: 1, base_unit: 'Pcs' };
    outputItemSearch.value = '';
    validationErrors.value = { name: '', output_item: '' };
    if (addAnother) {
      createSuccess.value = true;
    } else {
      showNewModal.value = false;
      createSuccess.value = false;
      router.push(`/homeportal/recipes/${r.id}`);
    }
  } catch (e) {
    const msg = e?.message || '';
    if (msg.includes('Version conflict') || msg.includes('duplicate')) {
      alert('Recipe already exists or version conflict detected. Try a different output item or refresh the list.');
    } else {
      alert(msg || 'Failed to create recipe');
    }
  }
}

async function openNewModal() {
  createSuccess.value = false;
  validationErrors.value = { name: '', output_item: '' };
  outputItemSearch.value = '';
  showNewModal.value = true;
  newForm.value = { name: '', output_item_id: '', base_quantity: 1, base_unit: 'Pcs' };
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
