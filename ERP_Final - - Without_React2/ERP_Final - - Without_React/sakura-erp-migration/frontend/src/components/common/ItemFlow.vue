<template>
  <div class="item-flow-container bg-white p-4 rounded-lg shadow-sm border border-gray-200 mt-6">
    <h3 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
      <i class="fas fa-list-ol text-[#284b44]"></i>
      {{ t('common.itemTransactionFlow') }} (EKBE)
      <span v-if="items.length > 0" class="text-sm font-normal text-gray-500 ml-2">
        ({{ items.length }} items)
      </span>
    </h3>
    
    <div v-if="loading" class="flex justify-center py-8">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-[#284b44]"></div>
    </div>
    
    <div v-else-if="error" class="text-red-600 bg-red-50 p-4 rounded-lg">
      <i class="fas fa-exclamation-triangle mr-2"></i>
      {{ error }}
      <button @click="loadFlow" class="ml-4 text-sm underline">Retry</button>
    </div>

    <div v-else class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 border border-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th scope="col" class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Item / PR #</th>
            <th scope="col" class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">PR Qty</th>
            <th scope="col" class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider bg-blue-50">Ordered (PO)</th>
            <th scope="col" class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider bg-green-50">Received (GRN)</th>
            <th scope="col" class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider bg-purple-50">Invoiced (PUR)</th>
            <th scope="col" class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider bg-red-50">Open (PO-GRN)</th>
            <th scope="col" class="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-if="items.length === 0">
            <td colspan="7" class="px-6 py-8 text-center text-sm text-gray-500">
              <i class="fas fa-box-open text-3xl text-gray-300 mb-2 block"></i>
              No item history found.
            </td>
          </tr>
          <tr v-for="item in items" :key="item.pr_item_id" class="hover:bg-gray-50 transition-colors">
            <td class="px-4 py-4 whitespace-nowrap">
              <div class="text-sm font-medium text-gray-900 max-w-xs truncate" :title="item.item_name">
                {{ item.item_name }}
              </div>
              <div class="text-xs text-gray-600 font-medium" :title="item.pr_number">
                {{ item.pr_number || '—' }} 
                <span v-if="item.pr_pos">(Pos {{ item.pr_pos }})</span>
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right text-sm bg-gray-50/50">
              <span :class="item.pr_qty > 0 ? 'text-gray-700 font-semibold' : 'text-gray-400'">
              {{ formatNumber(item.pr_qty) }}
              </span>
              <span v-if="item.unit" class="text-xs text-gray-400 ml-1">{{ item.unit }}</span>
              <div v-if="item.pr_number" class="text-[10px] text-gray-600 font-medium truncate max-w-[120px] mt-0.5" :title="item.pr_number">
                {{ item.pr_number }}
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right text-sm bg-blue-50/50">
              <span :class="item.po_qty > 0 ? 'text-blue-700 font-semibold' : 'text-gray-400'">
              {{ formatNumber(item.po_qty) }}
              </span>
              <div v-if="item.po_numbers" class="text-[10px] text-blue-600 font-medium truncate max-w-[120px]" :title="item.po_numbers">
                {{ item.po_numbers }}
              </div>
              <!-- Progress bar -->
              <div v-if="item.pr_qty > 0" class="mt-1 h-1 bg-gray-200 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-blue-500 transition-all" 
                  :style="{ width: Math.min(100, (item.po_qty / item.pr_qty * 100)) + '%' }"
                ></div>
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right text-sm bg-green-50/50">
              <span :class="item.grn_qty > 0 ? 'text-green-700 font-semibold' : 'text-gray-400'">
              {{ formatNumber(item.grn_qty) }}
              </span>
              <div v-if="item.grn_numbers" class="text-[10px] text-green-600 font-medium truncate max-w-[120px]" :title="item.grn_numbers">
                {{ item.grn_numbers }}
              </div>
              <!-- Progress bar -->
              <div v-if="item.po_qty > 0" class="mt-1 h-1 bg-gray-200 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-green-500 transition-all" 
                  :style="{ width: Math.min(100, (item.grn_qty / item.po_qty * 100)) + '%' }"
                ></div>
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right text-sm bg-purple-50/50">
              <span :class="item.pur_qty > 0 ? 'text-purple-700 font-semibold' : 'text-gray-400'">
              {{ formatNumber(item.pur_qty) }}
              </span>
              <div v-if="item.pur_numbers" class="text-[10px] text-purple-600 font-medium truncate max-w-[120px]" :title="item.pur_numbers">
                {{ item.pur_numbers }}
              </div>
              <!-- Progress bar -->
              <div v-if="item.grn_qty > 0" class="mt-1 h-1 bg-gray-200 rounded-full overflow-hidden">
                <div 
                  class="h-full bg-purple-500 transition-all" 
                  :style="{ width: Math.min(100, (item.pur_qty / item.grn_qty * 100)) + '%' }"
                ></div>
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-right text-sm bg-red-50/30">
              <span :class="item.remaining_po > 0 ? 'text-red-600 font-bold' : 'text-green-600'">
              {{ formatNumber(item.remaining_po) }}
              </span>
              <div v-if="item.remaining_po > 0" class="text-[10px] text-red-400">
                to receive
              </div>
            </td>
            <td class="px-4 py-4 whitespace-nowrap text-center">
              <span 
                :class="getStatusClass(item.chain_status)" 
                class="px-2 py-1 inline-flex text-xs leading-5 font-semibold rounded-full"
              >
                {{ item.chain_status }}
              </span>
            </td>
          </tr>
        </tbody>
        <!-- Summary Footer -->
        <tfoot v-if="items.length > 0" class="bg-gray-100 font-semibold">
          <tr>
            <td class="px-4 py-3 text-right text-sm text-gray-700">Totals:</td>
            <td class="px-4 py-3 text-right text-sm text-gray-900">{{ formatNumber(totals.pr_qty) }}</td>
            <td class="px-4 py-3 text-right text-sm text-blue-700 bg-blue-50">{{ formatNumber(totals.po_qty) }}</td>
            <td class="px-4 py-3 text-right text-sm text-green-700 bg-green-50">{{ formatNumber(totals.grn_qty) }}</td>
            <td class="px-4 py-3 text-right text-sm text-purple-700 bg-purple-50">{{ formatNumber(totals.pur_qty) }}</td>
            <td class="px-4 py-3 text-right text-sm bg-red-50" :class="totals.remaining_po > 0 ? 'text-red-600' : 'text-green-600'">
              {{ formatNumber(totals.remaining_po) }}
            </td>
            <td class="px-4 py-3"></td>
          </tr>
        </tfoot>
      </table>
    </div>
    
    <!-- Legend -->
    <div v-if="items.length > 0" class="mt-4 pt-3 border-t border-gray-200 flex flex-wrap gap-4 text-xs text-gray-600">
      <div class="flex items-center gap-1">
        <span class="w-3 h-3 rounded-full bg-gray-100"></span> Pending
      </div>
      <div class="flex items-center gap-1">
        <span class="w-3 h-3 rounded-full bg-blue-100"></span> Ordered
      </div>
      <div class="flex items-center gap-1">
        <span class="w-3 h-3 rounded-full bg-yellow-100"></span> Partial Received
      </div>
      <div class="flex items-center gap-1">
        <span class="w-3 h-3 rounded-full bg-green-100"></span> Fully Received
      </div>
      <div class="flex items-center gap-1">
        <span class="w-3 h-3 rounded-full bg-purple-100"></span> Invoiced
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  prId: {
    type: String,
    required: false
  },
  poId: {
    type: [String, Number],
    required: false
  },
  grnId: {
    type: String,
    required: false
  }
});

const { t } = useI18n();
const items = ref([]);
const loading = ref(false);
const error = ref(null);

// Computed totals
const totals = computed(() => {
  return items.value.reduce((acc, item) => ({
    pr_qty: acc.pr_qty + Number(item.pr_qty || 0),
    po_qty: acc.po_qty + Number(item.po_qty || 0),
    grn_qty: acc.grn_qty + Number(item.grn_qty || 0),
    pur_qty: acc.pur_qty + Number(item.pur_qty || 0),
    remaining_po: acc.remaining_po + Number(item.remaining_po || 0)
  }), { pr_qty: 0, po_qty: 0, grn_qty: 0, pur_qty: 0, remaining_po: 0 });
});

const formatNumber = (num) => {
  if (num === null || num === undefined) return '0';
  return Number(num).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 });
};

const getStatusClass = (status) => {
  switch(status) {
    case 'Pending': return 'bg-gray-100 text-gray-800';
    case 'Ordered': return 'bg-blue-100 text-blue-800';
    case 'Partial Received': return 'bg-yellow-100 text-yellow-800';
    case 'Fully Received': return 'bg-green-100 text-green-800';
    case 'Partial Invoiced': return 'bg-indigo-100 text-indigo-800';
    case 'Invoiced': return 'bg-purple-100 text-purple-800';
    case 'Processing': return 'bg-orange-100 text-orange-800';
    default: return 'bg-gray-100 text-gray-800';
  }
};

const loadFlow = async () => {
  if (!props.prId && !props.poId && !props.grnId) {
    items.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    // When grnId is provided (PR page with traced GRN, or GRN/PUR page), use GRN path FIRST — correct quantities
    // received_qty from grn_inspection_items. PO path uses purchase_order_items.quantity_received
    // which is often 0 when not synced.
    if (props.grnId) {
      console.log('📊 Loading item flow for GRN:', props.grnId);
      
      // Get GRN details to find PO (by id or purchase_order_number)
      const { data: grn } = await supabaseClient
        .from('grn_inspections')
        .select('purchase_order_id, purchase_order_number')
        .eq('id', props.grnId)
        .single();
      
      let poId = grn?.purchase_order_id;
      if (!poId && grn?.purchase_order_number) {
        const { data: po } = await supabaseClient
          .from('purchase_orders')
          .select('id')
          .eq('po_number', (grn.purchase_order_number || '').trim())
          .limit(1)
          .maybeSingle();
        if (po?.id) poId = po.id;
      }
      
      if (poId) {
        // Find PRs via PO (try po_id, then po_number)
        const poIdVal = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
        let linkage = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_id', poIdVal)).data;
        if (!linkage?.length && grn?.purchase_order_number) {
          linkage = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', (grn.purchase_order_number || '').trim())).data;
        }
        if (linkage?.length) {
          const prIds = [...new Set(linkage.map(l => l.pr_id))];
          
    const { data, error: dbError } = await supabaseClient
      .from('v_item_flow_recursive')
      .select('*')
            .in('pr_id', prIds)
            .order('pr_number', { ascending: true })
            .order('pr_pos', { ascending: true });
          
          if (!dbError && data?.length) {
            items.value = data;
            console.log('📊 Item flow for GRN (from view):', data);
            return;
          }
        }
      }
      
      // Fallback: v_item_flow_by_grn (may not exist - skip if 404)
      const { data: grnItems, error: grnError } = await supabaseClient
        .from('v_item_flow_by_grn')
        .select('*')
        .eq('grn_id', props.grnId);
      
      if (!grnError && grnItems?.length) {
        let prNumFallback = '';
        if (props.prId) {
          const { data: prRow } = await supabaseClient.from('purchase_requests').select('pr_number').eq('id', props.prId).maybeSingle();
          prNumFallback = (prRow?.pr_number && !String(prRow.pr_number).toUpperCase().startsWith('GRN')) ? String(prRow.pr_number) : '';
        }
        items.value = grnItems.map((item, i) => {
          const ord = Number(item.ordered_qty || 0);
          const recv = Number(item.received_qty || 0);
          const rem = Math.max(0, ord - recv);
          const prNum = (item.pr_number && !String(item.pr_number).toUpperCase().startsWith('GRN')) ? String(item.pr_number) : prNumFallback;
          return {
            pr_item_id: item.grn_item_id,
            pr_id: props.prId || null,
            pr_number: prNum,
            pr_pos: i + 1,
            item_name: item.item_name,
            pr_qty: ord,
            po_qty: ord,
            grn_qty: recv,
            pur_qty: Number(item.invoiced_qty || 0),
            remaining_po: rem,
            po_numbers: item.po_number || '',
            grn_numbers: item.grn_number || '',
            pur_numbers: item.pur_numbers || '',
            chain_status: item.item_status || (recv >= ord ? 'Fully Received' : 'Partial Received')
          };
        });
        return;
      }
      
      // Last resort: GRN inspection items + fetch PR/PO/PUR refs
      const { data: gii } = await supabaseClient
        .from('grn_inspection_items')
        .select('id, item_id, item_name, received_quantity, ordered_quantity')
        .eq('grn_inspection_id', props.grnId);
      if (gii?.length) {
        const { data: grnRow } = await supabaseClient.from('grn_inspections')
          .select('grn_number, purchase_order_id, purchase_order_number')
          .eq('id', props.grnId).single();
        let poNumber = '';
        let prNumber = '';
        let purNumbers = '';
        let purQtyByItem = {};
        if (grnRow) {
          const grnPoId = grnRow.purchase_order_id;
          let resolvedPoId = grnPoId;
          if (!resolvedPoId && grnRow.purchase_order_number) {
            const { data: poRow } = await supabaseClient.from('purchase_orders')
              .select('id, po_number').eq('po_number', (grnRow.purchase_order_number || '').trim()).maybeSingle();
            if (poRow) { resolvedPoId = poRow.id; poNumber = poRow.po_number || ''; }
          } else if (resolvedPoId) {
            const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', resolvedPoId).maybeSingle();
            poNumber = poRow?.po_number || '';
          }
          if (resolvedPoId) {
            const poIdForLink = typeof resolvedPoId === 'number' ? resolvedPoId : (parseInt(resolvedPoId, 10) || resolvedPoId);
            let linkRow = (await supabaseClient.from('pr_po_linkage').select('pr_id, pr_number').eq('po_id', poIdForLink).limit(1).maybeSingle()).data;
            if (!linkRow?.pr_id && (poNumber || grnRow?.purchase_order_number)) {
              linkRow = (await supabaseClient.from('pr_po_linkage').select('pr_id, pr_number').eq('po_number', (poNumber || grnRow?.purchase_order_number || '').trim()).limit(1).maybeSingle()).data;
            }
            prNumber = linkRow?.pr_number || '';
            if (!prNumber && linkRow?.pr_id) {
              const { data: prRow } = await supabaseClient.from('purchase_requests').select('pr_number').eq('id', linkRow.pr_id).maybeSingle();
              prNumber = prRow?.pr_number || '';
            }
          }
          const { data: purRows } = await supabaseClient.from('purchasing_invoices')
            .select('id, purchasing_number').eq('grn_id', props.grnId);
          purNumbers = (purRows || []).map(p => p.purchasing_number).filter(Boolean).join(', ');
          if (purRows?.length) {
            const purIds = purRows.map(p => p.id);
            const { data: pii } = await supabaseClient.from('purchasing_invoice_items')
              .select('item_id, item_name, quantity')
              .in('purchasing_invoice_id', purIds);
            purQtyByItem = (pii || []).reduce((acc, row) => {
              const key = String(row.item_id || row.item_name || '');
              acc[key] = (acc[key] || 0) + Number(row.quantity || 0);
              return acc;
            }, {});
          }
        }
        const safePrNum = (prNumber && !String(prNumber).toUpperCase().startsWith('GRN')) ? String(prNumber) : '';
        items.value = gii.map((g, i) => {
          const ord = Number(g.ordered_quantity || g.received_quantity || 0);
          const recv = Number(g.received_quantity || 0);
          const rem = Math.max(0, ord - recv);
          const status = recv >= ord ? 'Fully Received' : 'Partial Received';
          const purQty = (purQtyByItem[String(g.item_id || '')] || purQtyByItem[String(g.item_name || '')] || 0);
          return {
            pr_item_id: g.id,
            pr_id: null,
            pr_number: safePrNum,
            pr_pos: i + 1,
            item_name: g.item_name,
            pr_qty: ord,
            po_qty: ord,
            grn_qty: recv,
            pur_qty: purQty,
            remaining_po: rem,
            po_numbers: poNumber || grnRow?.purchase_order_number || '',
            grn_numbers: grnRow?.grn_number || '',
            pur_numbers: purNumbers,
            chain_status: status
          };
        });
      }
      return;
    }
    
    // If PO ID is provided (PO detail page, or when no grnId)
    if (props.poId) {
      console.log('📊 Loading item flow for PO:', props.poId);
      const poIdVal = typeof props.poId === 'number' ? props.poId : (parseInt(props.poId, 10) || props.poId);
      let linkage = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_id', poIdVal)).data;
      if (!linkage?.length) {
        const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdVal).maybeSingle();
        if (poRow?.po_number) {
          linkage = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', (poRow.po_number || '').trim())).data;
        }
      }
      if (linkage?.length) {
        const prIds = [...new Set(linkage.map(l => l.pr_id))];
        const { data, error: dbError } = await supabaseClient
          .from('v_item_flow_recursive')
          .select('*')
          .in('pr_id', prIds)
          .order('pr_number', { ascending: true })
          .order('pr_pos', { ascending: true });
        if (!dbError && data?.length) {
          items.value = data;
          return;
        }
      }
      const { data: poItems, error: poError } = await supabaseClient
        .from('v_item_flow_by_po')
        .select('*')
        .eq('po_id', poIdVal);
      if (!poError && poItems?.length) {
        items.value = poItems.map(item => ({
          pr_item_id: item.po_item_id,
          pr_id: null,
          pr_number: (item.pr_number && !String(item.pr_number).toUpperCase().startsWith('GRN')) ? String(item.pr_number) : '',
          pr_pos: item.po_pos,
          item_name: item.item_name,
          pr_qty: item.po_qty,
          po_qty: item.po_qty,
          grn_qty: item.grn_qty,
          pur_qty: item.pur_qty,
          remaining_po: item.remaining_to_receive,
          po_numbers: item.po_number,
          grn_numbers: item.grn_numbers,
          pur_numbers: item.pur_numbers,
          chain_status: item.item_status
        }));
        return;
      }
      const { data: poi } = await supabaseClient
        .from('purchase_order_items')
        .select('id, item_name, quantity, quantity_received, unit')
        .eq('purchase_order_id', poIdVal);
      if (poi?.length) {
        const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdVal).maybeSingle();
        let prNum = '';
        let linkRow = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_id', poIdVal).limit(1).maybeSingle()).data;
        if (!linkRow?.pr_id && poRow?.po_number) {
          linkRow = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', (poRow.po_number || '').trim()).limit(1).maybeSingle()).data;
        }
        if (linkRow?.pr_id) {
          const { data: prRow } = await supabaseClient.from('purchase_requests').select('pr_number').eq('id', linkRow.pr_id).maybeSingle();
          prNum = (prRow?.pr_number && !String(prRow.pr_number).toUpperCase().startsWith('GRN')) ? String(prRow.pr_number) : '';
        }
        items.value = poi.map((p, i) => ({
          pr_item_id: p.id,
          pr_id: linkRow?.pr_id || null,
          pr_number: prNum,
          pr_pos: i + 1,
          item_name: p.item_name,
          pr_qty: p.quantity || 0,
          po_qty: p.quantity || 0,
          grn_qty: p.quantity_received || 0,
          pur_qty: 0,
          remaining_po: Math.max(0, (p.quantity || 0) - (p.quantity_received || 0)),
          po_numbers: poRow?.po_number || '',
          grn_numbers: '',
          pur_numbers: '',
          chain_status: (p.quantity_received || 0) >= (p.quantity || 0) ? 'Fully Received' : 'Partial Received'
        }));
      }
    }
    
    // If PR ID is provided (PR page without traced grnId)
    if (props.prId) {
      const { data: d1 } = await supabaseClient.from('v_item_flow_recursive').select('*').eq('pr_id', props.prId).order('pr_pos');
      if (d1?.length && d1.some(r => (r.po_qty || 0) > 0 || (r.grn_qty || 0) > 0)) {
        items.value = d1;
        return;
      }
      const { data: d2 } = await supabaseClient.from('v_item_transaction_flow').select('*').eq('pr_id', props.prId).order('pr_pos');
      if (d2?.length && d2.some(r => (r.po_qty || 0) > 0 || (r.grn_qty || 0) > 0)) {
        items.value = d2;
        return;
      }
      const { data: prItems } = await supabaseClient.from('purchase_request_items').select('id, pr_id, item_number, item_name, item_code, quantity, unit').eq('pr_id', props.prId).eq('deleted', false);
      if (prItems?.length) {
        const { data: prRow } = await supabaseClient.from('purchase_requests').select('pr_number').eq('id', props.prId).maybeSingle();
        items.value = prItems.map((p, i) => ({
          pr_item_id: p.id, pr_id: p.pr_id, pr_number: prRow?.pr_number || '', pr_pos: p.item_number || i + 1,
          item_name: p.item_name, item_code: p.item_code, pr_qty: p.quantity || 0, po_qty: 0, grn_qty: 0, pur_qty: 0,
          remaining_po: 0, chain_status: 'Pending', po_numbers: '', grn_numbers: '', pur_numbers: ''
        }));
      } else {
        items.value = [];
      }
    }
    
  } catch (err) {
    console.error('Item Flow Error:', err);
    error.value = 'Failed to load item flow: ' + (err.message || 'Unknown error');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadFlow();
});

watch(() => props.prId, () => loadFlow());
watch(() => props.poId, () => loadFlow());
watch(() => props.grnId, () => loadFlow());
</script>

<style scoped>
.item-flow-container {
  overflow: hidden;
}
</style>
