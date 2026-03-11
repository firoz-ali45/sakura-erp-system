/**
 * Enterprise Recipe / BOM — recipes, recipe_ingredients, unit_conversions.
 * Supports versioning, edit protection, and consumption = ingredient_qty × production_qty.
 */
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase';
import { dbInsert, getCurrentCompanyId } from '@/services/db';
import { getCurrentUserUUID } from '@/utils/uuidUtils';

const FALLBACK_COMPANY_UUID = '00000000-0000-0000-0000-000000000000';

/** Common units for dropdowns */
export const COMMON_UNITS = ['Pcs', 'Gram', 'KG', 'ML', 'L', 'Liter', 'Unit', 'Box', 'Carton'];

export async function fetchRecipes() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('v_recipes_bom')
    .select('*')
    .order('updated_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function fetchRecipeById(id) {
  await ensureSupabaseReady();
  if (!supabaseClient) return null;
  const { data, error } = await supabaseClient
    .from('v_recipes_bom')
    .select('*')
    .eq('id', id)
    .single();
  if (error) throw error;
  return data;
}

/** Get the recipe for an inventory item (FG). Prefers active, then highest version. */
export async function fetchRecipeByItemId(itemId) {
  await ensureSupabaseReady();
  if (!supabaseClient || !itemId) return null;
  const { data, error } = await supabaseClient
    .from('v_recipes_bom')
    .select('*')
    .or(`item_id.eq.${itemId},output_item_id.eq.${itemId}`)
    .order('recipe_version', { ascending: false });
  if (error) throw error;
  const list = data || [];
  const active = list.find((r) => r.status === 'active');
  return active || list[0] || null;
}

export async function fetchRecipeIngredients(recipeId) {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('recipe_ingredients')
    .select('*, inventory_items(name, sku, storage_unit)')
    .eq('recipe_id', recipeId)
    .order('created_at');
  if (error) throw error;
  return (data || []).map((row) => ({
    ...row,
    ingredient_item_id: row.ingredient_item_id || row.item_id,
    quantity: row.quantity ?? row.quantity_required,
    itemName: row.inventory_items?.name,
    sku: row.inventory_items?.sku,
    storage_unit: row.storage_unit ?? row.inventory_items?.storage_unit
  }));
}

export async function fetchUnitConversions() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('unit_conversions')
    .select('*');
  if (error) throw error;
  return data || [];
}

/**
 * Convert quantity from fromUnit to toUnit using unit_conversions.
 * Returns converted qty or original if no conversion / same unit.
 */
export function convertQuantity(qty, fromUnit, toUnit, conversions = []) {
  if (qty == null || Number.isNaN(Number(qty))) return 0;
  const n = Number(qty);
  const f = (fromUnit || '').trim();
  const t = (toUnit || '').trim();
  if (!f || !t || f === t) return n;
  const row = conversions.find(
    (c) => c.from_unit === f && c.to_unit === t
  );
  if (row && row.conversion_factor != null) return n * Number(row.conversion_factor);
  const reverse = conversions.find(
    (c) => c.from_unit === t && c.to_unit === f
  );
  if (reverse && reverse.conversion_factor != null) return n / Number(reverse.conversion_factor);
  return n;
}

/** Check if recipe is used in any production (for edit warning) */
export async function checkRecipeUsedInProduction(recipeId) {
  await ensureSupabaseReady();
  if (!supabaseClient) return false;
  const { count, error } = await supabaseClient
    .from('production_orders')
    .select('*', { count: 'exact', head: true })
    .eq('recipe_id', recipeId);
  if (error) throw error;
  return (count || 0) > 0;
}

export async function createRecipe(payload) {
  await ensureSupabaseReady();
  const companyId = getCurrentCompanyId();
  const tenantId = (companyId && companyId !== FALLBACK_COMPANY_UUID) ? companyId : null;
  const createdBy = getCurrentUserUUID();
  const itemId = payload.item_id || payload.output_item_id;
  const row = await dbInsert(supabaseClient, 'recipes', {
    code: payload.code || `RCP-${Date.now()}`,
    name: payload.name || 'Unnamed Recipe',
    output_item_id: itemId,
    item_id: itemId,
    output_qty_per_batch: payload.base_quantity ?? payload.output_qty_per_batch ?? 1,
    base_quantity: payload.base_quantity ?? 1,
    base_unit: payload.base_unit || 'Pcs',
    recipe_version: payload.recipe_version ?? 1,
    status: payload.status || 'draft',
    company_id: companyId,
    tenant_id: tenantId,
    created_by: createdBy
  });
  return row;
}

export async function updateRecipe(recipeId, payload) {
  await ensureSupabaseReady();
  if (!supabaseClient) throw new Error('Supabase not ready');
  const updates = {};
  if (payload.name != null) updates.name = payload.name;
  if (payload.base_quantity != null) updates.base_quantity = payload.base_quantity;
  if (payload.base_unit != null) updates.base_unit = payload.base_unit;
  if (payload.status != null) updates.status = payload.status;
  if (payload.output_qty_per_batch != null) updates.output_qty_per_batch = payload.output_qty_per_batch;
  updates.updated_at = new Date().toISOString();
  const { data, error } = await supabaseClient
    .from('recipes')
    .update(updates)
    .eq('id', recipeId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

/** Create new recipe version (copy recipe and ingredients, increment version) */
export async function createRecipeVersion(recipeId) {
  const recipe = await fetchRecipeById(recipeId);
  if (!recipe) throw new Error('Recipe not found');
  const ingredients = await fetchRecipeIngredients(recipeId);
  const nextVersion = (recipe.recipe_version || 1) + 1;
  const newRecipe = await createRecipe({
    code: `${recipe.code}-v${nextVersion}`,
    name: recipe.name,
    item_id: recipe.item_id || recipe.output_item_id,
    output_item_id: recipe.output_item_id,
    base_quantity: recipe.base_quantity,
    base_unit: recipe.base_unit,
    recipe_version: nextVersion,
    status: 'draft'
  });
  for (const ing of ingredients) {
    await addRecipeIngredient(newRecipe.id, {
      ingredient_item_id: ing.ingredient_item_id || ing.item_id,
      quantity: ing.quantity ?? ing.quantity_required,
      unit: ing.unit || 'Pcs',
      storage_unit: ing.storage_unit,
      conversion_factor: ing.conversion_factor ?? 1
    });
  }
  return newRecipe;
}

export async function addRecipeIngredient(recipeId, payload) {
  await ensureSupabaseReady();
  const row = await dbInsert(supabaseClient, 'recipe_ingredients', {
    recipe_id: recipeId,
    item_id: payload.ingredient_item_id || payload.item_id,
    ingredient_item_id: payload.ingredient_item_id || payload.item_id,
    quantity_required: payload.quantity ?? 1,
    quantity: payload.quantity ?? 1,
    unit: payload.unit || 'Pcs',
    storage_unit: payload.storage_unit ?? null,
    conversion_factor: payload.conversion_factor ?? 1
  });
  return row;
}

export async function updateRecipeIngredient(ingredientId, payload) {
  await ensureSupabaseReady();
  if (!supabaseClient) throw new Error('Supabase not ready');
  const updates = {};
  if (payload.quantity != null) {
    updates.quantity = payload.quantity;
    updates.quantity_required = payload.quantity;
  }
  if (payload.unit != null) updates.unit = payload.unit;
  if (payload.storage_unit != null) updates.storage_unit = payload.storage_unit;
  if (payload.conversion_factor != null) updates.conversion_factor = payload.conversion_factor;
  const { data, error } = await supabaseClient
    .from('recipe_ingredients')
    .update(updates)
    .eq('id', ingredientId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function deleteRecipeIngredient(ingredientId) {
  await ensureSupabaseReady();
  if (!supabaseClient) throw new Error('Supabase not ready');
  const { error } = await supabaseClient
    .from('recipe_ingredients')
    .delete()
    .eq('id', ingredientId);
  if (error) throw error;
}

export async function fetchInventoryItemsForRecipe() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('inventory_items')
    .select('id, name, sku, storage_unit')
    .order('name');
  if (error) throw error;
  return data || [];
}
