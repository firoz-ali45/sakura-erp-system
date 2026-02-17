<template>
  <div class="bg-white rounded-lg shadow-md overflow-hidden mt-6">
    <!-- Header -->
    <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
      <h2 class="text-xl font-semibold flex items-center gap-2">
        <i class="fas fa-project-diagram"></i>
        Document Flow
      </h2>
      <span class="text-sm opacity-80">SAP VBFA Style</span>
    </div>
    
    <!-- Flow Content -->
    <div class="p-6 overflow-x-auto">
      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-8">
        <div class="flex flex-col items-center gap-3">
          <i class="fas fa-spinner fa-spin text-3xl text-[#284b44]"></i>
          <span class="text-gray-500">Loading document flow...</span>
        </div>
      </div>
      
      <!-- Error -->
      <div v-else-if="error" class="text-center py-8">
        <i class="fas fa-exclamation-triangle text-3xl text-yellow-500 mb-2"></i>
        <p class="text-gray-600">{{ error }}</p>
        <button @click="loadFlow" class="mt-3 px-4 py-2 bg-[#284b44] text-white rounded-lg text-sm">
          Retry
        </button>
      </div>
      
      <!-- Document Flow Timeline -->
      <div v-else class="flex items-center justify-center gap-2 min-w-max py-4">
        <template v-for="(node, index) in flowNodes" :key="node.doc_type + '-' + index">
          <!-- Document Node -->
          <div 
            class="document-node"
            :class="[
              getNodeStateClass(node),
              node.is_current ? 'current' : '',
              (node.doc_id != null && node.doc_id !== '') ? 'clickable' : 'disabled'
            ]"
            @click="navigateToDocument(node)"
            :title="getTooltip(node)"
          >
            <!-- Multiple Documents Indicator -->
            <div v-if="node.count > 1" class="absolute -top-2 -right-2 bg-blue-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center shadow-md z-10">
              {{ node.count }}
            </div>
            
            <!-- Icon -->
            <div class="node-icon" :class="getIconBgClass(node)">
              <span class="text-2xl">{{ getNodeIcon(node.doc_type) }}</span>
            </div>
            
            <!-- Label -->
            <div class="node-label">{{ getNodeLabel(node.doc_type) }}</div>
            
            <!-- Document Number -->
            <div class="node-number" :class="node.doc_id ? 'text-blue-600' : 'text-gray-400'">
              {{ node.doc_number || 'Not Created' }}
              <span v-if="node.count > 1" class="text-xs text-gray-500 block">
                +{{ node.count - 1 }} more
              </span>
            </div>
            
            <!-- Status Badge -->
            <div v-if="node.doc_id" class="node-status" :class="getStatusBadgeClass(node.doc_status)">
              {{ formatStatus(node.doc_status) }}
            </div>
            
            <!-- Current Indicator -->
            <div v-if="node.is_current" class="current-badge">
              <i class="fas fa-location-dot mr-1"></i>Current
            </div>
          </div>
          
          <!-- Arrow Connector -->
          <div v-if="index < flowNodes.length - 1" class="arrow-connector">
            <div class="arrow-line" :class="getArrowClass(node, flowNodes[index + 1])"></div>
            <i class="fas fa-chevron-right arrow-icon" :class="getArrowClass(node, flowNodes[index + 1])"></i>
          </div>
        </template>
      </div>
      
      <!-- Summary Stats -->
      <div v-if="!loading && flowNodes.length > 0" class="mt-6 pt-4 border-t border-gray-200">
        <div class="flex justify-center gap-8 text-sm">
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-green-500"></span>
            <span class="text-gray-600">Exists</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-yellow-500"></span>
            <span class="text-gray-600">Current</span>
          </div>
          <div class="flex items-center gap-2">
            <span class="w-3 h-3 rounded-full bg-gray-300"></span>
            <span class="text-gray-600">Not Created</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';

const props = defineProps({
  docType: {
    type: String,
    required: true
  },
  docId: {
    type: [String, Number],
    required: false,
    default: null
  },
  currentNumber: {
    type: String,
    default: ''
  },
  /** Fallback when docId is empty (e.g. route.params.id from detail page) */
  routeDocId: {
    type: [String, Number],
    required: false,
    default: null
  },
  /** Parent-traced PR id (e.g. from PUR page) — used when fn_trace_graph returns pr: null */
  linkedPrId: {
    type: [String, Number],
    required: false,
    default: null
  },
  /** 'purchase' (PR→PO→GRN→PUR) or 'transfer' (TO→TRS→Received) */
  flowType: {
    type: String,
    default: 'purchase'
  },
  /** When flowType=transfer: transfer_orders_id from stock_transfer. If set, TO exists (never show "Not Created"). */
  transferOrdersId: {
    type: [String, Number],
    required: false,
    default: null
  },
  /** When flowType=transfer: TO number from parent (e.g. transfer.to_number). Used when transferOrdersId exists. */
  transferOrderNumber: {
    type: String,
    required: false,
    default: ''
  }
});

const router = useRouter();
const flowNodes = ref([]);
const loading = ref(true);
const error = ref(null);
const graphData = ref(null);

// Document type configurations
const docConfig = {
  PR: { label: 'Purchase Request', icon: '📄', route: '/homeportal/pr-detail/' },
  PO: { label: 'Purchase Order', icon: '🧾', route: '/homeportal/purchase-order-detail/' },
  GRN: { label: 'GRN (MIGO)', icon: '📦', route: '/homeportal/grn-detail/' },
  PUR: { label: 'Purchasing (MIRO)', icon: '💰', route: '/homeportal/purchasing-detail/' },
  PAYMENT: { label: 'Payment', icon: '💳', route: '/homeportal/payment-detail/' },
  TO: { label: 'Transfer Order', icon: '📋', route: '/homeportal/transfer-order-detail/' },
  TRS: { label: 'Stock Transfer', icon: '🚚', route: '/homeportal/transfer-sending/' },
  RECEIVED: { label: 'Received', icon: '✅', route: '/homeportal/transfer-sending/' }
};

// Document flow: fn_trace_graph only (doc_graph table). Returns pr/po/grn/pur as IDs.
const exists = (id) => id !== null && id !== undefined && id !== '';

const loadFlow = async () => {
  const rawId = props.docId ?? props.routeDocId;
  const currentId = rawId != null && rawId !== '' ? String(rawId) : null;
  if (!currentId) {
    const norm = normalizeDocType(props.docType);
    if (props.flowType === 'transfer' || norm === 'TO' || norm === 'TRS') {
      buildTransferFlowEmpty(norm);
    } else {
      buildFlowFromTraceGraph({ pr: null, po: null, grn: null, pur: null }, norm);
    }
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  const currentType = normalizeDocType(props.docType);

  try {
    const { ensureSupabaseReady } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready) throw new Error('Database connection not available');

    if (props.flowType === 'transfer' || currentType === 'TO' || currentType === 'TRS') {
      await buildTransferFlowManually(currentType, currentId);
    } else {
      await buildFlowManually(currentType, currentId, props.linkedPrId);
    }
  } catch (err) {
    console.error('Document flow error:', err);
    error.value = 'Failed to load document flow';
    if (props.flowType === 'transfer' || currentType === 'TO' || currentType === 'TRS') {
      buildTransferFlowFromProps(currentType);
    } else {
      buildFlowFromTraceGraph({ pr: null, po: null, grn: null, pur: null }, currentType);
    }
  } finally {
    loading.value = false;
  }
};

function normalizeDocType(t) {
  const u = (t || '').toUpperCase().trim();
  if (u === 'INV' || u === 'INVOICE') return 'PUR';
  if (u === 'GR') return 'GRN';
  if (u === 'PAY' || u === 'PMT') return 'PAYMENT';
  if (u === 'TRANSFER') return 'TRS';
  return u;
}

// fn_trace_graph returns { pr, po, grn, pur } as full objects or null.
// ROOT CAUSE FIX: When is_current, ALWAYS use props — we're viewing this doc, so it exists.
const numberKeys = { PR: 'pr_number', PO: 'po_number', GRN: 'grn_number', PUR: 'purchasing_number' };

const normalizeDoc = (doc, type) => {
  if (!doc) return null;
  if (typeof doc === 'string' || typeof doc === 'number') return { id: String(doc), [numberKeys[type]]: String(doc) };
  return doc;
};

const buildFlowFromTraceGraph = (graph, currentType) => {
  const docTypes = ['PR', 'PO', 'GRN', 'PUR'];
  const keys = { PR: 'pr', PO: 'po', GRN: 'grn', PUR: 'pur' };
  const rawId = props.docId ?? props.routeDocId;
  const currentId = rawId != null && rawId !== '' ? String(rawId) : null;
  const currentNum = (props.currentNumber || '').trim();

  const nodes = docTypes.map((type, index) => {
    const key = keys[type];
    const doc = normalizeDoc(graph?.[key], type);
    const fromBackend = doc && (doc.id != null && doc.id !== undefined && String(doc.id) !== '');
    const isCurrent = type === currentType;

    // CRITICAL: Current doc — ALWAYS use props when backend is null (fixes PR "Not Created")
    let doc_id = fromBackend ? String(doc.id) : null;
    let doc_number = fromBackend ? (doc[numberKeys[type]] ?? doc.number ?? String(doc.id)) : null;
    if (isCurrent && currentId) {
      doc_id = doc_id || currentId;
      doc_number = doc_number || currentNum || currentId;
    }
    const hasDoc = !!(doc_id && doc_id !== 'undefined');

    return {
      doc_type: type,
      doc_id: hasDoc ? doc_id : null,
      doc_number: hasDoc ? (doc_number || doc_id) : null,
      doc_status: fromBackend ? (doc.status ?? '—') : (hasDoc ? '—' : 'not_created'),
      doc_date: fromBackend ? doc.date : null,
      is_current: isCurrent,
      sequence_order: index + 1,
      count: hasDoc ? 1 : 0,
      all_docs: hasDoc ? (fromBackend ? [doc] : [{ id: doc_id, [numberKeys[type]]: doc_number }]) : []
    };
  });

  flowNodes.value = nodes;
};

// Transfer flow: TO → TRS → Received
const buildTransferFlowEmpty = (currentType) => {
  const nodes = [
    { doc_type: 'TO', doc_id: null, doc_number: null, doc_status: 'not_created', is_current: currentType === 'TO', sequence_order: 1 },
    { doc_type: 'TRS', doc_id: null, doc_number: null, doc_status: 'not_created', is_current: currentType === 'TRS', sequence_order: 2 },
    { doc_type: 'RECEIVED', doc_id: null, doc_number: null, doc_status: 'not_created', is_current: false, sequence_order: 3 }
  ];
  flowNodes.value = nodes;
};

// When DB fetch fails but parent passed transferOrdersId — show TO exists
const buildTransferFlowFromProps = (currentType) => {
  const linkedToId = props.transferOrdersId ?? null;
  const linkedToNum = (props.transferOrderNumber || '').trim();
  const rawId = props.docId ?? props.routeDocId;
  const currentId = rawId != null && rawId !== '' ? String(rawId) : null;
  const currentNum = (props.currentNumber || '').trim();
  const nodes = [
    {
      doc_type: 'TO',
      doc_id: linkedToId || null,
      doc_number: linkedToNum || (linkedToId ? 'TO (linked)' : null),
      doc_status: linkedToId ? 'linked' : 'not_created',
      is_current: currentType === 'TO',
      sequence_order: 1
    },
    {
      doc_type: 'TRS',
      doc_id: currentType === 'TRS' && currentId ? currentId : null,
      doc_number: currentType === 'TRS' && currentId ? (currentNum || currentId) : null,
      doc_status: currentType === 'TRS' && currentId ? '—' : 'not_created',
      is_current: currentType === 'TRS',
      sequence_order: 2
    },
    { doc_type: 'RECEIVED', doc_id: null, doc_number: null, doc_status: 'not_created', is_current: false, sequence_order: 3 }
  ];
  flowNodes.value = nodes;
};

const buildTransferFlowManually = async (currentType, docId) => {
  const { supabaseClient } = await import('@/services/supabase.js');
  let toData = null;
  let trsData = null;
  const linkedToId = props.transferOrdersId ?? null;

  if (currentType === 'TO') {
    const { data: to } = await supabaseClient
      .from('transfer_orders')
      .select('id, transfer_number, status')
      .eq('id', docId)
      .single();
    toData = to;
    if (to) {
      const { data: st } = await supabaseClient
        .from('stock_transfers')
        .select('id, transfer_number, status')
        .eq('transfer_orders_id', docId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      trsData = st;
    }
  } else if (currentType === 'TRS') {
    const { data: st } = await supabaseClient
      .from('stock_transfers')
      .select('id, transfer_number, transfer_orders_id, status')
      .eq('id', docId)
      .single();
    trsData = st;
    const toId = st?.transfer_orders_id ?? linkedToId;
    if (toId) {
      const { data: to } = await supabaseClient
        .from('transfer_orders')
        .select('id, transfer_number, status')
        .eq('id', toId)
        .single();
      toData = to;
      if (!toData && toId) {
        toData = { id: toId, transfer_number: props.transferOrderNumber || 'TO (linked)', status: 'linked' };
      }
    }
  }

  const rawId = props.docId ?? props.routeDocId;
  const currentId = rawId != null && rawId !== '' ? String(rawId) : null;
  const currentNum = (props.currentNumber || '').trim();
  const hasLinkedTo = !!(toData?.id || trsData?.transfer_orders_id || linkedToId);

  const nodes = [
    {
      doc_type: 'TO',
      doc_id: toData?.id || trsData?.transfer_orders_id || linkedToId || (currentType === 'TO' && currentId ? currentId : null),
      doc_number: toData?.transfer_number || toData?.to_number || props.transferOrderNumber || (currentType === 'TO' && currentId ? currentNum || currentId : (hasLinkedTo ? 'TO (linked)' : null)),
      doc_status: toData?.status || (currentType === 'TO' && currentId ? '—' : (hasLinkedTo ? 'linked' : 'not_created')),
      is_current: currentType === 'TO',
      sequence_order: 1
    },
    {
      doc_type: 'TRS',
      doc_id: trsData?.id || (currentType === 'TRS' && currentId ? currentId : null),
      doc_number: trsData?.transfer_number || (currentType === 'TRS' && currentId ? currentNum || currentId : null),
      doc_status: trsData?.status || (currentType === 'TRS' && currentId ? '—' : 'not_created'),
      is_current: currentType === 'TRS',
      sequence_order: 2
    },
    {
      doc_type: 'RECEIVED',
      doc_id: trsData?.status === 'completed' ? trsData?.id : null,
      doc_number: trsData?.status === 'completed' ? (trsData?.transfer_number || 'Completed') : null,
      doc_status: trsData?.status === 'completed' ? 'completed' : 'not_created',
      is_current: false,
      sequence_order: 3
    }
  ];

  flowNodes.value = nodes;
};

// Manual flow building (ultimate fallback)
const buildFlowManually = async (normalizedType, docId, linkedPrIdFromParent = null) => {
  const { supabaseClient } = await import('@/services/supabase.js');
  
  let prId = linkedPrIdFromParent ? String(linkedPrIdFromParent) : null;
  let poId = null, grnId = null, purId = null;
  let paymentId = null;
  
  // Initialize based on current document type
  if (normalizedType === 'PR') prId = prId || docId;
  else if (normalizedType === 'PO') poId = docId;
  else if (normalizedType === 'GRN') grnId = docId;
  else if (normalizedType === 'PUR' || normalizedType === 'INV' || normalizedType === 'INVOICE') purId = docId;
  else if (normalizedType === 'PAYMENT') paymentId = docId;
  
  const nodes = [];
  
  // Trace the chain
  try {
    if (paymentId && !purId) {
      let pay = (await supabaseClient.from('finance_payments').select('purchasing_invoice_id').eq('id', paymentId).single()).data;
      if (!pay) pay = (await supabaseClient.from('ap_payments').select('purchasing_invoice_id').eq('id', paymentId).single()).data;
      if (pay?.purchasing_invoice_id) purId = pay.purchasing_invoice_id;
    }
    // If starting from PUR, find GRN and PO
    if (purId) {
      const { data: pur } = await supabaseClient
        .from('purchasing_invoices')
        .select('id, purchasing_number, status, created_at, grn_id, purchase_order_id, purchase_order_number')
        .eq('id', purId)
        .single();
      
      if (pur) {
        if (pur.grn_id) grnId = pur.grn_id;
        if (pur.purchase_order_id) poId = pur.purchase_order_id;
        if (!poId && pur.purchase_order_number) {
          const { data: poRow } = await supabaseClient.from('purchase_orders').select('id').eq('po_number', (pur.purchase_order_number || '').trim()).maybeSingle();
          if (poRow?.id) poId = poRow.id;
        }
      }
    }
    
    // If we have GRN, find PO (by id OR by po_number when purchase_order_id is NULL)
    if (grnId && !poId) {
      const { data: grn } = await supabaseClient
        .from('grn_inspections')
        .select('purchase_order_id, purchase_order_number')
        .eq('id', grnId)
        .single();
      if (grn?.purchase_order_id) poId = grn.purchase_order_id;
      else if (grn?.purchase_order_number) {
        const { data: poRow } = await supabaseClient.from('purchase_orders').select('id').eq('po_number', (grn.purchase_order_number || '').trim()).maybeSingle();
        if (poRow?.id) poId = poRow.id;
      }
    }
    
    // If we have PO, find PR — DOCUMENT CHAIN: source_pr_id first (direct FK), then pr_po_linkage. NO item_id.
    if (poId && !prId) {
      const poIdNum = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
      const { data: poRow } = await supabaseClient.from('purchase_orders').select('source_pr_id, po_number').eq('id', poIdNum).maybeSingle();
      if (poRow?.source_pr_id) prId = poRow.source_pr_id;
      if (!prId) {
        let linkage = await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_id', poIdNum).limit(1);
        if (!linkage.data?.length && poRow?.po_number) linkage = await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', (poRow.po_number || '').trim()).limit(1);
        if (linkage?.data?.[0]?.pr_id) prId = linkage.data[0].pr_id;
      }
    }
    
    // If starting from PR, find PO — DOCUMENT CHAIN: source_pr_id first (direct FK), then pr_po_linkage. NO item_id.
    if (prId && !poId) {
      const { data: poFromSource } = await supabaseClient.from('purchase_orders').select('id, po_number').eq('source_pr_id', prId).eq('deleted', false).limit(1);
      if (poFromSource?.[0]?.id) poId = poFromSource[0].id;
      if (!poId) {
        let linkage = (await supabaseClient.from('pr_po_linkage').select('po_id, po_number').eq('pr_id', prId).limit(1)).data;
        if (!linkage?.length) {
          const { data: prRow } = await supabaseClient.from('purchase_requests').select('pr_number').eq('id', prId).maybeSingle();
          if (prRow?.pr_number) linkage = (await supabaseClient.from('pr_po_linkage').select('po_id, po_number').eq('pr_number', (prRow.pr_number || '').trim()).limit(1)).data;
        }
        if (linkage?.[0]?.po_id) poId = linkage[0].po_id;
      }
    }
    
    // If we have PO, find GRN (by purchase_order_id OR by po_number)
    if (poId && !grnId) {
      const poIdNum = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
      let grnRes = await supabaseClient.from('grn_inspections').select('id, grn_number').eq('purchase_order_id', poIdNum).limit(1);
      if (!grnRes.data?.length) {
        const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdNum).maybeSingle();
        if (poRow?.po_number) {
          grnRes = await supabaseClient.from('grn_inspections').select('id, grn_number').eq('purchase_order_number', (poRow.po_number || '').trim()).limit(1);
        }
      }
      if (grnRes?.data?.[0]?.id) grnId = grnRes.data[0].id;
    }
    
    // If we have GRN, find PUR
    if (grnId && !purId) {
      const { data: purList } = await supabaseClient
        .from('purchasing_invoices')
        .select('id')
        .eq('grn_id', grnId)
        .limit(1);
      if (purList?.[0]?.id) purId = purList[0].id;
    }
    
    // If we have PO but no PUR through GRN, check direct (by id or po_number)
    if (poId && !purId) {
      const poIdNum = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
      let purRes = await supabaseClient.from('purchasing_invoices').select('id').eq('purchase_order_id', poIdNum).limit(1);
      if (!purRes.data?.length) {
        const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdNum).maybeSingle();
        if (poRow?.po_number) {
          purRes = await supabaseClient.from('purchasing_invoices').select('id').eq('purchase_order_number', (poRow.po_number || '').trim()).limit(1);
        }
      }
      if (purRes?.data?.[0]?.id) purId = purRes.data[0].id;
    }
    
    
    // Now fetch all the documents
    if (prId) {
      const { data: pr } = await supabaseClient
        .from('purchase_requests')
        .select('id, pr_number, status, created_at')
        .eq('id', prId)
        .single();
      if (pr) {
        nodes.push({
          doc_type: 'PR',
          doc_id: pr.id,
          doc_number: pr.pr_number,
          doc_status: pr.status,
          doc_date: pr.created_at,
          is_current: normalizedType === 'PR',
          sequence_order: 1,
          count: 1
        });
      }
    }
    
    if (poId) {
      const { data: po } = await supabaseClient
        .from('purchase_orders')
        .select('id, po_number, status, order_date')
        .eq('id', poId)
        .single();
      if (po) {
        nodes.push({
          doc_type: 'PO',
          doc_id: String(po.id),
          doc_number: po.po_number,
          doc_status: po.status,
          doc_date: po.order_date,
          is_current: normalizedType === 'PO',
          sequence_order: 2,
          count: 1
        });
      }
    }
    
    if (grnId) {
      const { data: grn } = await supabaseClient
        .from('grn_inspections')
        .select('id, grn_number, status, grn_date')
        .eq('id', grnId)
        .single();
      if (grn) {
        nodes.push({
          doc_type: 'GRN',
          doc_id: grn.id,
          doc_number: grn.grn_number,
          doc_status: grn.status,
          doc_date: grn.grn_date,
          is_current: normalizedType === 'GRN',
          sequence_order: 3,
          count: 1
        });
      }
    }
    
    if (purId) {
      const { data: pur } = await supabaseClient
        .from('purchasing_invoices')
        .select('id, purchasing_number, status, created_at')
        .eq('id', purId)
        .single();
      if (pur) {
        nodes.push({
          doc_type: 'PUR',
          doc_id: pur.id,
          doc_number: pur.purchasing_number,
          doc_status: pur.status,
          doc_date: pur.created_at,
          is_current: normalizedType === 'PUR' || normalizedType === 'INV' || normalizedType === 'INVOICE',
          sequence_order: 4,
          count: 1
        });
      }
    }

    if (purId || paymentId) {
      let pay = null;
      if (paymentId) {
        pay = (await supabaseClient.from('finance_payments').select('id, payment_number, status').eq('id', paymentId).single()).data;
        if (!pay) pay = (await supabaseClient.from('ap_payments').select('id, payment_number, status').eq('id', paymentId).single()).data;
      }
      if (!pay && purId) {
        pay = (await supabaseClient.from('finance_payments').select('id, payment_number, status').eq('purchasing_invoice_id', purId).order('created_at', { ascending: false }).limit(1).maybeSingle()).data;
        if (!pay) pay = (await supabaseClient.from('ap_payments').select('id, payment_number, status').eq('purchasing_invoice_id', purId).order('payment_date', { ascending: false }).limit(1).maybeSingle()).data;
      }
      if (pay) {
        nodes.push({
          doc_type: 'PAYMENT',
          doc_id: pay.id,
          doc_number: pay.payment_number,
          doc_status: pay.status || 'completed',
          doc_date: null,
          is_current: normalizedType === 'PAYMENT',
          sequence_order: 5,
          count: 1
        });
      }
    }
  } catch (e) {
    console.error('🔧 ERROR in manual chain building:', e);
    console.error('🔧 Error stack:', e.stack);
  }
  
  
  // Ensure all 5 document types are present (PR, PO, GRN, PUR, PAYMENT)
  const docTypes = ['PR', 'PO', 'GRN', 'PUR', 'PAYMENT'];
  const existingTypes = new Set(nodes.map(n => n.doc_type));
  
  docTypes.forEach((type, index) => {
    if (!existingTypes.has(type)) {
      nodes.push({
        doc_type: type,
        doc_id: null,
        doc_number: null,
        doc_status: 'not_created',
        doc_date: null,
        is_current: false,
        sequence_order: index + 1,
        count: 0
      });
    }
  });
  
  // CRITICAL: Current document MUST show — we're viewing it (fixes PR "Not Created" on PR page)
  const currentNum = (props.currentNumber || '').trim();
  let idx = nodes.findIndex(n => n.doc_type === normalizedType);
  if (idx < 0 && normalizedType === 'PAYMENT') {
    nodes.push({ doc_type: 'PAYMENT', doc_id: null, doc_number: null, doc_status: 'not_created', doc_date: null, is_current: false, sequence_order: 5, count: 0 });
    idx = nodes.length - 1;
  }
  if (idx >= 0 && (!nodes[idx].doc_id || nodes[idx].doc_id === '') && docId) {
    nodes[idx].doc_id = String(docId);
    nodes[idx].doc_number = currentNum || String(docId);
    nodes[idx].doc_status = nodes[idx].doc_status === 'not_created' ? '—' : nodes[idx].doc_status;
    nodes[idx].is_current = true;
    nodes[idx].count = 1;
  }
  
  // Sort by sequence order
  nodes.sort((a, b) => a.sequence_order - b.sequence_order);
  flowNodes.value = nodes;
  
  console.log('📊 Manual flow built:', nodes);
};

// Navigation — clickable only when exists (doc.id != null)
const navigateToDocument = (node) => {
  if (node.doc_id == null || node.doc_id === '' || node.is_current) return;
  const config = docConfig[node.doc_type];
  if (config?.route) router.push(config.route + node.doc_id);
};

// Helpers
const getNodeIcon = (type) => docConfig[type]?.icon || '📄';
const getNodeLabel = (type) => docConfig[type]?.label || type;

const getNodeStateClass = (node) => {
  if (node.is_current) return 'state-current';
  if (!node.doc_id) return 'state-pending';
  return 'state-completed';
};

const getIconBgClass = (node) => {
  if (node.is_current) return 'bg-yellow-100';
  if (!node.doc_id) return 'bg-gray-100';
  return 'bg-green-100';
};

const getStatusBadgeClass = (status) => {
  const classes = {
    'approved': 'badge-success',
    'completed': 'badge-success',
    'posted': 'badge-success',
    'passed': 'badge-success',
    'fully_ordered': 'badge-success',
    'fully_received': 'badge-success',
    'paid': 'badge-success',
    'draft': 'badge-warning',
    'pending': 'badge-warning',
    'pending_approval': 'badge-warning',
    'under_inspection': 'badge-warning',
    'partially_ordered': 'badge-info',
    'partial_received': 'badge-info',
    'partial': 'badge-info',
    'rejected': 'badge-danger',
    'cancelled': 'badge-danger'
  };
  return classes[status] || 'badge-default';
};

const getArrowClass = (source, target) => {
  if (source.doc_id && target.doc_id) return 'arrow-active';
  if (source.doc_id && !target.doc_id) return 'arrow-next';
  return 'arrow-inactive';
};

const formatStatus = (status) => {
  if (!status) return '';
  return status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
};

const getTooltip = (node) => {
  if (!node.doc_id) return `${getNodeLabel(node.doc_type)} - Not yet created`;
  let tooltip = `${getNodeLabel(node.doc_type)}: ${node.doc_number}`;
  if (node.doc_status) tooltip += `\nStatus: ${formatStatus(node.doc_status)}`;
  if (node.doc_date) tooltip += `\nDate: ${new Date(node.doc_date).toLocaleDateString()}`;
  if (node.count > 1) tooltip += `\n\n${node.count} total documents (click to see first)`;
  return tooltip;
};

// Lifecycle
onMounted(loadFlow);
watch(() => props.docId, loadFlow);
watch(() => props.docType, loadFlow);
watch(() => props.routeDocId, loadFlow);
watch(() => props.linkedPrId, loadFlow);
</script>

<style scoped>
.document-node {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 1rem;
  border-radius: 12px;
  border: 2px solid transparent;
  min-width: 140px;
  max-width: 160px;
  transition: all 0.3s ease;
  position: relative;
}

.document-node.clickable {
  cursor: pointer;
}

.document-node.clickable:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px -5px rgba(0, 0, 0, 0.1);
}

.document-node.disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

/* State Classes */
.state-completed {
  background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
  border-color: #86efac;
}

.state-current {
  background: linear-gradient(135deg, #fefce8 0%, #fef08a 100%);
  border-color: #fbbf24;
  transform: scale(1.05);
  box-shadow: 0 4px 20px -5px rgba(251, 191, 36, 0.4);
}

.state-pending {
  background: linear-gradient(135deg, #f9fafb 0%, #f3f4f6 100%);
  border-color: #d1d5db;
}

.node-icon {
  width: 56px;
  height: 56px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.75rem;
}

.node-label {
  font-size: 0.75rem;
  font-weight: 600;
  color: #374151;
  text-align: center;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  margin-bottom: 0.25rem;
}

.node-number {
  font-size: 0.875rem;
  font-weight: 700;
  text-align: center;
  word-break: break-all;
}

.node-status {
  margin-top: 0.5rem;
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.625rem;
  font-weight: 600;
  text-transform: uppercase;
}

.current-badge {
  position: absolute;
  top: -8px;
  right: -8px;
  background: #f59e0b;
  color: white;
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.625rem;
  font-weight: 600;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

/* Status Badges */
.badge-success { background: #dcfce7; color: #166534; }
.badge-warning { background: #fef3c7; color: #92400e; }
.badge-info { background: #dbeafe; color: #1e40af; }
.badge-danger { background: #fee2e2; color: #991b1b; }
.badge-default { background: #f3f4f6; color: #374151; }

/* Arrow Connector */
.arrow-connector {
  display: flex;
  align-items: center;
  padding: 0 0.5rem;
}

.arrow-line {
  width: 30px;
  height: 2px;
  margin-right: -8px;
}

.arrow-icon {
  font-size: 1rem;
}

.arrow-active {
  color: #22c55e;
  background: #22c55e;
}

.arrow-next {
  color: #fbbf24;
  background: #fbbf24;
}

.arrow-inactive {
  color: #d1d5db;
  background: #d1d5db;
}

/* Responsive */
@media (max-width: 768px) {
  .document-node {
    min-width: 100px;
    max-width: 120px;
    padding: 0.75rem;
  }
  
  .node-icon {
    width: 40px;
    height: 40px;
  }
  
  .node-icon span {
    font-size: 1.25rem !important;
  }
}
</style>
