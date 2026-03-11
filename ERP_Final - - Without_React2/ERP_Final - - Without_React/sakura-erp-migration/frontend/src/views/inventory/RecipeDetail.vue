<template>
  <div class="p-6 bg-[#f0e1cd] min-h-screen">
    <div class="flex items-center gap-4 mb-6">
      <router-link to="/homeportal/recipes" class="text-[#284b44] hover:text-[#1e3a36]"><i class="fas fa-arrow-left"></i></router-link>
      <h1 class="text-2xl font-bold text-gray-800">{{ recipe?.name || recipe?.code || 'Recipe' }}</h1>
      <span v-if="recipe" :class="['px-2 py-1 rounded text-xs font-medium', statusClass(recipe.status)]">{{ recipe.status }}</span>
    </div>

    <div v-if="loading" class="bg-white rounded-xl shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading...</p>
    </div>

    <div v-else-if="!recipe" class="bg-white rounded-xl shadow-md p-6">
      <p class="text-gray-600 mb-4">Recipe not found.</p>
      <router-link to="/homeportal/recipes" class="inline-flex items-center gap-2 px-4 py-2 rounded-lg text-white font-medium" style="background-color: #284b44;">
        <i class="fas fa-arrow-left"></i> Back to Recipes list
      </router-link>
    </div>

    <div v-else>
      <!-- Used in production warning -->
      <div v-if="usedInProduction" class="bg-amber-50 border border-amber-200 rounded-xl p-4 mb-6">
        <p class="text-amber-800 font-medium">This recipe is already used in production. Editing will affect costing and consumption.</p>
        <p class="text-sm text-amber-700 mt-1">Consider creating a new version instead of editing.</p>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6 mb-6">
        <h2 class="text-lg font-bold text-gray-800 mb-4">Recipe details</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><span class="text-gray-500">Output item</span><p class="font-medium">{{ recipe.output_item_name }} ({{ recipe.output_item_sku }})</p></div>
          <div><span class="text-gray-500">Base quantity</span><p class="font-medium">{{ recipe.base_quantity ?? recipe.output_qty_per_batch }} {{ recipe.base_unit || 'Pcs' }}</p></div>
          <div><span class="text-gray-500">Version</span><p class="font-medium">v{{ recipe.recipe_version ?? 1 }}</p></div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-md p-6">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-lg font-bold text-gray-800">Ingredients</h2>
          <button
            @click="openAddIngredientModal"
            class="px-4 py-2 rounded-lg text-white text-sm font-medium"
            style="background-color: #284b44;"
          >
            <i class="fas fa-plus mr-1"></i> Add ingredient
          </button>
        </div>
        <div class="border rounded-lg overflow-hidden">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Item</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Quantity</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Unit</th>
                <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Conversion</th>
                <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="ing in ingredients" :key="ing.id">
                <td class="px-4 py-3 font-medium text-gray-900">{{ ing.itemName || ing.name }}</td>
                <td class="px-4 py-3 text-gray-700">{{ ing.quantity ?? ing.quantity_required }}</td>
                <td class="px-4 py-3 text-gray-600">{{ ing.unit || 'Pcs' }}</td>
                <td class="px-4 py-3 text-gray-600">{{ ing.conversion_factor ?? 1 }}</td>
                <td class="px-4 py-3 text-right">
                  <button @click="openEditIngredient(ing)" class="text-blue-600 hover:text-blue-800 mr-3">Edit</button>
                  <button @click="confirmDeleteIngredient(ing)" class="text-red-600 hover:text-red-800">Delete</button>
                </td>
              </tr>
              <tr v-if="!ingredients.length">
                <td colspan="5" class="px-4 py-8 text-center text-gray-500">No ingredients. Add ingredients to define BOM.</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-if="usedInProduction" class="mt-4 flex items-center gap-2">
          <button
            @click="createNewVersion"
            class="px-4 py-2 rounded-lg border border-[#284b44] text-[#284b44] hover:bg-[#284b44] hover:text-white text-sm font-medium"
          >
            Create new version
          </button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Ingredient modal -->
    <div v-if="showIngredientModal" class="fixed inset-0 bg-black/40 flex items-center justify-center z-50" @click.self="closeIngredientModal">
      <div class="bg-white rounded-xl shadow-xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <h3 class="text-lg font-bold mb-4">{{ editingIngredient ? 'Edit ingredient' : 'Add ingredient' }}</h3>
        <div class="space-y-4">
          <div v-if="!editingIngredient">
            <label class="block text-sm font-medium text-gray-700 mb-1">Ingredient item *</label>
            <p v-if="ingredientForm.ingredient_item_id" class="text-sm text-[#284b44] font-medium mb-2">Selected: {{ selectedItemName }}</p>
            <input
              v-model="ingredientSearch"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg mb-2"
              placeholder="Search by name or SKU..."
            />
            <div class="border rounded-lg max-h-48 overflow-y-auto">
              <div
                v-for="item in filteredItems"
                :key="item.id"
                @click="selectIngredientItem(item)"
                class="p-3 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-0"
              >
                <div class="font-medium text-gray-900">{{ item.name }}</div>
                <div v-if="item.sku" class="text-sm text-gray-600">SKU: {{ item.sku }}</div>
              </div>
              <div v-if="filteredItems.length === 0" class="p-4 text-center text-gray-500">No items match</div>
            </div>
          </div>
          <div v-else>
            <p class="text-gray-700"><strong>Item:</strong> {{ editingIngredient.itemName }}</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Quantity *</label>
            <input v-model.number="ingredientForm.quantity" type="number" step="0.0001" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Unit</label>
            <select v-model="ingredientForm.unit" class="w-full px-3 py-2 border border-gray-300 rounded-lg">
              <option v-for="u in COMMON_UNITS" :key="u" :value="u">{{ u }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Storage unit</label>
            <input v-model="ingredientForm.storage_unit" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg" placeholder="Optional" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Conversion factor</label>
            <input v-model.number="ingredientForm.conversion_factor" type="number" step="0.000001" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg" />
          </div>
        </div>
        <div class="flex justify-end gap-2 mt-6">
          <button type="button" @click="closeIngredientModal" class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button type="button" @click="saveIngredient" class="px-4 py-2 rounded-lg text-white" style="background-color: #284b44;">{{ editingIngredient ? 'Update' : 'Add' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import {
  fetchRecipeById,
  fetchRecipeIngredients,
  fetchInventoryItemsForRecipe,
  addRecipeIngredient,
  updateRecipeIngredient,
  deleteRecipeIngredient,
  checkRecipeUsedInProduction,
  createRecipeVersion,
  COMMON_UNITS
} from '@/services/recipeService';

const route = useRoute();
const loading = ref(true);
const recipe = ref(null);
const ingredients = ref([]);
const usedInProduction = ref(false);
const showIngredientModal = ref(false);
const editingIngredient = ref(null);
const inventoryItems = ref([]);
const ingredientSearch = ref('');
const ingredientForm = ref({
  ingredient_item_id: '',
  quantity: 1,
  unit: 'Pcs',
  storage_unit: '',
  conversion_factor: 1
});

const selectedItemName = computed(() => {
  if (!ingredientForm.value.ingredient_item_id) return '';
  const item = inventoryItems.value.find((i) => i.id === ingredientForm.value.ingredient_item_id);
  return item ? (item.name || item.sku || item.id) : '';
});

const filteredItems = computed(() => {
  const q = (ingredientSearch.value || '').toLowerCase();
  if (!q) return inventoryItems.value.slice(0, 50);
  return inventoryItems.value.filter(
    (i) =>
      (i.name && i.name.toLowerCase().includes(q)) ||
      (i.sku && i.sku.toLowerCase().includes(q))
  ).slice(0, 50);
});

function statusClass(s) {
  if (s === 'active') return 'bg-green-100 text-green-800';
  if (s === 'archived') return 'bg-gray-200 text-gray-700';
  return 'bg-amber-100 text-amber-800';
}

async function load() {
  const id = route.params.id;
  if (!id) return;
  try {
    loading.value = true;
    const [r, ings, used] = await Promise.all([
      fetchRecipeById(id),
      fetchRecipeIngredients(id),
      checkRecipeUsedInProduction(id)
    ]);
    recipe.value = r;
    ingredients.value = ings || [];
    usedInProduction.value = !!used;
  } catch (e) {
    recipe.value = null;
    ingredients.value = [];
  } finally {
    loading.value = false;
  }
}

function openAddIngredientModal() {
  if (usedInProduction.value && !confirm('This recipe is used in production. Adding ingredients will affect future runs. Continue?')) return;
  editingIngredient.value = null;
  ingredientForm.value = { ingredient_item_id: '', quantity: 1, unit: 'Pcs', storage_unit: '', conversion_factor: 1 };
  showIngredientModal.value = true;
  fetchInventoryItemsForRecipe().then((items) => {
    const existingIds = ingredients.value.map((i) => i.ingredient_item_id || i.item_id);
    inventoryItems.value = (items || []).filter((i) => !existingIds.includes(i.id));
  });
}

function openEditIngredient(ing) {
  if (usedInProduction.value && !confirm('This recipe is used in production. Editing will affect costing and consumption. Continue?')) return;
  editingIngredient.value = ing;
  ingredientForm.value = {
    ingredient_item_id: ing.ingredient_item_id || ing.item_id,
    quantity: ing.quantity ?? ing.quantity_required,
    unit: ing.unit || 'Pcs',
    storage_unit: ing.storage_unit || '',
    conversion_factor: ing.conversion_factor ?? 1
  };
  showIngredientModal.value = true;
}

function closeIngredientModal() {
  showIngredientModal.value = false;
  editingIngredient.value = null;
  ingredientSearch.value = '';
}

function selectIngredientItem(item) {
  ingredientForm.value.ingredient_item_id = item.id;
  ingredientSearch.value = item.name;
}

async function saveIngredient() {
  if (!recipe.value) return;
  if (editingIngredient.value) {
    await updateRecipeIngredient(editingIngredient.value.id, {
      quantity: ingredientForm.value.quantity,
      unit: ingredientForm.value.unit,
      storage_unit: ingredientForm.value.storage_unit || null,
      conversion_factor: ingredientForm.value.conversion_factor ?? 1
    });
  } else {
    if (!ingredientForm.value.ingredient_item_id) {
      alert('Select an ingredient item');
      return;
    }
    await addRecipeIngredient(recipe.value.id, {
      ingredient_item_id: ingredientForm.value.ingredient_item_id,
      quantity: ingredientForm.value.quantity,
      unit: ingredientForm.value.unit,
      storage_unit: ingredientForm.value.storage_unit || null,
      conversion_factor: ingredientForm.value.conversion_factor ?? 1
    });
  }
  await load();
  closeIngredientModal();
}

function confirmDeleteIngredient(ing) {
  if (!confirm('Remove this ingredient from the recipe?')) return;
  if (usedInProduction.value && !confirm('This recipe is used in production. Removing will affect future runs. Confirm again?')) return;
  deleteRecipeIngredient(ing.id).then(() => load());
}

async function createNewVersion() {
  if (!confirm('Create a new recipe version? You can then edit the new version without affecting existing production.')) return;
  try {
    const newR = await createRecipeVersion(recipe.value.id);
    window.location.href = `#/homeportal/recipes/${newR.id}`;
  } catch (e) {
    alert(e?.message || 'Failed to create version');
  }
}

watch(() => route.params.id, load, { immediate: true });
</script>
