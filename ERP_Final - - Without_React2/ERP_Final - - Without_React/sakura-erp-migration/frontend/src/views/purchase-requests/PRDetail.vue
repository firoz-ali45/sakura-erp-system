<template>
  <div class="p-6 bg-gray-50 min-h-screen">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center h-64">
      <i class="fas fa-spinner fa-spin text-4xl text-[#284b44]"></i>
    </div>

    <template v-else-if="pr">
      <!-- Header -->
      <div class="bg-white rounded-lg shadow-md p-6 mb-4">
        <div class="flex justify-between items-start">
          <div>
            <div class="flex items-center gap-3 mb-2">
              <h1 class="text-2xl font-bold text-gray-800">{{ pr.pr_number }}</h1>
              <span :class="['px-3 py-1 rounded-full text-sm font-semibold', getStatusClass(pr.status)]">
                {{ formatStatus(pr.status) }}
              </span>
              <span :class="['px-3 py-1 rounded-full text-sm font-semibold', getPriorityClass(pr.priority)]">
                {{ formatPriority(pr.priority) }}
              </span>
            </div>
            <p class="text-gray-500">
              Created by {{ pr.requester_name }} on {{ formatDate(pr.created_at) }}
            </p>
          </div>
          <div class="flex gap-2">
            <button 
              @click="goBack"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
            >
              <i class="fas fa-arrow-left mr-2"></i>Back
            </button>
            <button 
              v-if="pr.status === 'draft'"
              @click="editPR"
              class="px-4 py-2 border border-[#284b44] text-[#284b44] rounded-lg hover:bg-[#284b44] hover:text-white transition-colors"
            >
              <i class="fas fa-edit mr-2"></i>Edit
            </button>
            <button 
              v-if="pr.status === 'draft'"
              @click="submitPR"
              class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
            >
              <i class="fas fa-paper-plane mr-2"></i>Submit
            </button>
            <button 
              v-if="canApprove"
              @click="approvePR"
              class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
            >
              <i class="fas fa-check mr-2"></i>Approve
            </button>
            <button 
              v-if="canReject"
              @click="showRejectModal = true"
              class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
            >
              <i class="fas fa-times mr-2"></i>Reject
            </button>
            <button 
              v-if="canConvertToPO"
              @click="navigateToConvert"
              class="px-4 py-2 text-white rounded-lg sakura-primary-btn"
            >
              <i class="fas fa-exchange-alt mr-2"></i>Convert to PO
            </button>
          </div>
        </div>
      </div>

      <!-- Info Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
        <div class="bg-white rounded-lg shadow-md p-4">
          <div class="text-sm text-gray-500">Department</div>
          <div class="text-lg font-semibold text-gray-800">{{ pr.department }}</div>
        </div>
        <div class="bg-white rounded-lg shadow-md p-4">
          <div class="text-sm text-gray-500">Cost Center</div>
          <div class="text-lg font-semibold text-gray-800">{{ pr.cost_center || 'N/A' }}</div>
        </div>
        <div class="bg-white rounded-lg shadow-md p-4">
          <div class="text-sm text-gray-500">Required Date</div>
          <div class="text-lg font-semibold" :class="isOverdue ? 'text-red-600' : 'text-gray-800'">
            {{ formatDate(pr.required_date) }}
            <span v-if="isOverdue" class="text-sm">(Overdue)</span>
          </div>
        </div>
        <div class="bg-white rounded-lg shadow-md p-4">
          <div class="text-sm text-gray-500">Estimated Total</div>
          <div class="text-lg font-bold" style="color: #284b44;">{{ formatCurrency(pr.estimated_total_value) }}</div>
        </div>
      </div>

      <!-- Main Content Grid -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-4">
        <!-- Items Table -->
        <div class="lg:col-span-2 bg-white rounded-lg shadow-md p-6">
          <h2 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
            <i class="fas fa-list text-[#284b44]"></i>
            Request Items ({{ pr.items?.length || 0 }})
          </h2>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">#</th>
                  <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">Item</th>
                  <th class="px-4 py-3 text-left text-sm font-semibold text-gray-700">SKU</th>
                  <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Qty</th>
                  <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Est. Price</th>
                  <th class="px-4 py-3 text-right text-sm font-semibold text-gray-700">Total</th>
                  <th class="px-4 py-3 text-center text-sm font-semibold text-gray-700">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <tr v-for="(item, index) in pr.items" :key="item.id" class="hover:bg-gray-50">
                  <td class="px-4 py-3 text-sm text-gray-500">{{ item.item_number || index + 1 }}</td>
                  <td class="px-4 py-3">
                    <div class="font-medium text-gray-900">{{ item.item_name }}</div>
                    <div v-if="item.inventory_item?.category" class="text-xs text-gray-500">
                      {{ item.inventory_item.category }}
                    </div>
                  </td>
                  <td class="px-4 py-3 text-sm text-gray-600 font-mono">
                    {{ item.inventory_item?.sku || item.item_code || '-' }}
                  </td>
                  <td class="px-4 py-3 text-sm text-gray-900 text-right">
                    {{ item.quantity }} {{ item.unit }}
                    <div v-if="item.quantity_ordered > 0" class="text-xs text-green-600">
                      {{ item.quantity_ordered }} ordered
                    </div>
                  </td>
                  <td class="px-4 py-3 text-sm text-gray-900 text-right">
                    {{ formatCurrency(item.estimated_price) }}
                  </td>
                  <td class="px-4 py-3 text-sm font-semibold text-gray-900 text-right">
                    {{ formatCurrency(item.quantity * item.estimated_price) }}
                  </td>
                  <td class="px-4 py-3 text-center">
                    <span :class="['px-2 py-1 rounded-full text-xs font-semibold', getItemStatusClass(item.status)]">
                      {{ formatItemStatus(item.status) }}
                    </span>
                  </td>
                </tr>
              </tbody>
              <tfoot class="bg-gray-50">
                <tr>
                  <td colspan="5" class="px-4 py-3 text-right font-semibold">Total:</td>
                  <td class="px-4 py-3 text-right font-bold text-lg" style="color: #284b44;">
                    {{ formatCurrency(pr.estimated_total_value) }}
                  </td>
                  <td></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-4">
          <!-- Status Timeline -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <i class="fas fa-history text-[#284b44]"></i>
              Status History
            </h3>
            <div class="space-y-4">
              <div 
                v-for="(history, index) in statusHistory" 
                :key="history.id"
                class="flex gap-3"
              >
                <div class="flex flex-col items-center">
                  <div :class="['w-3 h-3 rounded-full', index === 0 ? 'bg-[#284b44]' : 'bg-gray-300']"></div>
                  <div v-if="index < statusHistory.length - 1" class="w-0.5 h-full bg-gray-200 mt-1"></div>
                </div>
                <div class="pb-4">
                  <div class="font-medium text-gray-900">{{ formatStatus(history.new_status) }}</div>
                  <div class="text-sm text-gray-500">
                    {{ history.changed_by_name || 'System' }} - {{ formatDateTime(history.change_date) }}
                  </div>
                  <div v-if="history.change_reason" class="text-sm text-gray-600 mt-1">
                    {{ history.change_reason }}
                  </div>
                </div>
              </div>
              <div v-if="!statusHistory.length" class="text-gray-500 text-sm">No history available</div>
            </div>
          </div>

          <!-- Linked POs -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <i class="fas fa-file-invoice text-[#284b44]"></i>
              Linked Purchase Orders
              <span v-if="linkedPOs.length > 0" class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                {{ linkedPOs.length }}
              </span>
            </h3>
            <div v-if="linkedPOs.length > 0" class="space-y-3">
              <div 
                v-for="po in linkedPOs" 
                :key="po.po_id"
                @click="viewPO(po.po_id)"
                class="p-3 border border-gray-200 rounded-lg hover:bg-green-50 hover:border-green-300 cursor-pointer transition-all"
              >
                <div class="flex items-center justify-between mb-1">
                  <div class="font-medium text-blue-600 hover:text-blue-800">{{ po.po_number }}</div>
                  <i class="fas fa-external-link-alt text-gray-400 text-xs"></i>
                </div>
                <div class="text-sm text-gray-600">
                  <span v-if="po.supplier_name">{{ po.supplier_name }} • </span>
                  {{ po.item_count || po.total_items || 1 }} item(s)
                </div>
                <div class="flex items-center justify-between mt-2 text-xs">
                  <span class="text-gray-500">{{ formatDate(po.po_date || po.converted_at) }}</span>
                  <span class="font-semibold text-[#284b44]">{{ formatCurrency(po.po_total) }}</span>
                </div>
                <div v-if="po.receiving_status" class="mt-2">
                  <span :class="['px-2 py-0.5 rounded text-xs', getReceivingStatusClass(po.receiving_status)]">
                    {{ formatReceivingStatus(po.receiving_status) }}
                  </span>
                </div>
              </div>
            </div>
            <div v-else class="text-gray-500 text-sm text-center py-4">
              <i class="fas fa-shopping-cart text-2xl text-gray-300 mb-2 block"></i>
              No linked purchase orders
            </div>
          </div>

          <!-- Document Flow -->
          <div class="bg-white rounded-lg shadow-md p-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4 flex items-center gap-2">
              <i class="fas fa-project-diagram text-[#284b44]"></i>
              Document Flow
            </h3>
            <div class="space-y-2">
              <div 
                v-for="(doc, index) in documentFlow" 
                :key="index"
                @click="navigateToDocument(doc)"
                class="flex items-center gap-2 p-2 rounded-lg hover:bg-gray-50 cursor-pointer transition-colors border border-transparent hover:border-gray-200"
              >
                <div :class="['w-10 h-10 rounded-lg flex items-center justify-center text-white text-xs font-bold shadow-sm', getDocTypeColor(doc.doc_type)]">
                  {{ getDocTypeLabel(doc.doc_type) }}
                </div>
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-sm text-blue-600 hover:text-blue-800 truncate">
                    {{ doc.doc_number || getDocTypeName(doc.doc_type) }}
                  </div>
                  <div class="text-xs text-gray-500">{{ formatDate(doc.doc_date) }}</div>
                </div>
                <div class="flex items-center gap-2">
                  <span v-if="doc.doc_status" :class="['px-2 py-0.5 rounded text-xs whitespace-nowrap', getStatusClass(doc.doc_status)]">
                    {{ formatStatus(doc.doc_status) }}
                  </span>
                  <i class="fas fa-chevron-right text-gray-400 text-xs"></i>
                </div>
              </div>
              <div v-if="!documentFlow.length" class="text-gray-500 text-sm text-center py-4">
                <i class="fas fa-link text-2xl text-gray-300 mb-2 block"></i>
                No document flow available
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Notes Section -->
      <div v-if="pr.notes" class="bg-white rounded-lg shadow-md p-6">
        <h3 class="text-lg font-semibold text-gray-800 mb-2 flex items-center gap-2">
          <i class="fas fa-sticky-note text-[#284b44]"></i>
          Notes
        </h3>
        <p class="text-gray-700 whitespace-pre-line">{{ pr.notes }}</p>
      </div>

      <!-- =========================================================== -->
      <!-- DOCUMENT FLOW (SAP VBFA STYLE) - Full Chain Visualization -->
      <!-- =========================================================== -->
      <DocumentFlow 
        :key="(pr?.id || route.params.id) + '-docflow'"
        docType="pr" 
        :docId="pr?.id ?? route.params.id" 
        :currentNumber="pr?.pr_number ?? ''"
        :routeDocId="route.params.id"
      />

      <!-- =========================================================== -->
      <!-- ITEM-WISE DOCUMENT FLOW (SAP EKBE STYLE) - Bilkul Last -->
      <!-- =========================================================== -->
      <ItemFlow :key="(pr?.id || route.params.id) + '-' + (tracedGrnId || tracedPoId || 'pr')" :prId="pr?.id ?? route.params.id" :grnId="tracedGrnId" :poId="tracedPoId" />
    </template>

    <!-- Not Found -->
    <div v-else class="bg-white rounded-lg shadow-md p-12 text-center">
      <i class="fas fa-file-excel text-6xl text-gray-300 mb-4"></i>
      <h2 class="text-xl font-semibold text-gray-600">Purchase Request Not Found</h2>
      <p class="text-gray-500 mt-2">The requested PR could not be found.</p>
      <button @click="goBack" class="mt-4 px-6 py-2 sakura-primary-btn text-white rounded-lg">
        Back to List
      </button>
    </div>

    <!-- =========================================================== -->
    <!-- UNIFIED SAKURA MODAL - APPROVE CONFIRMATION -->
    <!-- =========================================================== -->
    <Teleport to="body">
      <Transition name="modal-fade">
        <div v-if="showApproveModal" class="sakura-modal-overlay" @click.self="showApproveModal = false">
          <div class="sakura-modal-container">
            <!-- Modal Header with Branding -->
            <div class="sakura-modal-header">
              <div class="flex items-center gap-3">
                <div class="sakura-modal-logo">
                  <img src="/sakura-logo.png" alt="Sakura" class="w-8 h-8" onerror="this.style.display='none'" />
                  <i class="fas fa-leaf text-white text-lg" v-if="!logoLoaded"></i>
                </div>
                <div>
                  <h3 class="text-lg font-bold text-white">Sakura ERP</h3>
                  <p class="text-xs text-green-200">Confirmation Required</p>
                </div>
              </div>
              <button @click="showApproveModal = false" class="sakura-modal-close">
                <i class="fas fa-times"></i>
              </button>
            </div>
            
            <!-- Modal Body -->
            <div class="sakura-modal-body">
              <div class="flex items-start gap-4">
                <div class="sakura-modal-icon bg-green-100 text-green-600">
                  <i class="fas fa-check-circle text-2xl"></i>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-semibold text-gray-800 mb-2">Approve Purchase Request?</h4>
                  <p class="text-gray-600 mb-3">
                    You are about to approve <strong class="text-[#284b44]">{{ pr?.pr_number }}</strong>
                  </p>
                  <div class="bg-gray-50 rounded-lg p-3 space-y-1 text-sm">
                    <div class="flex justify-between">
                      <span class="text-gray-500">Requested by:</span>
                      <span class="font-medium">{{ pr?.requester_name }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-500">Department:</span>
                      <span class="font-medium">{{ pr?.department }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-500">Total Value:</span>
                      <span class="font-bold text-[#284b44]">{{ formatCurrency(pr?.estimated_total_value) }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-500">Items:</span>
                      <span class="font-medium">{{ pr?.items?.length || 0 }} item(s)</span>
                    </div>
                  </div>
                  <!-- Optional Approval Notes -->
                  <div class="mt-4">
                    <label class="block text-sm font-medium text-gray-700 mb-1">Approval Notes (Optional)</label>
                    <textarea
                      v-model="approvalNotes"
                      rows="2"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                      placeholder="Add any notes for this approval..."
                    ></textarea>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Modal Footer -->
            <div class="sakura-modal-footer">
              <button 
                @click="showApproveModal = false" 
                class="sakura-btn-secondary"
                :disabled="approving"
              >
                Cancel
              </button>
              <button 
                @click="confirmApprove" 
                class="sakura-btn-success"
                :disabled="approving"
              >
                <i v-if="approving" class="fas fa-spinner fa-spin mr-2"></i>
                <i v-else class="fas fa-check mr-2"></i>
                {{ approving ? 'Approving...' : 'Approve PR' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- =========================================================== -->
    <!-- UNIFIED SAKURA MODAL - REJECT CONFIRMATION -->
    <!-- =========================================================== -->
    <Teleport to="body">
      <Transition name="modal-fade">
        <div v-if="showRejectModal" class="sakura-modal-overlay" @click.self="showRejectModal = false">
          <div class="sakura-modal-container">
            <!-- Modal Header with Branding -->
            <div class="sakura-modal-header bg-gradient-to-r from-red-600 to-red-700">
              <div class="flex items-center gap-3">
                <div class="sakura-modal-logo bg-red-800">
                  <i class="fas fa-exclamation-triangle text-white text-lg"></i>
                </div>
                <div>
                  <h3 class="text-lg font-bold text-white">Sakura ERP</h3>
                  <p class="text-xs text-red-200">Rejection Required</p>
                </div>
              </div>
              <button @click="showRejectModal = false" class="sakura-modal-close">
                <i class="fas fa-times"></i>
              </button>
            </div>
            
            <!-- Modal Body -->
            <div class="sakura-modal-body">
              <div class="flex items-start gap-4">
                <div class="sakura-modal-icon bg-red-100 text-red-600">
                  <i class="fas fa-times-circle text-2xl"></i>
                </div>
                <div class="flex-1">
                  <h4 class="text-lg font-semibold text-gray-800 mb-2">Reject Purchase Request?</h4>
                  <p class="text-gray-600 mb-3">
                    You are about to reject <strong class="text-red-600">{{ pr?.pr_number }}</strong>
                  </p>
                  <div class="bg-gray-50 rounded-lg p-3 space-y-1 text-sm mb-4">
                    <div class="flex justify-between">
                      <span class="text-gray-500">Requested by:</span>
                      <span class="font-medium">{{ pr?.requester_name }}</span>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-gray-500">Total Value:</span>
                      <span class="font-bold">{{ formatCurrency(pr?.estimated_total_value) }}</span>
                    </div>
                  </div>
                  <!-- Rejection Reason (Required) -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">
                      Rejection Reason <span class="text-red-500">*</span>
                    </label>
                    <textarea
                      v-model="rejectReason"
                      rows="3"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-red-500 focus:border-transparent"
                      placeholder="Please provide a reason for rejection (required)..."
                    ></textarea>
                    <p v-if="!rejectReason.trim()" class="text-xs text-red-500 mt-1">
                      <i class="fas fa-info-circle mr-1"></i>Reason is required to reject
                    </p>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Modal Footer -->
            <div class="sakura-modal-footer">
              <button 
                @click="showRejectModal = false" 
                class="sakura-btn-secondary"
                :disabled="rejecting"
              >
                Cancel
              </button>
              <button 
                @click="confirmReject" 
                class="sakura-btn-danger"
                :disabled="!rejectReason.trim() || rejecting"
              >
                <i v-if="rejecting" class="fas fa-spinner fa-spin mr-2"></i>
                <i v-else class="fas fa-times mr-2"></i>
                {{ rejecting ? 'Rejecting...' : 'Reject PR' }}
              </button>
            </div>
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, Teleport, Transition } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { 
  getPurchaseRequestById,
  getPRLinkedPOs,
  getPRDocumentFlow,
  submitPRForApproval,
  approvePurchaseRequest,
  rejectPurchaseRequest
} from '@/services/purchaseRequests';
import DocumentFlow from '@/components/common/DocumentFlow.vue';
import ItemFlow from '@/components/common/ItemFlow.vue';

const router = useRouter();
const route = useRoute();

// State
const loading = ref(true);
const pr = ref(null);
const linkedPOs = ref([]);
const documentFlow = ref([]);
const tracedPoId = ref(null);
const tracedGrnId = ref(null);

// Modal States
const showApproveModal = ref(false);
const showRejectModal = ref(false);
const approvalNotes = ref('');
const rejectReason = ref('');
const approving = ref(false);
const rejecting = ref(false);
const logoLoaded = ref(false);

// Computed
const statusHistory = computed(() => pr.value?.status_history || []);

const isOverdue = computed(() => {
  if (!pr.value?.required_date) return false;
  const required = new Date(pr.value.required_date);
  const today = new Date();
  return required < today && !['closed', 'cancelled', 'fully_ordered'].includes(pr.value.status);
});

const canApprove = computed(() => ['submitted', 'under_review'].includes(pr.value?.status));
const canReject = computed(() => ['submitted', 'under_review'].includes(pr.value?.status));

// DB-driven: fn_can_create_next_document('PR', pr_id) — no local logic
const canConvertToPO = ref(false);

// Calculate total remaining quantity for display
const totalRemainingQty = computed(() => {
  if (!pr.value?.items) return 0;
  return pr.value.items.reduce((sum, item) => {
    const ordered = parseFloat(item.quantity_ordered) || 0;
    const total = parseFloat(item.quantity) || 0;
    return sum + Math.max(0, total - ordered);
  }, 0);
});

// Calculate ordered percentage for progress display
// Calculate ordered percentage for progress display (Using DB fields)
const orderedPercentage = computed(() => {
  if (!pr.value?.items) return 0;
  
  const totalQty = pr.value.items.reduce((sum, item) => sum + (parseFloat(item.quantity) || 0), 0);
  const orderedQty = pr.value.items.reduce((sum, item) => sum + (parseFloat(item.quantity_ordered) || 0), 0);
  
  if (totalQty === 0) return 0;
  return Math.round((orderedQty / totalQty) * 100);
});

// Methods
const loadData = async () => {
  loading.value = true;
  tracedPoId.value = null;
  tracedGrnId.value = null;
  try {
    const prId = route.params.id;
    const [prData, pos, flow] = await Promise.all([
      getPurchaseRequestById(prId),
      getPRLinkedPOs(prId),
      getPRDocumentFlow(prId)
    ]);
    
    pr.value = prData;
    linkedPOs.value = pos || [];
    documentFlow.value = flow || [];
    const { canCreateNextDocument } = await import('@/services/erpViews.js');
    canConvertToPO.value = await canCreateNextDocument('PR', prId);
    
    // Trace PO/GRN for ItemFlow — DOCUMENT CHAIN ONLY (pr_po_linkage). NO item_id fallback.
    try {
      const { supabaseClient } = await import('@/services/supabase.js');
      let poId = pos?.[0]?.po_id ?? null;
      if (!poId) {
        const link = (await supabaseClient.from('pr_po_linkage').select('po_id').eq('pr_id', prId).limit(1)).data?.[0];
        poId = link?.po_id ?? null;
      }
      if (!poId && prData?.pr_number) {
        const link2 = (await supabaseClient.from('pr_po_linkage').select('po_id').eq('pr_number', (prData.pr_number || '').trim()).limit(1)).data?.[0];
        poId = link2?.po_id ?? null;
      }
      // NEVER link by item_id — only pr_po_linkage (document chain). If no linkage, PO/GRN stay null.
      if (poId) {
        tracedPoId.value = poId;
        const poIdNum = typeof poId === 'number' ? poId : (parseInt(poId, 10) || poId);
        let grnRes = (await supabaseClient.from('grn_inspections').select('id').eq('purchase_order_id', poIdNum).limit(1)).data;
        if (!grnRes?.length) {
          const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdNum).maybeSingle();
          if (poRow?.po_number) {
            grnRes = (await supabaseClient.from('grn_inspections').select('id').eq('purchase_order_number', (poRow.po_number || '').trim()).limit(1)).data;
          }
        }
        if (grnRes?.[0]?.id) tracedGrnId.value = grnRes[0].id;
      }
    } catch (_) {}
  } catch (error) {
    console.error('Error loading PR:', error);
    showNotification('Error loading purchase request', 'error');
  } finally {
    loading.value = false;
  }
};

const goBack = () => router.push('/homeportal/pr');

const editPR = () => router.push(`/homeportal/pr-create?edit=${pr.value.id}`);

const navigateToConvert = () => router.push(`/homeportal/pr-convert-to-po/${pr.value.id}`);

const viewPO = (poId) => router.push(`/homeportal/purchase-order-detail/${poId}`);

// Navigate to document based on type
const navigateToDocument = (doc) => {
  if (!doc) return;
  
  const docType = doc.doc_type?.toUpperCase();
  const docId = doc.doc_id;
  const docNumber = doc.doc_number;
  
  console.log('Navigating to document:', docType, docId, docNumber);
  
  switch (docType) {
    case 'PR':
      // Already on PR detail, no navigation needed
      break;
    case 'PO':
      if (docId) {
        router.push(`/homeportal/purchase-order-detail/${docId}`);
      }
      break;
    case 'GRN':
      if (docId) {
        router.push(`/homeportal/grn-detail/${docId}`);
      }
      break;
    case 'INV':
    case 'INVOICE':
      if (docId) {
        router.push(`/homeportal/purchasing-detail/${docId}`);
      }
      break;
    case 'PAYMENT':
      if (docId) {
        router.push(`/homeportal/ap-payment-detail/${docId}`);
      }
      break;
    default:
      console.log('Unknown document type:', docType);
  }
};

// Get document type display label
const getDocTypeLabel = (type) => {
  const labels = {
    'PR': 'PR',
    'PO': 'PO',
    'GRN': 'GRN',
    'INV': 'INV',
    'INVOICE': 'INV',
    'PAYMENT': 'PAY'
  };
  return labels[type?.toUpperCase()] || type?.substring(0, 3).toUpperCase() || '?';
};

// Get document type full name
const getDocTypeName = (type) => {
  const names = {
    'PR': 'Purchase Request',
    'PO': 'Purchase Order',
    'GRN': 'Goods Receipt Note',
    'INV': 'Purchasing Invoice',
    'INVOICE': 'Purchasing Invoice',
    'PAYMENT': 'AP Payment'
  };
  return names[type?.toUpperCase()] || type || 'Unknown';
};

const submitPR = async () => {
  try {
    const result = await submitPRForApproval(pr.value.id);
    if (result.success) {
      showNotification('PR submitted for approval', 'success');
      await loadData();
    } else {
      showNotification(result.error || 'Failed to submit', 'error');
    }
  } catch (error) {
    showNotification('Error submitting PR', 'error');
  }
};

// Open the approve modal (unified Sakura style)
const approvePR = () => {
  approvalNotes.value = '';
  showApproveModal.value = true;
};

// Confirm approval from modal
const confirmApprove = async () => {
  approving.value = true;
  try {
    console.log('============ APPROVE PR START ============');
    console.log('PR ID:', pr.value.id);
    console.log('PR Number:', pr.value.pr_number);
    console.log('Approval Notes:', approvalNotes.value);
    
    const result = await approvePurchaseRequest(pr.value.id, approvalNotes.value);
    console.log('Approve result:', result);
    
    if (result.success) {
      showNotification('Purchase Request approved successfully!', 'success');
      showApproveModal.value = false;
      await loadData();
    } else {
      console.error('Approval failed:', result.error);
      showNotification(result.error || 'Failed to approve PR', 'error');
    }
  } catch (error) {
    console.error('Exception approving PR:', error);
    showNotification('Error approving PR: ' + error.message, 'error');
  } finally {
    approving.value = false;
    console.log('============ APPROVE PR END ============');
  }
};

// Confirm rejection from modal
const confirmReject = async () => {
  if (!rejectReason.value.trim()) return;
  
  rejecting.value = true;
  try {
    console.log('============ REJECT PR START ============');
    console.log('PR ID:', pr.value.id);
    console.log('Rejection Reason:', rejectReason.value);
    
    const result = await rejectPurchaseRequest(pr.value.id, rejectReason.value);
    console.log('Reject result:', result);
    
    if (result.success) {
      showNotification('Purchase Request rejected', 'success');
      showRejectModal.value = false;
      rejectReason.value = '';
      await loadData();
    } else {
      console.error('Rejection failed:', result.error);
      showNotification(result.error || 'Failed to reject PR', 'error');
    }
  } catch (error) {
    console.error('Exception rejecting PR:', error);
    showNotification('Error rejecting PR: ' + error.message, 'error');
  } finally {
    rejecting.value = false;
    console.log('============ REJECT PR END ============');
  }
};

// Formatters
const formatStatus = (status) => {
  const map = {
    'draft': 'Draft', 'submitted': 'Submitted', 'under_review': 'Under Review',
    'approved': 'Approved', 'rejected': 'Rejected', 'partially_ordered': 'Partially Ordered',
    'fully_ordered': 'Fully Ordered', 'closed': 'Closed', 'cancelled': 'Cancelled'
  };
  return map[status] || status;
};

const getStatusClass = (status) => {
  const map = {
    'draft': 'bg-gray-100 text-gray-800', 'submitted': 'bg-yellow-100 text-yellow-800',
    'under_review': 'bg-orange-100 text-orange-800', 'approved': 'bg-green-100 text-green-800',
    'rejected': 'bg-red-100 text-red-800', 'partially_ordered': 'bg-blue-100 text-blue-800',
    'fully_ordered': 'bg-indigo-100 text-indigo-800', 'closed': 'bg-purple-100 text-purple-800'
  };
  return map[status] || 'bg-gray-100 text-gray-800';
};

const formatPriority = (p) => ({ low: 'Low', normal: 'Normal', high: 'High', urgent: 'Urgent', critical: 'Critical' }[p] || p);
const getPriorityClass = (p) => ({ low: 'bg-gray-100 text-gray-600', normal: 'bg-blue-100 text-blue-600', high: 'bg-yellow-100 text-yellow-600', urgent: 'bg-orange-100 text-orange-600', critical: 'bg-red-100 text-red-600' }[p] || 'bg-gray-100 text-gray-600');

const formatItemStatus = (s) => ({ open: 'Open', partially_converted: 'Partial', converted_to_po: 'Ordered', cancelled: 'Cancelled', blocked: 'Blocked' }[s] || s);
const getItemStatusClass = (s) => ({ open: 'bg-gray-100 text-gray-800', partially_converted: 'bg-yellow-100 text-yellow-800', converted_to_po: 'bg-green-100 text-green-800', cancelled: 'bg-red-100 text-red-800' }[s] || 'bg-gray-100 text-gray-800');

const getDocTypeColor = (type) => {
  const colors = {
    'PR': 'bg-blue-500',
    'PO': 'bg-green-600',
    'GRN': 'bg-purple-500',
    'INV': 'bg-orange-500',
    'INVOICE': 'bg-orange-500',
    'PAYMENT': 'bg-teal-500',
    'PAY': 'bg-teal-500'
  };
  return colors[type?.toUpperCase()] || 'bg-gray-500';
};

const formatReceivingStatus = (status) => {
  const map = {
    'not_received': 'Not Received',
    'partial_received': 'Partial Received',
    'fully_received': 'Fully Received'
  };
  return map[status] || status;
};

const getReceivingStatusClass = (status) => {
  const map = {
    'not_received': 'bg-gray-100 text-gray-700',
    'partial_received': 'bg-yellow-100 text-yellow-700',
    'fully_received': 'bg-green-100 text-green-700'
  };
  return map[status] || 'bg-gray-100 text-gray-700';
};

const formatCurrency = (amt) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR' }).format(amt || 0);
const formatDate = (d) => d ? new Date(d).toLocaleDateString('en-GB', { year: 'numeric', month: 'short', day: 'numeric' }) : '-';
const formatDateTime = (d) => d ? new Date(d).toLocaleString('en-GB', { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '-';

const showNotification = (msg, type) => window.showNotification?.(msg, type) || console.log(`[${type}] ${msg}`);

onMounted(() => loadData());
</script>

<style scoped>
.sakura-primary-btn { background-color: #284b44; transition: background-color 0.2s; }
.sakura-primary-btn:hover:not(:disabled) { background-color: #1f3a35; }

/* =========================================================== */
/* UNIFIED SAKURA MODAL STYLES */
/* =========================================================== */

.sakura-modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background-color: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  -webkit-backdrop-filter: blur(4px);
}

.sakura-modal-container {
  background: white;
  border-radius: 16px;
  width: 100%;
  max-width: 480px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25), 
              0 0 0 1px rgba(255, 255, 255, 0.1);
  overflow: hidden;
  animation: modalSlideIn 0.3s ease-out;
}

@keyframes modalSlideIn {
  from {
    opacity: 0;
    transform: scale(0.95) translateY(-20px);
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
}

.sakura-modal-header {
  background: linear-gradient(135deg, #284b44 0%, #1f3a35 100%);
  padding: 1.25rem 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sakura-modal-logo {
  width: 40px;
  height: 40px;
  background: rgba(255, 255, 255, 0.15);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.sakura-modal-close {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  opacity: 0.7;
  transition: all 0.2s;
  background: transparent;
  border: none;
  cursor: pointer;
}

.sakura-modal-close:hover {
  opacity: 1;
  background: rgba(255, 255, 255, 0.1);
}

.sakura-modal-body {
  padding: 1.5rem;
}

.sakura-modal-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.sakura-modal-footer {
  padding: 1rem 1.5rem;
  background: #f9fafb;
  border-top: 1px solid #e5e7eb;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.sakura-btn-secondary {
  padding: 0.625rem 1.25rem;
  border-radius: 8px;
  font-weight: 500;
  font-size: 0.875rem;
  border: 1px solid #d1d5db;
  background: white;
  color: #374151;
  cursor: pointer;
  transition: all 0.2s;
}

.sakura-btn-secondary:hover:not(:disabled) {
  background: #f3f4f6;
  border-color: #9ca3af;
}

.sakura-btn-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.sakura-btn-success {
  padding: 0.625rem 1.25rem;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  border: none;
  background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
  color: white;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 4px rgba(34, 197, 94, 0.3);
}

.sakura-btn-success:hover:not(:disabled) {
  background: linear-gradient(135deg, #16a34a 0%, #15803d 100%);
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(34, 197, 94, 0.4);
}

.sakura-btn-success:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

.sakura-btn-danger {
  padding: 0.625rem 1.25rem;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.875rem;
  border: none;
  background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
  color: white;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 2px 4px rgba(239, 68, 68, 0.3);
}

.sakura-btn-danger:hover:not(:disabled) {
  background: linear-gradient(135deg, #dc2626 0%, #b91c1c 100%);
  transform: translateY(-1px);
  box-shadow: 0 4px 8px rgba(239, 68, 68, 0.4);
}

.sakura-btn-danger:disabled {
  opacity: 0.6;
  cursor: not-allowed;
  transform: none;
}

/* Modal Transition */
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity 0.3s ease;
}

.modal-fade-enter-active .sakura-modal-container,
.modal-fade-leave-active .sakura-modal-container {
  transition: transform 0.3s ease, opacity 0.3s ease;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-from .sakura-modal-container,
.modal-fade-leave-to .sakura-modal-container {
  transform: scale(0.95) translateY(-20px);
}
</style>
