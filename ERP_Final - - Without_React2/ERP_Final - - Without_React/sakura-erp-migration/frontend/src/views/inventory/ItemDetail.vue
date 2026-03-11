<template>
  <div class="bg-[#f0e1cd] p-6">
    <!-- Header Section -->
    <div class="flex justify-between items-center mb-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-[#284b44] hover:text-[#1f3d38] flex items-center gap-2">
          <i class="fas fa-arrow-left"></i>
          <span>Back</span>
        </button>
        <div class="flex items-center gap-3">
          <h1 class="text-3xl font-bold text-gray-800">
            {{ displayItemName }}
          </h1>
          <span v-if="item?.deleted" class="px-3 py-1 bg-red-100 text-red-800 rounded-full text-sm font-semibold">Deleted</span>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <button 
          v-if="item?.deleted" 
          @click="restoreItem" 
          class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center gap-2 font-semibold"
        >
          <i class="fas fa-undo"></i>
          <span>Restore Item</span>
        </button>
        <button 
          v-if="!item?.deleted" 
          @click="openEditModal" 
          class="px-6 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38] flex items-center gap-2 font-semibold"
        >
          <i class="fas fa-edit"></i>
          <span>Edit Item</span>
        </button>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="bg-white rounded-lg shadow-md p-12 text-center">
      <div class="loading-spinner w-12 h-12 border-4 border-gray-200 border-t-[#284b44] rounded-full animate-spin mx-auto mb-4"></div>
      <p class="text-gray-600">Loading item details...</p>
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="bg-white rounded-lg shadow-md p-6">
      <div class="text-center">
        <p class="text-red-600 mb-4">{{ error }}</p>
        <button @click="goBack" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
          ← Go Back
        </button>
      </div>
    </div>

    <!-- Item Details -->
    <div v-else-if="item">
      <!-- Item Details Card -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h2 class="text-xl font-bold text-gray-800 mb-4">Item Details</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <!-- Left Column -->
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Name</label>
              <p class="text-gray-900 font-medium">{{ item.name }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">SKU</label>
              <p class="text-gray-900 font-mono">{{ item.sku || 'N/A' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Minimum Level</label>
              <p class="text-gray-900">{{ item.min_level || '-' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Maximum Level</label>
              <p class="text-gray-900">{{ item.max_level || '-' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Ingredient Unit</label>
              <p class="text-gray-900">{{ item.ingredient_unit || 'N/A' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Costing Method</label>
              <p class="text-gray-900">{{ item.costing_method || 'From Transactions' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Total Cost of Production</label>
              <p class="text-gray-900 font-semibold">{{ item.cost ? `${item.cost} SAR` : '0 SAR' }}</p>
            </div>
          </div>
          
          <!-- Right Column -->
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Name Localized</label>
              <p class="text-gray-900 font-medium">{{ item.name_localized || item.name }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Barcode</label>
              <p class="text-gray-900">{{ item.barcode || '-' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Par Level</label>
              <p class="text-gray-900">{{ item.par_level || '-' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Storage Unit</label>
              <p class="text-gray-900">{{ item.storage_unit || 'N/A' }}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Factor</label>
              <p class="text-gray-900">
                {{ getFactorDisplay(item) }}
              </p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-600 mb-1">Category</label>
              <p class="text-gray-900">{{ item.category || 'Uncategorized' }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Tags Section -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <div class="flex justify-between items-center mb-3">
          <h3 class="text-lg font-semibold text-gray-800">Tags</h3>
          <button @click="openAddTagsModal" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
            Add Tags
          </button>
        </div>
        <p class="text-sm text-gray-600 text-center py-4">
          Add tags to help you filter and group items easily. You can create tags such as Weekly Stocktaking, Vegetables, etc.
        </p>
        <div class="flex flex-wrap gap-2 mt-4">
          <span 
            v-for="tag in itemTags" 
            :key="tag.id"
            class="inline-flex items-center gap-2 px-3 py-1 bg-[#284b44] bg-opacity-10 text-[#284b44] rounded-full text-sm"
          >
            {{ tag.name }}
            <button @click="removeTag(tag.id)" class="hover:text-[#1f3d38]">
              <i class="fas fa-times text-xs"></i>
            </button>
          </span>
          <span v-if="itemTags.length === 0" class="text-gray-400 text-sm">No tags added yet</span>
        </div>
      </div>

      <!-- Ingredients Section (Recipe / BOM) -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <div class="flex justify-between items-center mb-3">
          <h3 class="text-lg font-semibold text-gray-800">Ingredients (BOM)</h3>
          <div class="flex items-center gap-2">
            <a v-if="recipeForItem" :href="`#/homeportal/recipes/${recipeForItem.id}`" class="text-sm text-[#284b44] hover:underline">Open in Recipes</a>
            <button v-if="recipeForItem" @click="openAddIngredientsModal" class="px-4 py-2 text-white rounded-lg text-sm font-medium" style="background-color: #284b44;">
              <i class="fas fa-plus mr-1"></i> Add ingredient
            </button>
            <button v-else @click="ensureRecipeAndOpenAddModal" class="px-4 py-2 text-white rounded-lg text-sm font-medium" style="background-color: #284b44;">
              <i class="fas fa-plus mr-1"></i> Create recipe & add ingredients
            </button>
          </div>
        </div>
        <p class="text-sm text-gray-600 mb-4">
          <template v-if="recipeForItem">
            Ingredients needed to produce <strong>{{ recipeForItem.base_quantity ?? 1 }} {{ recipeForItem.base_unit || 'Pcs' }}</strong> of this item. You can set quantity, unit, and conversion factor per ingredient.
          </template>
          <template v-else>
            No recipe (BOM) for this item yet. Click &quot;Create recipe & add ingredients&quot; to define ingredients with quantity, unit, and unit conversion.
          </template>
        </p>
        <div v-if="ingredientsLoading" class="py-4 text-center text-gray-500">Loading ingredients...</div>
        <div v-else class="mt-4 border rounded-lg overflow-hidden">
          <table v-if="recipeForItem && itemIngredients.length > 0" class="w-full">
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
              <tr v-for="ing in itemIngredients" :key="ing.id">
                <td class="px-4 py-3 font-medium text-gray-900">{{ ing.itemName || ing.name }}</td>
                <td class="px-4 py-3 text-gray-700">{{ ing.quantity ?? ing.quantity_required }}</td>
                <td class="px-4 py-3 text-gray-600">{{ ing.unit || 'Pcs' }}</td>
                <td class="px-4 py-3 text-gray-600">{{ ing.conversion_factor ?? 1 }}</td>
                <td class="px-4 py-3 text-right">
                  <button @click="openEditIngredient(ing)" class="text-blue-600 hover:text-blue-800 mr-3 text-sm">Edit</button>
                  <button @click="removeIngredient(ing)" class="text-red-600 hover:text-red-800 text-sm">Delete</button>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-else class="p-4 text-center text-gray-500">
            {{ recipeForItem ? 'No ingredients yet. Add ingredients to define the BOM.' : 'Create a recipe above to add ingredients.' }}
          </p>
        </div>
      </div>

      <!-- Suppliers Section -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <div class="flex justify-between items-center mb-3">
          <h3 class="text-lg font-semibold text-gray-800">Suppliers</h3>
          <button @click="openLinkSuppliersModal" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
            Link Suppliers
          </button>
        </div>
        <p class="text-sm text-gray-600 text-center py-4">
          Link this item to the suppliers you purchase from, and you can assign different order units and cost to each supplier.
        </p>
        <div class="mt-4">
          <p v-if="itemSuppliers.length === 0" class="text-gray-400 text-sm text-center">No suppliers linked yet</p>
          <div v-else class="space-y-2">
            <div 
              v-for="supplier in itemSuppliers" 
              :key="supplier.id"
              class="flex justify-between items-center p-3 bg-gray-50 rounded-lg"
            >
              <div class="flex-1">
                <div class="font-medium text-gray-900">{{ supplier.name }}</div>
              </div>
              <button @click="removeSupplier(supplier.id)" class="text-red-600 hover:text-red-800 ml-3">
                <i class="fas fa-times"></i>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Custom Level Section -->
      <div class="bg-white rounded-lg shadow-md p-6">
        <div class="flex justify-between items-center mb-3">
          <h3 class="text-lg font-semibold text-gray-800">Custom Level</h3>
          <button @click="selectBranches" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
            Select Branches
          </button>
        </div>
        <p class="text-sm text-gray-600 text-center py-4">
          You can apply custom inventory levels to some branches instead of the default levels (such as high traffic branches) and specify the minimum and maximum levels for them.
        </p>
        <div class="mt-4">
          <p class="text-gray-400 text-sm text-center">No custom levels set</p>
        </div>
      </div>
    </div>

    <!-- Edit Item Modal -->
    <div 
      v-if="showEditModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeEditModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">Edit item</h2>
          <button @click="closeEditModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <form @submit.prevent="saveItem" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Name <span class="text-red-500">*</span>
            </label>
            <input 
              v-model="editForm.name" 
              type="text" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name Localized</label>
            <input 
              v-model="editForm.name_localized" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              SKU <span class="text-red-500">*</span>
            </label>
            <div class="flex gap-2">
              <input 
                v-model="editForm.sku" 
                type="text" 
                required 
                class="flex-1 px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
              <button type="button" @click="generateSKU" class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
                Generate
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Category</label>
            <select 
              v-model="editForm.category" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Choose...</option>
              <option v-for="cat in categories" :key="cat.id || cat.name" :value="cat.name">{{ cat.name }}</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Storage Unit <span class="text-red-500">*</span>
            </label>
            <input 
              v-model="editForm.storage_unit" 
              type="text" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Ingredient Unit <span class="text-red-500">*</span>
            </label>
            <input 
              v-model="editForm.ingredient_unit" 
              type="text" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Storage To Ingredient <span class="text-red-500">*</span>
            </label>
            <input 
              v-model.number="editForm.storage_to_ingredient" 
              type="number" 
              step="0.01" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Costing Method <span class="text-red-500">*</span>
            </label>
            <select 
              v-model="editForm.costing_method" 
              required 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="From Transactions">From Transactions</option>
              <option value="Manual">Manual</option>
              <option value="Average">Average</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Cost (Per Pcs)</label>
            <input 
              v-model.number="editForm.cost" 
              type="number" 
              step="0.01" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Barcode</label>
            <input 
              v-model="editForm.barcode" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Minimum Level</label>
            <input 
              v-model="editForm.min_level" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Maximum Level</label>
            <input 
              v-model="editForm.max_level" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Par Level</label>
            <input 
              v-model="editForm.par_level" 
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
          </div>

          <div class="flex justify-between items-center pt-4 border-t border-gray-200 mt-6">
            <div class="flex gap-4">
              <button 
                type="button" 
                @click="deleteItemFromModal" 
                class="text-red-600 hover:text-red-800"
              >
                Delete Item
              </button>
            </div>
            <div class="flex gap-3">
              <button 
                type="button" 
                @click="closeEditModal" 
                class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
              >
                Close
              </button>
              <button 
                type="button" 
                @click="saveItem"
                :disabled="saving"
                class="px-6 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1f3d38] disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <span v-if="saving">Saving...</span>
                <span v-else>Save</span>
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>

    <!-- Add Tags Modal -->
    <div 
      v-if="showAddTagsModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeAddTagsModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">Add tags</h2>
          <button @click="closeAddTagsModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Tags
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Select tags to link to this item"></i>
            </label>
            <select 
              v-model="selectedTagId" 
              @change="handleTagSelect"
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 mb-2"
            >
              <option value="">Choose...</option>
              <option v-for="tag in availableTags" :key="tag.id" :value="tag.id">{{ tag.name }}</option>
            </select>
            <input 
              v-model="tagSearchQuery"
              @input="loadAvailableTags"
              @focus="loadAvailableTags"
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" 
              placeholder="Type something to start searching"
            >
          </div>

          <!-- Tags Dropdown List -->
          <div class="border border-gray-300 rounded-lg max-h-64 overflow-y-auto bg-white">
            <div v-if="filteredTags.length === 0" class="p-4 text-center text-gray-500">
              {{ tagSearchQuery ? 'No tags found matching your search' : 'No tags available. Create tags from Manage > More > Tags' }}
            </div>
            <div 
              v-for="tag in filteredTags" 
              :key="tag.id"
              @click="toggleTagLink(tag.id)"
              :class="['p-3 hover:bg-gray-100 cursor-pointer flex justify-between items-center border-b border-gray-100', isTagLinked(tag.id) ? 'bg-[#284b44] bg-opacity-10' : '']"
            >
              <div class="flex-1">
                <div class="font-medium text-gray-900">{{ tag.name }}</div>
                <div v-if="tag.nameLocalized && tag.nameLocalized !== tag.name" class="text-sm text-gray-600">{{ tag.nameLocalized }}</div>
              </div>
              <i v-if="isTagLinked(tag.id)" class="fas fa-check text-[#284b44] ml-3"></i>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
          <button 
            type="button" 
            @click="closeAddTagsModal" 
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Close
          </button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Ingredient Modal (Recipe BOM style: quantity, unit, conversion) -->
    <div 
      v-if="showAddIngredientsModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeAddIngredientsModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-4">
          <h2 class="text-xl font-bold text-gray-800">{{ editingIngredient ? 'Edit ingredient' : 'Add ingredient' }}</h2>
          <button @click="closeAddIngredientsModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>
        <div class="space-y-4">
          <div v-if="!editingIngredient">
            <label class="block text-sm font-medium text-gray-700 mb-1">Ingredient item *</label>
            <p v-if="ingredientForm.ingredient_item_id" class="text-sm text-[#284b44] font-medium mb-2">Selected: {{ selectedIngredientItemName }}</p>
            <input
              v-model="ingredientSearch"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg mb-2"
              placeholder="Search by name or SKU..."
            />
            <div class="border rounded-lg max-h-48 overflow-y-auto">
              <div
                v-for="invItem in filteredInventoryItemsForRecipe"
                :key="invItem.id"
                @click="selectIngredientItem(invItem)"
                class="p-3 hover:bg-gray-100 cursor-pointer border-b border-gray-100 last:border-0"
              >
                <div class="font-medium text-gray-900">{{ invItem.name }}</div>
                <div v-if="invItem.sku" class="text-sm text-gray-600">SKU: {{ invItem.sku }}</div>
              </div>
              <div v-if="filteredInventoryItemsForRecipe.length === 0" class="p-4 text-center text-gray-500">No items match</div>
            </div>
          </div>
          <div v-else>
            <p class="text-gray-700"><strong>Item:</strong> {{ editingIngredient.itemName || editingIngredient.name }}</p>
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
        <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
          <button type="button" @click="closeAddIngredientsModal" class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">Cancel</button>
          <button type="button" @click="saveIngredient" class="px-6 py-2 rounded-lg text-white font-medium" style="background-color: #284b44;">{{ editingIngredient ? 'Update' : 'Add' }}</button>
        </div>
      </div>
    </div>

    <!-- Link Suppliers Modal -->
    <div 
      v-if="showLinkSuppliersModal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeLinkSuppliersModal"
    >
      <div class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-800">Link Suppliers</h2>
          <button @click="closeLinkSuppliersModal" class="text-gray-500 hover:text-gray-700 text-2xl">
            <i class="fas fa-times"></i>
          </button>
        </div>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Suppliers
              <i class="fas fa-info-circle text-gray-400 ml-1" title="Select suppliers to link to this item"></i>
            </label>
            <input 
              v-model="supplierSearchQuery"
              @input="loadAvailableSuppliers"
              @focus="loadAvailableSuppliers"
              type="text" 
              class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500" 
              placeholder="Type something to start searching"
            >
          </div>

          <!-- Suppliers List -->
          <div class="border border-gray-300 rounded-lg max-h-64 overflow-y-auto bg-white">
            <div v-if="filteredSuppliers.length === 0" class="p-4 text-center text-gray-500">
              {{ supplierSearchQuery ? 'No suppliers found matching your search' : 'No suppliers available' }}
            </div>
            <div 
              v-for="supplier in filteredSuppliers" 
              :key="supplier.id"
              @click="toggleSupplierLink(supplier.id)"
              :class="['p-3 hover:bg-gray-100 cursor-pointer flex justify-between items-center border-b border-gray-100', isSupplierLinked(supplier.id) ? 'bg-[#284b44] bg-opacity-10' : '']"
            >
              <div class="flex-1">
                <div class="font-medium text-gray-900">{{ supplier.name }}</div>
              </div>
              <i v-if="isSupplierLinked(supplier.id)" class="fas fa-check text-[#284b44] ml-3"></i>
            </div>
          </div>
        </div>

        <div class="flex justify-end gap-3 pt-4 border-t border-gray-200 mt-6">
          <button 
            type="button" 
            @click="closeLinkSuppliersModal" 
            class="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabaseClient, USE_SUPABASE } from '@/services/supabase';
import { inventoryService } from '@/services/inventory';
import {
  fetchRecipeByItemId,
  fetchRecipeIngredients,
  addRecipeIngredient,
  updateRecipeIngredient,
  deleteRecipeIngredient,
  createRecipe,
  fetchInventoryItemsForRecipe,
  COMMON_UNITS
} from '@/services/recipeService';

const props = defineProps({
  itemId: {
    type: String,
    default: null
  }
});

const route = useRoute();
const router = useRouter();

const item = ref(null);
const loading = ref(true);
const error = ref(null);
const saving = ref(false);
const itemTags = ref([]);
const itemIngredients = ref([]);
const itemSuppliers = ref([]);
const recipeForItem = ref(null);
const ingredientsLoading = ref(false);
const categories = ref([]);

// Modals
const showEditModal = ref(false);
const showAddTagsModal = ref(false);
const showAddIngredientsModal = ref(false);
const showLinkSuppliersModal = ref(false);

// Edit Form
const editForm = ref({
  name: '',
  name_localized: '',
  sku: '',
  category: '',
  storage_unit: '',
  ingredient_unit: '',
  storage_to_ingredient: 1,
  costing_method: 'From Transactions',
  cost: 0,
  barcode: '',
  min_level: '',
  max_level: '',
  par_level: ''
});

// Tags
const availableTags = ref([]);
const tagSearchQuery = ref('');
const selectedTagId = ref('');
const linkedTagIds = ref([]);

// Ingredients (Recipe/BOM)
const availableItems = ref([]);
const ingredientSearchQuery = ref('');
const selectedIngredientItemId = ref('');
const editingIngredient = ref(null);
const ingredientForm = ref({
  ingredient_item_id: '',
  quantity: 1,
  unit: 'Pcs',
  storage_unit: '',
  conversion_factor: 1
});
const inventoryItemsForRecipe = ref([]);
const ingredientSearch = ref('');

// Suppliers
const availableSuppliers = ref([]);
const supplierSearchQuery = ref('');
const linkedSupplierIds = ref([]);

// Language detection
const currentLanguage = ref(localStorage.getItem('portalLang') || 'en');

// Watch for language changes
watch(() => localStorage.getItem('portalLang'), (newLang) => {
  if (newLang) {
    currentLanguage.value = newLang;
  }
});

// Language change handlers
const handleLanguageMessage = (event) => {
  if (event.data && event.data.type === 'SET_LANGUAGE') {
    currentLanguage.value = event.data.lang || 'en';
  }
};

const handleStorageChange = (event) => {
  if (event.key === 'portalLang' && event.newValue) {
    currentLanguage.value = event.newValue;
  }
};

// Computed property for displaying item name based on current language
const displayItemName = computed(() => {
  if (!item.value) return 'Loading...';
  
  // If Arabic is selected, show localized name (Arabic), fallback to English name
  if (currentLanguage.value === 'ar') {
    return item.value.name_localized || item.value.name || 'Loading...';
  }
  
  // If English is selected, show English name (main name)
  return item.value.name || 'Loading...';
});

const getFactorDisplay = (item) => {
  const storageUnit = item.storage_unit || 'Pcs';
  const ingredientUnit = item.ingredient_unit || 'Pcs';
  const factor = item.storage_to_ingredient || 1;
  
  if (factor && factor !== '1' && factor !== 1) {
    return `1 ${storageUnit} = ${factor} ${ingredientUnit}`;
  } else {
    return `1 ${storageUnit} = 1 ${ingredientUnit}`;
  }
};

const filteredTags = computed(() => {
  if (!tagSearchQuery.value) return availableTags.value;
  const query = tagSearchQuery.value.toLowerCase();
  return availableTags.value.filter(tag => 
    tag.name.toLowerCase().includes(query) || 
    (tag.nameLocalized && tag.nameLocalized.toLowerCase().includes(query))
  );
});

const filteredItems = computed(() => {
  if (!ingredientSearchQuery.value) return availableItems.value;
  const query = ingredientSearchQuery.value.toLowerCase();
  return availableItems.value.filter(item => {
    const name = (item.name || item.nameLocalized || '').toLowerCase();
    const sku = (item.sku || '').toLowerCase();
    return name.includes(query) || sku.includes(query);
  });
});

const filteredSuppliers = computed(() => {
  if (!supplierSearchQuery.value) return availableSuppliers.value;
  const query = supplierSearchQuery.value.toLowerCase();
  return availableSuppliers.value.filter(supplier => 
    supplier.name.toLowerCase().includes(query)
  );
});

const selectedIngredientItemName = computed(() => {
  if (!ingredientForm.value.ingredient_item_id) return '';
  const item = inventoryItemsForRecipe.value.find((i) => i.id === ingredientForm.value.ingredient_item_id);
  return item ? (item.name || item.sku || item.id) : '';
});

const filteredInventoryItemsForRecipe = computed(() => {
  const q = (ingredientSearch.value || '').toLowerCase();
  const itemId = props.itemId || route.params.id;
  let list = inventoryItemsForRecipe.value.filter((i) => i.id !== itemId);
  const existingIds = itemIngredients.value.map((ing) => ing.ingredient_item_id || ing.item_id).filter(Boolean);
  list = list.filter((i) => !existingIds.includes(i.id));
  if (!q) return list.slice(0, 50);
  return list.filter(
    (i) =>
      (i.name && i.name.toLowerCase().includes(q)) ||
      (i.sku && i.sku.toLowerCase().includes(q))
  ).slice(0, 50);
});

const loadItem = async () => {
  const itemId = props.itemId || route.params.id;
  
  if (!itemId) {
    error.value = 'No item ID provided';
    loading.value = false;
    return;
  }

  loading.value = true;
  error.value = null;

  try {
    if (USE_SUPABASE && supabaseClient) {
      const { data, error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .select('*')
        .eq('id', itemId)
        .single();

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to load item');
      }

      if (!data) {
        throw new Error('Item not found');
      }

      item.value = data;
      
      // Load related data (including recipe/BOM for this item)
      await loadItemTags();
      await loadRecipeAndIngredients();
      await loadItemSuppliers();
      
    } else {
      // Fallback to API
      const response = await inventoryService.getItemById(itemId);
      item.value = response.data;
      await loadItemTags();
      await loadRecipeAndIngredients();
      await loadItemSuppliers();
    }
  } catch (err) {
    console.error('Error loading item:', err);
    error.value = err.message || 'Failed to load item';
  } finally {
    loading.value = false;
  }
};

const loadItemTags = async () => {
  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    // Load tags from localStorage (for now, can be migrated to Supabase later)
    const allTags = JSON.parse(localStorage.getItem('inventory_item_tags') || '[]');
    
    // Get item's tags from Supabase or localStorage
    if (USE_SUPABASE && supabaseClient && item.value) {
      const tags = item.value.tags || [];
      linkedTagIds.value = tags;
      itemTags.value = allTags.filter(tag => tags.includes(tag.id));
    } else {
      // Fallback to localStorage
      const items = JSON.parse(localStorage.getItem('inventory_items') || '[]');
      const currentItem = items.find(i => i.id === itemId);
      if (currentItem && currentItem.tags) {
        linkedTagIds.value = currentItem.tags;
        itemTags.value = allTags.filter(tag => currentItem.tags.includes(tag.id));
      }
    }
  } catch (err) {
    console.error('Error loading item tags:', err);
  }
};

/** Load recipe for this item (FG) and its ingredients from recipe_ingredients (BOM). */
const loadRecipeAndIngredients = async () => {
  const itemId = props.itemId || route.params.id;
  if (!itemId || !item.value) return;

  if (!USE_SUPABASE || !supabaseClient) {
    itemIngredients.value = item.value.ingredients || [];
    return;
  }

  ingredientsLoading.value = true;
  try {
    const recipe = await fetchRecipeByItemId(itemId);
    recipeForItem.value = recipe;
    if (recipe) {
      const ings = await fetchRecipeIngredients(recipe.id);
      itemIngredients.value = ings || [];
    } else {
      itemIngredients.value = [];
    }
  } catch (err) {
    console.error('Error loading recipe/ingredients:', err);
    recipeForItem.value = null;
    itemIngredients.value = item.value.ingredients || [];
  } finally {
    ingredientsLoading.value = false;
  }
};

const loadItemIngredients = async () => {
  await loadRecipeAndIngredients();
};

const loadItemSuppliers = async () => {
  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    if (USE_SUPABASE && supabaseClient && item.value) {
      const suppliers = item.value.suppliers || [];
      linkedSupplierIds.value = suppliers.map(s => s.id || s);
      
      // Load supplier details
      if (suppliers.length > 0) {
        const { data } = await supabaseClient
          .from('suppliers')
          .select('*')
          .in('id', linkedSupplierIds.value);
        
        if (data) {
          itemSuppliers.value = data;
        }
      }
    } else {
      // Fallback to localStorage
      const items = JSON.parse(localStorage.getItem('inventory_items') || '[]');
      const currentItem = items.find(i => i.id === itemId);
      if (currentItem && currentItem.suppliers) {
        linkedSupplierIds.value = currentItem.suppliers;
        // Load supplier details from localStorage
        const allSuppliers = JSON.parse(localStorage.getItem('suppliers') || '[]');
        itemSuppliers.value = allSuppliers.filter(s => currentItem.suppliers.includes(s.id));
      }
    }
  } catch (err) {
    console.error('Error loading item suppliers:', err);
  }
};

const loadCategories = async () => {
  try {
    if (USE_SUPABASE && supabaseClient) {
      const { data } = await supabaseClient
        .from('inventory_categories')
        .select('*')
        .eq('deleted', false)
        .order('name', { ascending: true });
      
      if (data) {
        categories.value = data;
      }
    } else {
      const response = await inventoryService.getCategories(false);
      categories.value = response.data || [];
    }
  } catch (err) {
    console.error('Error loading categories:', err);
  }
};

const goBack = () => {
  // Navigate back using HomePortal's loadDashboard to keep sidebar visible
  if (window.parent && window.parent.loadDashboard) {
    window.parent.loadDashboard('inventory-items');
  } else if (window.loadDashboard) {
    window.loadDashboard('inventory-items');
  } else {
    router.push('/homeportal');
  }
};

const openEditModal = async () => {
  if (!item.value) return;
  
  // Populate edit form
  editForm.value = {
    name: item.value.name || '',
    name_localized: item.value.name_localized || item.value.name || '',
    sku: item.value.sku || '',
    category: item.value.category || '',
    storage_unit: item.value.storage_unit || '',
    ingredient_unit: item.value.ingredient_unit || '',
    storage_to_ingredient: item.value.storage_to_ingredient || 1,
    costing_method: item.value.costing_method || 'From Transactions',
    cost: item.value.cost || 0,
    barcode: item.value.barcode || '',
    min_level: item.value.min_level || '',
    max_level: item.value.max_level || '',
    par_level: item.value.par_level || ''
  };
  
  await loadCategories();
  showEditModal.value = true;
};

const closeEditModal = () => {
  showEditModal.value = false;
};

const generateSKU = async () => {
  try {
    const response = await inventoryService.getItems();
    const items = response.data?.items || response.data || [];
    let maxSKUNumber = 19587;
    
    items.forEach(item => {
      if (item.sku) {
        const match = item.sku.match(/sk-(\d+)/);
        if (match) {
          const num = parseInt(match[1]);
          if (num > maxSKUNumber) {
            maxSKUNumber = num;
          }
        }
      }
    });
    
    editForm.value.sku = `sk-${maxSKUNumber + 1}`;
  } catch (error) {
    console.error('Error generating SKU:', error);
  }
};

const saveItem = async () => {
  const itemId = props.itemId || route.params.id;
  if (!itemId) {
    showNotification('No item ID found', 'error');
    return;
  }

  // Validate required fields
  if (!editForm.value.name || !editForm.value.name.trim()) {
    showNotification('Name is required', 'warning');
    return;
  }

  if (!editForm.value.sku || !editForm.value.sku.trim()) {
    showNotification('SKU is required', 'warning');
    return;
  }

  if (!editForm.value.storage_unit || !editForm.value.storage_unit.trim()) {
    showNotification('Storage Unit is required', 'warning');
    return;
  }

  if (!editForm.value.ingredient_unit || !editForm.value.ingredient_unit.trim()) {
    showNotification('Ingredient Unit is required', 'warning');
    return;
  }

  saving.value = true;

  try {
    if (USE_SUPABASE && supabaseClient) {
      const updateData = {
        name: editForm.value.name.trim(),
        name_localized: (editForm.value.name_localized || editForm.value.name || '').trim(),
        sku: editForm.value.sku.trim(),
        category: (editForm.value.category || '').trim() || null,
        storage_unit: editForm.value.storage_unit.trim(),
        ingredient_unit: editForm.value.ingredient_unit.trim(),
        storage_to_ingredient: editForm.value.storage_to_ingredient || 1,
        costing_method: editForm.value.costing_method || 'From Transactions',
        cost: editForm.value.cost || 0,
        barcode: (editForm.value.barcode || '').trim() || null,
        min_level: (editForm.value.min_level || '').trim() || null,
        max_level: (editForm.value.max_level || '').trim() || null,
        par_level: (editForm.value.par_level || '').trim() || null,
        updated_at: new Date().toISOString()
      };

      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update(updateData)
        .eq('id', itemId);

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to save item');
      }

      showNotification('Item saved successfully!', 'success');
      await loadItem();
      closeEditModal();
    } else {
      // Fallback to API
      await inventoryService.updateItem(itemId, editForm.value);
      showNotification('Item saved successfully!', 'success');
      await loadItem();
      closeEditModal();
    }
  } catch (err) {
    console.error('Error saving item:', err);
    showNotification(err.message || 'Error saving item', 'error');
  } finally {
    saving.value = false;
  }
};

const deleteItemFromModal = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Delete Item',
    message: 'Are you sure you want to delete this item? This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    type: 'danger',
    icon: 'fas fa-trash'
  });

  if (!confirmed) return;

  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    if (USE_SUPABASE && supabaseClient) {
      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update({
          deleted: true,
          deleted_at: new Date().toISOString()
        })
        .eq('id', itemId);

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to delete item');
      }

      showNotification('Item deleted successfully!', 'success');
      closeEditModal();
      setTimeout(() => {
        goBack();
      }, 1500);
    } else {
      await inventoryService.deleteItem(itemId);
      showNotification('Item deleted successfully!', 'success');
      closeEditModal();
      setTimeout(() => {
        goBack();
      }, 1500);
    }
  } catch (err) {
    console.error('Error deleting item:', err);
    showNotification(err.message || 'Error deleting item', 'error');
  }
};

const restoreItem = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Restore Item',
    message: 'Are you sure you want to restore this item?',
    confirmText: 'Restore',
    cancelText: 'Cancel',
    type: 'confirm',
    icon: 'fas fa-undo'
  });

  if (!confirmed) return;

  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    if (USE_SUPABASE && supabaseClient) {
      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update({
          deleted: false,
          deleted_at: null
        })
        .eq('id', itemId);

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to restore item');
      }

      showNotification('Item restored successfully!', 'success');
      await loadItem();
      setTimeout(() => {
        goBack();
      }, 1500);
    } else {
      await inventoryService.restoreItem(itemId);
      showNotification('Item restored successfully!', 'success');
      await loadItem();
      setTimeout(() => {
        goBack();
      }, 1500);
    }
  } catch (err) {
    console.error('Error restoring item:', err);
    showNotification(err.message || 'Error restoring item', 'error');
  }
};

const openAddTagsModal = () => {
  loadAvailableTags();
  showAddTagsModal.value = true;
};

const closeAddTagsModal = () => {
  showAddTagsModal.value = false;
  tagSearchQuery.value = '';
  selectedTagId.value = '';
};

const loadAvailableTags = () => {
  try {
    const tags = JSON.parse(localStorage.getItem('inventory_item_tags') || '[]');
    availableTags.value = tags;
  } catch (err) {
    console.error('Error loading tags:', err);
    availableTags.value = [];
  }
};

const handleTagSelect = () => {
  if (selectedTagId.value) {
    toggleTagLink(selectedTagId.value);
    selectedTagId.value = '';
  }
};

const isTagLinked = (tagId) => {
  return linkedTagIds.value.includes(tagId);
};

const toggleTagLink = async (tagId) => {
  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    const isLinked = linkedTagIds.value.includes(tagId);
    
    if (USE_SUPABASE && supabaseClient) {
      let tags = item.value.tags || [];
      
      if (isLinked) {
        tags = tags.filter(id => id !== tagId);
      } else {
        if (!tags.includes(tagId)) {
          tags.push(tagId);
        }
      }

      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update({ tags })
        .eq('id', itemId);

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to update tags');
      }

      linkedTagIds.value = tags;
      await loadItemTags();
    } else {
      // Fallback to localStorage
      const items = JSON.parse(localStorage.getItem('inventory_items') || '[]');
      const currentItem = items.find(i => i.id === itemId);
      if (currentItem) {
        if (!currentItem.tags) currentItem.tags = [];
        const index = currentItem.tags.indexOf(tagId);
        if (index > -1) {
          currentItem.tags.splice(index, 1);
        } else {
          currentItem.tags.push(tagId);
        }
        const itemIndex = items.findIndex(i => i.id === itemId);
        items[itemIndex] = currentItem;
        localStorage.setItem('inventory_items', JSON.stringify(items));
        await loadItemTags();
      }
    }
  } catch (err) {
    console.error('Error toggling tag link:', err);
    showNotification(err.message || 'Error updating tags', 'error');
  }
};

const removeTag = async (tagId) => {
  await toggleTagLink(tagId);
};

const ensureRecipeAndOpenAddModal = async () => {
  const itemId = props.itemId || route.params.id;
  if (!itemId || !item.value) return;
  try {
    if (!recipeForItem.value) {
      const name = item.value.name || item.value.name_localized || 'Recipe';
      const created = await createRecipe({
        name: `${name} (BOM)`,
        item_id: itemId,
        output_item_id: itemId,
        base_quantity: 1,
        base_unit: item.value.ingredient_unit || item.value.storage_unit || 'Pcs',
        status: 'draft'
      });
      recipeForItem.value = created;
      await loadRecipeAndIngredients();
    }
    openAddIngredientsModal();
  } catch (err) {
    console.error('Error creating recipe:', err);
    showNotification(err.message || 'Failed to create recipe', 'error');
  }
};

const openAddIngredientsModal = async () => {
  if (!recipeForItem.value) return;
  editingIngredient.value = null;
  ingredientForm.value = { ingredient_item_id: '', quantity: 1, unit: 'Pcs', storage_unit: '', conversion_factor: 1 };
  ingredientSearch.value = '';
  try {
    const items = await fetchInventoryItemsForRecipe();
    const existingIds = itemIngredients.value.map((i) => i.ingredient_item_id || i.item_id).filter(Boolean);
    inventoryItemsForRecipe.value = (items || []).filter((i) => !existingIds.includes(i.id));
  } catch (err) {
    inventoryItemsForRecipe.value = [];
  }
  showAddIngredientsModal.value = true;
};

const closeAddIngredientsModal = () => {
  showAddIngredientsModal.value = false;
  ingredientSearchQuery.value = '';
  selectedIngredientItemId.value = '';
  editingIngredient.value = null;
  ingredientSearch.value = '';
};

const openEditIngredient = (ing) => {
  editingIngredient.value = ing;
  ingredientForm.value = {
    ingredient_item_id: ing.ingredient_item_id || ing.item_id,
    quantity: ing.quantity ?? ing.quantity_required ?? 1,
    unit: ing.unit || 'Pcs',
    storage_unit: ing.storage_unit || '',
    conversion_factor: ing.conversion_factor ?? 1
  };
  inventoryItemsForRecipe.value = [];
  showAddIngredientsModal.value = true;
};

const selectIngredientItem = (invItem) => {
  ingredientForm.value.ingredient_item_id = invItem.id;
  ingredientSearch.value = invItem.name || invItem.sku || '';
};

const saveIngredient = async () => {
  if (!recipeForItem.value) return;
  try {
    if (editingIngredient.value) {
      await updateRecipeIngredient(editingIngredient.value.id, {
        quantity: ingredientForm.value.quantity,
        unit: ingredientForm.value.unit,
        storage_unit: ingredientForm.value.storage_unit || null,
        conversion_factor: ingredientForm.value.conversion_factor ?? 1
      });
      showNotification('Ingredient updated.', 'success');
    } else {
      if (!ingredientForm.value.ingredient_item_id) {
        showNotification('Select an ingredient item', 'warning');
        return;
      }
      await addRecipeIngredient(recipeForItem.value.id, {
        ingredient_item_id: ingredientForm.value.ingredient_item_id,
        quantity: ingredientForm.value.quantity,
        unit: ingredientForm.value.unit,
        storage_unit: ingredientForm.value.storage_unit || null,
        conversion_factor: ingredientForm.value.conversion_factor ?? 1
      });
      showNotification('Ingredient added.', 'success');
    }
    await loadRecipeAndIngredients();
    closeAddIngredientsModal();
  } catch (err) {
    console.error('Error saving ingredient:', err);
    showNotification(err.message || 'Failed to save ingredient', 'error');
  }
};

const removeIngredient = async (ing) => {
  if (recipeForItem.value && ing.id) {
    if (!confirm('Remove this ingredient from the recipe (BOM)?')) return;
    try {
      await deleteRecipeIngredient(ing.id);
      await loadRecipeAndIngredients();
      showNotification('Ingredient removed.', 'success');
    } catch (err) {
      showNotification(err.message || 'Failed to remove ingredient', 'error');
    }
    return;
  }
  const ingredientItemId = ing.itemId || ing.id;
  const itemId = props.itemId || route.params.id;
  if (!itemId) return;
  try {
    if (USE_SUPABASE && supabaseClient) {
      let ingredients = item.value.ingredients || [];
      ingredients = ingredients.filter((i) => (i.itemId || i.id) !== ingredientItemId);
      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update({ ingredients })
        .eq('id', itemId);
      if (supabaseError) throw new Error(supabaseError.message);
      await loadRecipeAndIngredients();
      showNotification('Ingredient removed.', 'success');
    }
  } catch (err) {
    showNotification(err.message || 'Error removing ingredient', 'error');
  }
};

const openLinkSuppliersModal = async () => {
  await loadAvailableSuppliers();
  showLinkSuppliersModal.value = true;
};

const closeLinkSuppliersModal = () => {
  showLinkSuppliersModal.value = false;
  supplierSearchQuery.value = '';
};

const loadAvailableSuppliers = async () => {
  try {
    if (USE_SUPABASE && supabaseClient) {
      const { data } = await supabaseClient
        .from('suppliers')
        .select('*')
        .eq('deleted', false)
        .order('name', { ascending: true });
      
      if (data) {
        availableSuppliers.value = data;
      }
    } else {
      // Fallback to localStorage
      const suppliers = JSON.parse(localStorage.getItem('suppliers') || '[]');
      availableSuppliers.value = suppliers.filter(s => !s.deleted);
    }
  } catch (err) {
    console.error('Error loading suppliers:', err);
    availableSuppliers.value = [];
  }
};

const isSupplierLinked = (supplierId) => {
  return linkedSupplierIds.value.includes(supplierId);
};

const toggleSupplierLink = async (supplierId) => {
  const itemId = props.itemId || route.params.id;
  if (!itemId) return;

  try {
    const isLinked = linkedSupplierIds.value.includes(supplierId);
    
    if (USE_SUPABASE && supabaseClient) {
      let suppliers = item.value.suppliers || [];
      
      if (isLinked) {
        suppliers = suppliers.filter(id => (typeof id === 'object' ? id.id : id) !== supplierId);
      } else {
        if (!suppliers.some(s => (typeof s === 'object' ? s.id : s) === supplierId)) {
          suppliers.push(supplierId);
        }
      }

      const { error: supabaseError } = await supabaseClient
        .from('inventory_items')
        .update({ suppliers })
        .eq('id', itemId);

      if (supabaseError) {
        throw new Error(supabaseError.message || 'Failed to update suppliers');
      }

      linkedSupplierIds.value = suppliers.map(s => typeof s === 'object' ? s.id : s);
      await loadItemSuppliers();
    } else {
      // Fallback to localStorage
      const items = JSON.parse(localStorage.getItem('inventory_items') || '[]');
      const currentItem = items.find(i => i.id === itemId);
      if (currentItem) {
        if (!currentItem.suppliers) currentItem.suppliers = [];
        const index = currentItem.suppliers.indexOf(supplierId);
        if (index > -1) {
          currentItem.suppliers.splice(index, 1);
        } else {
          currentItem.suppliers.push(supplierId);
        }
        const itemIndex = items.findIndex(i => i.id === itemId);
        items[itemIndex] = currentItem;
        localStorage.setItem('inventory_items', JSON.stringify(items));
        await loadItemSuppliers();
      }
    }
  } catch (err) {
    console.error('Error toggling supplier link:', err);
    showNotification(err.message || 'Error updating suppliers', 'error');
  }
};

const removeSupplier = async (supplierId) => {
  await toggleSupplierLink(supplierId);
};

const selectBranches = () => {
  showNotification('Select branches functionality - To be implemented', 'info');
};

const showNotification = (message, type = 'info') => {
  if (window.showNotification) {
    window.showNotification(message, type);
  } else {
    console.log(`[${type.toUpperCase()}] ${message}`);
  }
};

// Watch for itemId prop changes
watch(() => props.itemId, (newId) => {
  if (newId) {
    loadItem();
  }
});

onMounted(() => {
  // Listen for language change messages
  window.addEventListener('message', handleLanguageMessage);
  
  // Listen for storage changes (language changes in other tabs)
  window.addEventListener('storage', handleStorageChange);
  
  loadItem();
});

onUnmounted(() => {
  // Clean up event listeners
  window.removeEventListener('message', handleLanguageMessage);
  window.removeEventListener('storage', handleStorageChange);
});
</script>

<style scoped>
.loading-spinner {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
