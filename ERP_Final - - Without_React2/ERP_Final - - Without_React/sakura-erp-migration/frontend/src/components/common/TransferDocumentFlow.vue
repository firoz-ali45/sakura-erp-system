<template>
  <div class="bg-white rounded-lg shadow-md overflow-hidden mt-6">
    <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
      <h2 class="text-xl font-semibold flex items-center gap-2">
        <i class="fas fa-project-diagram"></i>
        Document Flow
      </h2>
      <span class="text-sm opacity-80">TO → Transfer → Receiving</span>
    </div>

    <div class="p-6 overflow-x-auto">
      <div v-if="loading" class="flex justify-center py-8">
        <div class="flex flex-col items-center gap-3">
          <i class="fas fa-spinner fa-spin text-3xl text-[#284b44]"></i>
          <span class="text-gray-500">Loading document flow...</span>
        </div>
      </div>

      <div v-else-if="error" class="text-center py-8">
        <i class="fas fa-exclamation-triangle text-3xl text-yellow-500 mb-2"></i>
        <p class="text-gray-600">{{ error }}</p>
        <button @click="loadFlow" class="mt-3 px-4 py-2 bg-[#284b44] text-white rounded-lg text-sm">Retry</button>
      </div>

      <div v-else class="flex items-center justify-center gap-2 min-w-max py-4">
        <template v-for="(node, index) in flowNodes" :key="node.doc_type + '-' + index">
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
            <div class="node-icon" :class="getIconBgClass(node)">
              <span class="text-2xl">{{ getNodeIcon(node.doc_type) }}</span>
            </div>
            <div class="node-label">{{ getNodeLabel(node.doc_type) }}</div>
            <div class="node-number" :class="node.doc_id ? 'text-blue-600' : 'text-gray-400'">
              {{ node.doc_number || 'Not Created' }}
            </div>
            <div v-if="node.doc_id || node.doc_status" class="node-status" :class="getStatusBadgeClass(node.doc_status)">
              {{ formatStatus(node.doc_status) }}
            </div>
            <div v-if="node.is_current" class="current-badge">
              <i class="fas fa-location-dot mr-1"></i>Current
            </div>
          </div>

          <div v-if="index < flowNodes.length - 1" class="arrow-connector">
            <div class="arrow-line" :class="getArrowClass(node, flowNodes[index + 1])"></div>
            <i class="fas fa-chevron-right arrow-icon" :class="getArrowClass(node, flowNodes[index + 1])"></i>
          </div>
        </template>
      </div>

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
    default: null
  },
  currentNumber: {
    type: String,
    default: ''
  },
  routeDocId: {
    type: [String, Number],
    default: null
  },
  linkedToId: {
    type: [String, Number],
    default: null
  }
});

const router = useRouter();
const flowNodes = ref([]);
const loading = ref(true);
const error = ref(null);

const docConfig = {
  TO: { label: 'Transfer Order', icon: '📋', route: '/homeportal/transfer-order-detail/' },
  TRS: { label: 'Stock Transfer', icon: '🚚', route: '/homeportal/transfer-sending/' },
  RECEIVED: { label: 'Received', icon: '✅', route: '/homeportal/transfer-sending/' }
};

const loadFlow = async () => {
  const rawId = props.docId ?? props.routeDocId;
  const currentId = rawId != null && rawId !== '' ? String(rawId) : null;
  const currentType = (props.docType || '').toUpperCase().trim();
  const normalizedType = currentType === 'TRANSFER' ? 'TRS' : currentType;

  if (!currentId) {
    buildFlowNodes([], normalizedType, null, null);
    loading.value = false;
    return;
  }

  loading.value = true;
  error.value = null;

  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    if (!ready) throw new Error('Database connection not available');

    let toId = null;
    let trsId = null;
    let toData = null;
    let trsData = null;

    if (normalizedType === 'TO') {
      toId = currentId;
      const { data: to } = await supabaseClient
        .from('transfer_orders')
        .select('id, transfer_number, to_number, status')
        .eq('id', toId)
        .single();
      toData = to;
      if (to) {
        const { data: st } = await supabaseClient
          .from('stock_transfers')
          .select('id, transfer_number, status')
          .eq('transfer_orders_id', toId)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();
        trsData = st;
        trsId = st?.id;
      }
    } else if (normalizedType === 'TRS') {
      trsId = currentId;
      const { data: st } = await supabaseClient
        .from('stock_transfers')
        .select('id, transfer_number, transfer_orders_id, status')
        .eq('id', trsId)
        .single();
      trsData = st;
      if (st?.transfer_orders_id) {
        toId = st.transfer_orders_id;
        const { data: to } = await supabaseClient
          .from('transfer_orders')
          .select('id, transfer_number, to_number, status')
          .eq('id', toId)
          .single();
        toData = to;
      }
    }

    buildFlowNodes([toData, trsData].filter(Boolean), normalizedType, currentId, props.currentNumber || (trsData?.transfer_number || toData?.transfer_number));
  } catch (err) {
    console.error('Transfer document flow error:', err);
    error.value = 'Failed to load document flow';
    buildFlowNodes([], normalizedType, currentId, props.currentNumber);
  } finally {
    loading.value = false;
  }
};

function buildFlowNodes(docs, currentType, currentId, currentNum) {
  const nodes = [];
  const toDoc = docs.find(d => d.transfer_orders_id === undefined && (d.to_number || d.transfer_number?.startsWith('TO-')));
  const trsDoc = docs.find(d => d.transfer_number?.startsWith('TRS-') || d.transfer_orders_id != null);

  const toData = toDoc || (trsDoc ? null : null);
  const trsData = trsDoc || docs.find(d => d.transfer_number?.startsWith('TRS-'));

  const toId = toData?.id || (trsData?.transfer_orders_id ? null : null);
  const trsId = trsData?.id;
  const isCompleted = trsData?.status === 'completed';

  nodes.push({
    doc_type: 'TO',
    doc_id: toId || null,
    doc_number: toData?.transfer_number || toData?.to_number || null,
    doc_status: toData?.status || 'not_created',
    is_current: currentType === 'TO',
    sequence_order: 1
  });

  nodes.push({
    doc_type: 'TRS',
    doc_id: trsId || null,
    doc_number: trsData?.transfer_number || null,
    doc_status: trsData?.status || 'not_created',
    is_current: currentType === 'TRS',
    sequence_order: 2
  });

  nodes.push({
    doc_type: 'RECEIVED',
    doc_id: isCompleted ? trsId : null,
    doc_number: isCompleted ? (trsData?.transfer_number || 'Completed') : null,
    doc_status: isCompleted ? 'completed' : 'not_created',
    is_current: false,
    sequence_order: 3
  });

  if (currentId) {
    const toIdx = nodes.findIndex(n => n.doc_type === 'TO');
    const trsIdx = nodes.findIndex(n => n.doc_type === 'TRS');
    if (currentType === 'TO' && toIdx >= 0 && !nodes[toIdx].doc_id) {
      nodes[toIdx].doc_id = currentId;
      nodes[toIdx].doc_number = currentNum || currentId;
      nodes[toIdx].is_current = true;
    }
    if (currentType === 'TRS' && trsIdx >= 0 && !nodes[trsIdx].doc_id) {
      nodes[trsIdx].doc_id = currentId;
      nodes[trsIdx].doc_number = currentNum || currentId;
      nodes[trsIdx].is_current = true;
    }
  }

  flowNodes.value = nodes;
}

const navigateToDocument = (node) => {
  if (!node.doc_id || node.is_current) return;
  const config = docConfig[node.doc_type];
  if (config?.route) router.push(config.route + node.doc_id);
};

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
  if (!status || status === 'not_created') return 'badge-default';
  const m = { completed: 'badge-success', approved: 'badge-success', draft: 'badge-warning', picked: 'badge-warning', in_transit: 'badge-info', arrived: 'badge-info' };
  return m[status] || 'badge-default';
};

const getArrowClass = (source, target) => {
  if (source.doc_id && target.doc_id) return 'arrow-active';
  if (source.doc_id && !target.doc_id) return 'arrow-next';
  return 'arrow-inactive';
};

const formatStatus = (status) => {
  if (!status || status === 'not_created') return 'Not Created';
  return status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
};

const getTooltip = (node) => {
  if (!node.doc_id) return `${getNodeLabel(node.doc_type)} - Not yet created`;
  return `${getNodeLabel(node.doc_type)}: ${node.doc_number}\nStatus: ${formatStatus(node.doc_status)}`;
};

onMounted(loadFlow);
watch(() => props.docId, loadFlow);
watch(() => props.docType, loadFlow);
watch(() => props.routeDocId, loadFlow);
watch(() => props.linkedToId, loadFlow);
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
.document-node.clickable { cursor: pointer; }
.document-node.clickable:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 25px -5px rgba(0, 0, 0, 0.1);
}
.document-node.disabled { cursor: not-allowed; opacity: 0.7; }
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
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 0.5rem;
}
.node-label { font-size: 0.75rem; font-weight: 600; color: #374151; margin-bottom: 0.25rem; }
.node-number { font-size: 0.875rem; font-weight: 600; }
.node-status {
  font-size: 0.65rem;
  padding: 0.15rem 0.4rem;
  border-radius: 9999px;
  margin-top: 0.25rem;
}
.badge-success { background: #dcfce7; color: #166534; }
.badge-warning { background: #fef3c7; color: #92400e; }
.badge-info { background: #dbeafe; color: #1e40af; }
.badge-default { background: #f3f4f6; color: #6b7280; }
.current-badge {
  position: absolute;
  top: -8px;
  right: -8px;
  background: #fbbf24;
  color: #78350f;
  font-size: 0.65rem;
  padding: 0.2rem 0.5rem;
  border-radius: 9999px;
  font-weight: 600;
}
.arrow-connector {
  display: flex;
  align-items: center;
  padding: 0 0.5rem;
}
.arrow-line {
  width: 24px;
  height: 2px;
  border-radius: 1px;
}
.arrow-icon { font-size: 0.75rem; margin-left: -12px; }
.arrow-active { background: #22c55e; color: #22c55e; }
.arrow-next { background: #fbbf24; color: #fbbf24; }
.arrow-inactive { background: #d1d5db; color: #9ca3af; }
</style>
