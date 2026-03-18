/**
 * Enterprise Manufacturing Module — Production Orders, Items, Consumption, FG Batches.
 * Uses Supabase + db.js for inserts; RPC for execute.
 * When recipe exists, consumption is auto-calculated from BOM on execute.
 */
import { ensureSupabaseReady, supabaseClient } from '@/services/supabase';
import { dbInsert, getCurrentCompanyId } from '@/services/db';
import { getCurrentUserUUID } from '@/utils/uuidUtils';
import { fetchRecipeByItemId, fetchRecipeIngredients } from '@/services/recipeService';

const FALLBACK_COMPANY_UUID = '00000000-0000-0000-0000-000000000000';

export async function fetchProductionOrdersList() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('v_production_orders_full')
    .select('*')
    .order('created_at', { ascending: false });
  if (error) throw error;
  return data || [];
}

export async function fetchProductionOrderById(id) {
  await ensureSupabaseReady();
  if (!supabaseClient) return null;
  const { data: order, error: orderError } = await supabaseClient
    .from('production_orders')
    .select('*')
    .eq('id', id)
    .single();
  if (orderError) throw orderError;
  if (!order) return null;

  const [itemsRes, consumptionRes, fgRes] = await Promise.all([
    supabaseClient.from('production_items').select('*, inventory_items(name, sku, storage_unit)').eq('production_id', id),
    supabaseClient.from('production_consumption').select('*, inventory_items(name, sku), batches(batch_number)').eq('production_id', id),
    supabaseClient.from('fg_batches').select('*, inventory_items(name, sku), batches(batch_number)').eq('production_id', id)
  ]);

  return {
    ...order,
    items: itemsRes.data || [],
    consumption: consumptionRes.data || [],
    fg_batches: fgRes.data || []
  };
}

export async function getNextProductionNumber() {
  await ensureSupabaseReady();
  if (!supabaseClient) return 'PRD-' + new Date().getFullYear() + '-000001';
  const companyId = getCurrentCompanyId();
  const { data, error } = await supabaseClient.rpc('fn_next_production_number', { p_tenant_id: companyId });
  if (error) return 'PRD-' + new Date().getFullYear() + '-' + String(Date.now()).slice(-6);
  return data || 'PRD-' + new Date().getFullYear() + '-000001';
}

export async function createProductionOrder(payload) {
  await ensureSupabaseReady();
  const companyId = getCurrentCompanyId();
  const createdBy = getCurrentUserUUID();
  const productionNumber = payload.production_number || 'Draft-' + (typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : Date.now() + '-' + Math.random().toString(36).slice(2, 9));
  const tenantId = (companyId && companyId !== FALLBACK_COMPANY_UUID) ? companyId : null;
  const row = await dbInsert(supabaseClient, 'production_orders', {
    production_number: productionNumber,
    branch_id: payload.branch_id,
    recipe_id: payload.recipe_id || null,
    planned_qty: payload.planned_qty ?? 0,
    produced_qty: 0,
    status: 'draft',
    production_date: payload.production_date || null,
    company_id: companyId,
    tenant_id: tenantId,
    created_by: createdBy
  });
  return row;
}

export async function addProductionItem(productionId, payload) {
  await ensureSupabaseReady();
  const row = await dbInsert(supabaseClient, 'production_items', {
    production_id: productionId,
    item_id: payload.item_id,
    recipe_id: payload.recipe_id || null,
    quantity_planned: payload.quantity_planned ?? 0,
    quantity_produced: 0
  });
  return row;
}

export async function updateProductionItem(itemId, updates) {
  await ensureSupabaseReady();
  if (!supabaseClient) throw new Error('Supabase not ready');
  const { data, error } = await supabaseClient
    .from('production_items')
    .update(updates)
    .eq('id', itemId)
    .select()
    .single();
  if (error) throw error;
  return data;
}

export async function addProductionConsumption(productionId, payload) {
  await ensureSupabaseReady();
  const companyId = getCurrentCompanyId();
  const row = await dbInsert(supabaseClient, 'production_consumption', {
    production_id: productionId,
    production_item_id: payload.production_item_id || null,
    item_id: payload.item_id,
    batch_id: payload.batch_id,
    quantity: payload.quantity ?? 0,
    cost: payload.cost ?? 0,
    company_id: companyId,
    tenant_id: companyId
  });
  return row;
}

/**
 * Preview what will be consumed when producing.
 * Always fetches recipe by item_id (production linked to recipes table).
 * required_qty = ingredient.quantity × (production_quantity / recipe.base_quantity).
 * Returns { rmLines, fgLines, allItemsCovered, totalFgQty }.
 */
export async function getProductionConsumptionPreview(order) {
  await ensureSupabaseReady();
  if (!order?.items?.length) return { rmLines: [], fgLines: [], allItemsCovered: false, totalFgQty: 0 };
  const rmLines = [];
  let totalFgQty = 0;
  const fgLines = order.items.map((pi) => {
    const q = Number(pi.quantity_planned) || 0;
    totalFgQty += q;
    return {
      item_name: pi.inventory_items?.name || pi.item_id,
      sku: pi.inventory_items?.sku || '',
      unit: pi.inventory_items?.storage_unit || '',
      quantity_planned: q
    };
  });
  let allItemsCovered = true;

  for (const pi of order.items) {
    const qtyPlanned = Number(pi.quantity_planned) || 0;
    if (qtyPlanned <= 0) continue;

    // 1) Always try recipe by item_id first (production directly linked to recipes)
    let recipe = await fetchRecipeByItemId(pi.item_id);
    if (!recipe && pi.recipe_id) {
      const { data: r } = await supabaseClient.from('recipes').select('id, base_quantity').eq('id', pi.recipe_id).single();
      if (r) recipe = r;
    }

    if (recipe) {
      const baseQty = Number(recipe.base_quantity) || 1;
      const ingredients = await fetchRecipeIngredients(recipe.id);
      for (const ing of ingredients) {
        const ingQty = Number(ing.quantity ?? ing.quantity_required) || 0;
        const requiredQty = (ingQty / baseQty) * qtyPlanned;
        if (requiredQty <= 0) continue;
        rmLines.push({
          item_name: ing.itemName || ing.inventory_items?.name || ing.ingredient_item_id,
          sku: ing.sku || ing.inventory_items?.sku || '',
          unit: ing.storage_unit || ing.unit || '',
          required_qty: requiredQty,
          source: 'recipe',
          for_fg: pi.inventory_items?.name || pi.item_id
        });
      }
    } else {
      const manualForItem = (order.consumption || []).filter((c) => c.production_item_id === pi.id);
      if (manualForItem.length) {
        manualForItem.forEach((c) => {
          rmLines.push({
            item_name: c.inventory_items?.name || c.item_id,
            sku: c.inventory_items?.sku || '',
            unit: '',
            required_qty: Number(c.quantity) || 0,
            source: 'manual',
            for_fg: pi.inventory_items?.name || pi.item_id
          });
        });
      } else {
        allItemsCovered = false;
      }
    }
  }

  return { rmLines, fgLines, allItemsCovered, totalFgQty };
}

export async function executeProduction(productionId) {
  await ensureSupabaseReady();
  if (!supabaseClient) throw new Error('Supabase not ready');
  const userId = getCurrentUserUUID();
  const { data, error } = await supabaseClient.rpc('fn_execute_production', {
    p_production_id: productionId,
    p_user_id: userId
  });
  if (error) throw error;
  if (data && data.ok === false) throw new Error(data.error || 'Execute failed');
  return data;
}

export async function fetchRecipes() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const companyId = getCurrentCompanyId();
  const { data, error } = await supabaseClient
    .from('recipes')
    .select('*')
    .eq('company_id', companyId)
    .order('name');
  if (error) return [];
  return data || [];
}

// Legacy helper (kept for older callers). Prefer recipeService.fetchRecipeIngredients for BOM.
export async function fetchRecipeIngredientsLegacy(recipeId) {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('recipe_ingredients')
    .select('*, inventory_items(name, sku, storage_unit)')
    .eq('recipe_id', recipeId);
  if (error) return [];
  return data || [];
}

export async function fetchBranches() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('branches')
    .select('id, branch_name, branch_code')
    .order('branch_name');
  if (error) return [];
  return data || [];
}

export async function fetchInventoryItems() {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('inventory_items')
    .select('id, name, sku, storage_unit')
    .order('name');
  if (error) return [];
  return data || [];
}

/** Batch balance at location (from v_inventory_balance or ledger sum) for RM picking */
export async function fetchBatchBalances(itemId, locationId) {
  await ensureSupabaseReady();
  if (!supabaseClient) return [];
  const { data, error } = await supabaseClient
    .from('v_inventory_balance')
    .select('*')
    .eq('item_id', itemId)
    .eq('location_id', locationId)
    .gt('current_qty', 0);
  if (error) return [];
  return data || [];
}
