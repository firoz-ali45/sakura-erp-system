<template>
  <div class="bg-[#f0e1cd] p-6 min-h-screen">
    <!-- Header Section -->
    <div class="flex justify-between items-center mb-6">
      <div class="flex items-center gap-4">
        <button @click="goBack" class="text-blue-600 hover:text-blue-800 flex items-center gap-2">
          <i class="fas fa-arrow-left"></i>
          <span>{{ t('common.back') }}</span>
        </button>
        <div class="flex flex-col md:flex-row items-stretch md:items-center gap-2 md:gap-3">
          <h1 class="text-3xl font-bold text-gray-800">
            Purchasing Document ({{ invoice?.purchasing_number || 'Draft' }})
          </h1>
          <span 
            v-if="invoice"
            :class="getStatusClass(invoice.status)"
            class="px-3 py-1 rounded-full text-sm font-semibold"
          >
            {{ formatStatus(invoice.status) }}
          </span>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <button 
          v-if="isEditing && hasChanges"
          @click="saveChanges"
          :disabled="isSaving"
          class="px-6 py-2 bg-green-600 text-white rounded-lg flex items-center gap-2 font-semibold hover:bg-green-700 transition-all"
        >
          <i class="fas fa-save"></i>
          <span>{{ isSaving ? 'Saving...' : 'Save Changes' }}</span>
        </button>
        
        <button 
          @click="printInvoice"
          class="px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 flex items-center gap-2"
        >
          <i class="fas fa-print"></i>
          <span>{{ t('common.print') }}</span>
        </button>
        
        <!-- Draft Actions -->
        <template v-if="invoice?.status === 'draft'">
          <button 
            @click="submitForApproval"
            :disabled="!!paymentValidationError"
            :title="paymentValidationError || ''"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
            style="background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%);"
          >
            <i class="fas fa-paper-plane"></i>
            <span>Submit for Approval</span>
          </button>
        </template>
        
        <!-- Pending Approval Actions -->
        <template v-else-if="invoice?.status === 'pending_approval'">
          <button 
            @click="rejectInvoice"
            class="px-4 py-2 bg-white border border-red-300 rounded-lg hover:bg-red-50 flex items-center gap-2 text-red-600"
          >
            <i class="fas fa-times"></i>
            <span>Reject</span>
          </button>
          <button 
            @click="approveInvoice"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all"
            style="background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%);"
          >
            <i class="fas fa-check"></i>
            <span>Approve</span>
          </button>
        </template>
        
        <!-- Approved Actions -->
        <template v-else-if="invoice?.status === 'approved'">
          <button 
            @click="postToGL"
            class="px-6 py-2 text-white rounded-lg flex items-center gap-2 font-semibold shadow-lg hover:shadow-xl transform hover:scale-105 transition-all"
            style="background: linear-gradient(135deg, #1e3a34 0%, #284b44 50%, #2d5a4f 100%);"
          >
            <i class="fas fa-book"></i>
            <span>Post to GL</span>
          </button>
        </template>
      </div>
    </div>

    <!-- Loading State -->
    <div v-if="isLoading" class="bg-white rounded-lg shadow-md p-8 text-center">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-[#284b44] mx-auto mb-4"></div>
      <p class="text-gray-600">{{ t('common.loading') }}</p>
    </div>

    <!-- Invoice Content -->
    <div v-else-if="invoice" class="space-y-6">
      
      <!-- ============================================================ -->
      <!-- SECTION 1: VENDOR INVOICE ENTRY (SAP MIRO STYLE) -->
      <!-- ============================================================ -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-file-invoice mr-2"></i>
            Vendor Invoice Entry
          </h2>
          <span class="text-sm opacity-80">SAP MIRO Equivalent</span>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            
            <!-- Purchasing Document Number (Auto-generated, Readonly) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Purchasing Doc No. <span class="text-gray-400">(Auto)</span>
              </label>
              <div class="px-4 py-3 bg-gray-100 rounded-lg border border-gray-200 font-bold text-[#284b44]">
                {{ invoice.purchasing_number || 'PUR-XXXXXX' }}
              </div>
            </div>
            
            <!-- Vendor Invoice Number (Editable) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Vendor Invoice No. <span class="text-red-500">*</span>
              </label>
              <input 
                v-model="formData.vendor_invoice_number"
                type="text"
                placeholder="Enter vendor invoice #"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              />
            </div>
            
            <!-- Invoice Date (Editable) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Invoice Date <span class="text-red-500">*</span>
              </label>
              <input 
                v-model="formData.invoice_date"
                type="date"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              />
            </div>
            
            <!-- Due Date (Editable) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Due Date <span class="text-red-500">*</span>
              </label>
              <input 
                v-model="formData.due_date"
                type="date"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              />
            </div>
            
            <!-- Payment Terms (Auto-calculated) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Payment Terms <span class="text-gray-400">(Days)</span>
              </label>
              <div class="px-4 py-3 bg-blue-50 rounded-lg border border-blue-200 font-semibold text-blue-800">
                {{ calculatedPaymentTerms }} days
              </div>
            </div>
            
            <!-- Payment Method (AUTO-PAY types only — Bank Transfer via Finance → Payments) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Payment Method <span class="text-red-500">*</span>
              </label>
              <select 
                v-model="formData.payment_method"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              >
                <option value="CASH_ON_HAND">Cash on Hand</option>
                <option value="ATM_MARKET_PURCHASE">ATM / Market Purchase</option>
                <option value="FREE_SAMPLE">Free Sample</option>
                <option value="ONLINE_GATEWAY">Online Gateway</option>
              </select>
              <p class="text-xs text-gray-500 mt-1">Auto-pay: invoice marks as PAID on approval. For Bank Transfer use Finance → Payments.</p>
            </div>
            
            <!-- ATM selection (required for ATM / Market Purchase) -->
            <div v-if="formData.payment_method === 'ATM_MARKET_PURCHASE'" class="md:col-span-2">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                ATM <span class="text-red-500">*</span>
              </label>
              <select
                v-model="formData.atm_id"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              >
                <option value="">— Select ATM —</option>
                <option v-for="a in atms" :key="a.id" :value="a.id">{{ a.atm_name }} — {{ a.atm_number || '—' }}{{ (a.linked_bank_name || a.bank_name) ? ' · ' + (a.linked_bank_name || a.bank_name) : '' }}</option>
              </select>
              <p class="text-xs text-gray-500 mt-1">Required for ATM / Market Purchase. Configure in Finance → More → Payment Configuration.</p>
            </div>
            
            <!-- Online Gateway transaction reference -->
            <div v-if="formData.payment_method === 'ONLINE_GATEWAY'" class="md:col-span-2">
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Transaction Reference <span class="text-red-500">*</span>
              </label>
              <input
                v-model="formData.payment_reference"
                type="text"
                placeholder="e.g. gateway ref / transaction ID"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#284b44] focus:border-transparent"
                :disabled="!isEditable"
              />
            </div>
            
            <!-- Supplier -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Supplier
              </label>
              <div class="px-4 py-3 bg-gray-100 rounded-lg border border-gray-200">
                {{ invoice.supplier_name || 'N/A' }}
              </div>
            </div>
            
          </div>
          
          <!-- Auto Payment Warning -->
          <div v-if="isAutoPayMethod" class="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
            <div class="flex items-center gap-2 text-green-800">
              <i class="fas fa-info-circle"></i>
              <span class="font-semibold">Auto Payment:</span>
              <span>This payment method will automatically mark the invoice as PAID upon approval.</span>
            </div>
          </div>
          
          <!-- Free Sample Warning -->
          <div v-if="formData.payment_method === 'FREE_SAMPLE'" class="mt-4 p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
            <div class="flex items-center gap-2 text-yellow-800">
              <i class="fas fa-gift"></i>
              <span class="font-semibold">Free Sample:</span>
              <span>Invoice amounts will be set to zero. No payment required.</span>
            </div>
          </div>
          <!-- Validation: ATM / Online Gateway required -->
          <div v-if="paymentValidationError" class="mt-4 p-4 bg-red-50 border border-red-200 rounded-lg">
            <div class="flex items-center gap-2 text-red-800">
              <i class="fas fa-exclamation-triangle"></i>
              <span class="font-semibold">{{ paymentValidationError }}</span>
            </div>
          </div>
        </div>
      </div>
      
      <!-- ============================================================ -->
      <!-- SECTION 2: REFERENCE DOCUMENTS -->
      <!-- ============================================================ -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-link mr-2"></i>
            Reference Documents
          </h2>
        </div>
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div>
              <label class="text-sm text-gray-500">GRN Reference</label>
              <p class="font-semibold text-gray-800 mt-1">
                <span v-if="invoice.grn_number" class="text-blue-600 cursor-pointer hover:underline" @click="viewGRN">
                  {{ invoice.grn_number }}
                </span>
                <span v-else>N/A</span>
              </p>
            </div>
            <div>
              <label class="text-sm text-gray-500">PO Reference</label>
              <p class="font-semibold text-gray-800 mt-1">
                <span v-if="invoice.purchase_order_number" class="text-blue-600 cursor-pointer hover:underline" @click="viewPO">
                  {{ invoice.purchase_order_number }}
                </span>
                <span v-else>N/A</span>
              </p>
            </div>
            <div>
              <label class="text-sm text-gray-500">Receiving Location</label>
              <p class="font-semibold text-gray-800 mt-1">{{ invoice.receiving_location || '—' }}</p>
            </div>
            <div>
              <label class="text-sm text-gray-500">Created By</label>
              <p class="font-semibold text-gray-800 mt-1">{{ invoice.created_by || 'System' }}</p>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 3: ITEMS (Unit cost defaults from PO, editable) -->
      <!-- ============================================================ -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-boxes mr-2"></i>
            Items (Unit cost editable — defaults from PO)
          </h2>
          <span class="bg-white bg-opacity-20 px-3 py-1 rounded-full text-sm">
            {{ invoiceItems.length }} Items
          </span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Item Name</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Item Code</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Quantity</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Unit Cost (SAR)</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Total Cost</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <tr v-for="item in invoiceItems" :key="item.id" class="hover:bg-gray-50">
                <td class="px-6 py-4 text-sm text-gray-900 font-medium">{{ item.item_name || 'N/A' }}</td>
                <td class="px-6 py-4 text-sm text-gray-600">{{ item.item_code || 'N/A' }}</td>
                <td class="px-6 py-4 text-sm text-gray-900 text-right font-semibold">{{ formatNumber(item.quantity) }}</td>
                <td class="px-6 py-4 text-sm text-right">
                  <input
                    v-if="isEditable"
                    v-model.number="item.unit_cost"
                    type="number"
                    step="0.01"
                    min="0"
                    class="w-28 px-2 py-1.5 border border-gray-300 rounded text-right focus:ring-2 focus:ring-[#284b44]"
                    @blur="recalcItemTotal(item); persistItemCost(item)"
                  />
                  <span v-else>{{ formatCurrency(item.unit_cost) }}</span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-900 text-right font-bold">{{ formatCurrency(itemTotal(item)) }}</td>
              </tr>
              <tr v-if="invoiceItems.length === 0">
                <td colspan="5" class="px-6 py-8 text-center text-gray-500">No items found</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="isEditable" class="px-6 pb-4 text-xs text-gray-500">Edit unit cost and tab out to save. Totals recalculate automatically. Currency: SAR only.</p>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 4: FINANCIAL SUMMARY -->
      <!-- ============================================================ -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-calculator mr-2"></i>
            Financial Summary
          </h2>
        </div>
        <div class="p-6">
          <div class="max-w-md ml-auto space-y-3">
            <div class="flex justify-between items-center py-2 border-b border-gray-200">
              <span class="text-gray-600">Subtotal</span>
              <span class="font-semibold">{{ formatCurrency(invoice.subtotal || 0) }}</span>
            </div>
            <div class="flex justify-between items-center py-2 border-b border-gray-200">
              <span class="text-gray-600">Tax ({{ invoice.tax_rate || 15 }}%)</span>
              <span class="font-semibold">{{ formatCurrency(invoice.tax_amount || 0) }}</span>
            </div>
            <div v-if="invoice.discount_amount > 0" class="flex justify-between items-center py-2 border-b border-gray-200">
              <span class="text-gray-600">Discount</span>
              <span class="font-semibold text-red-600">-{{ formatCurrency(invoice.discount_amount) }}</span>
            </div>
            <div class="flex justify-between items-center py-3 bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white rounded-lg px-4 mt-4">
              <span class="text-lg font-semibold">Grand Total</span>
              <span class="text-2xl font-bold">{{ formatCurrency(invoice.grand_total || 0) }}</span>
            </div>
            
            <!-- Payment Status Summary -->
            <div class="mt-4 pt-4 border-t border-gray-200">
              <div class="flex justify-between items-center py-2">
                <span class="text-gray-600">Paid Amount</span>
                <span class="font-semibold text-green-600">{{ formatCurrency(invoice.paid_amount || 0) }}</span>
              </div>
              <div class="flex justify-between items-center py-2">
                <span class="text-gray-600">Outstanding</span>
                <span class="font-semibold" :class="outstandingAmount > 0 ? 'text-red-600' : 'text-green-600'">
                  {{ formatCurrency(outstandingAmount) }}
                </span>
              </div>
              <div class="flex justify-between items-center py-2">
                <span class="text-gray-600">Payment Status</span>
                <span :class="getPaymentStatusClass(invoice.payment_status)" class="px-3 py-1 rounded-full text-sm font-semibold">
                  {{ formatPaymentStatus(invoice.payment_status) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 5: FINANCE PAYMENT (SAP F-53 / F110) -->
      <!-- Only show for BANK_TRANSFER, ONLINE_GATEWAY, CREDIT -->
      <!-- ============================================================ -->
      <div v-if="showFinancePaymentSection" class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-purple-700 to-purple-900 text-white px-6 py-4 flex justify-between items-center">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-money-check-alt mr-2"></i>
            Finance Payment (AP Payment)
          </h2>
          <span class="text-sm opacity-80">SAP F-53 / F110 Equivalent</span>
        </div>
        <div class="p-6">
          <!-- Payment History -->
          <div v-if="payments.length > 0" class="mb-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-3">Payment History</h3>
            <table class="w-full">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Payment #</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Channel</th>
                  <th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase">Reference</th>
                  <th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
                  <th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <tr v-for="payment in payments" :key="payment.id" class="hover:bg-gray-50">
                  <td class="px-4 py-3 text-sm font-semibold text-purple-600">{{ payment.payment_number }}</td>
                  <td class="px-4 py-3 text-sm">{{ formatDate(payment.payment_date) }}</td>
                  <td class="px-4 py-3 text-sm">{{ formatPaymentChannel(payment.payment_channel) }}</td>
                  <td class="px-4 py-3 text-sm">{{ payment.reference_number || '-' }}</td>
                  <td class="px-4 py-3 text-sm text-right font-semibold text-green-600">{{ formatCurrency(payment.payment_amount) }}</td>
                  <td class="px-4 py-3 text-sm text-center">
                    <span class="px-2 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                      {{ payment.status }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          
          <!-- Add Payment Form - DB-driven: show only when fn_can_create_next_document('PURCHASE', id) is true -->
          <div v-if="canCreatePayment" class="border-t pt-6">
            <h3 class="text-lg font-semibold text-gray-800 mb-4">Record New Payment</h3>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Payment Date</label>
                <input 
                  v-model="newPayment.payment_date"
                  type="date"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Amount</label>
                <input 
                  v-model.number="newPayment.payment_amount"
                  type="number"
                  step="0.01"
                  :max="outstandingAmount"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Payment Channel</label>
                <select 
                  v-model="newPayment.payment_channel"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                >
                  <option value="BANK_TRANSFER">Bank Transfer</option>
                  <option value="CASH">Cash</option>
                  <option value="CARD">Card</option>
                  <option value="ONLINE">Online</option>
                  <option value="CHECK">Check</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Reference #</label>
                <input 
                  v-model="newPayment.reference_number"
                  type="text"
                  placeholder="Transaction/Check #"
                  class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500"
                />
              </div>
            </div>
            <div class="mt-4 flex justify-end">
              <button 
                @click="recordPayment"
                :disabled="!canRecordPayment"
                class="px-6 py-2 bg-purple-600 text-white rounded-lg flex items-center gap-2 font-semibold hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <i class="fas fa-plus"></i>
                <span>Record Payment</span>
              </button>
            </div>
          </div>
          
          <!-- Fully Paid Message -->
          <div v-if="invoice.payment_status === 'paid'" class="text-center py-8">
            <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <i class="fas fa-check-circle text-green-600 text-4xl"></i>
            </div>
            <h3 class="text-xl font-semibold text-green-800">Invoice Fully Paid</h3>
            <p class="text-gray-500 mt-2">Paid on {{ formatDate(invoice.paid_date) }}</p>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 6: DOCUMENT FLOW (SAP VBFA) -->
      <!-- ============================================================ -->
      <DocumentFlow 
        docType="invoice" 
        :docId="invoice.id" 
        :currentNumber="invoice.purchasing_number"
        :routeDocId="route.params.id"
        :linkedPrId="linkedPrId"
      />

      <!-- ============================================================ -->
      <!-- SECTION 7: AUDIT TRAIL -->
      <!-- ============================================================ -->
      <div class="bg-white rounded-lg shadow-md overflow-hidden">
        <div class="bg-gradient-to-r from-[#284b44] to-[#1e3a35] text-white px-6 py-4">
          <h2 class="text-xl font-semibold">
            <i class="fas fa-history mr-2"></i>
            Audit Trail
          </h2>
        </div>
        <div class="p-6">
          <div class="space-y-4">
            <div class="flex items-center gap-4">
              <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                <i class="fas fa-plus text-blue-600"></i>
              </div>
              <div>
                <p class="font-semibold text-gray-800">Created</p>
                <p class="text-sm text-gray-500">{{ formatDateTime(invoice.created_at) }} by {{ invoice.created_by || 'System' }}</p>
              </div>
            </div>
            <div v-if="invoice.approved_at" class="flex items-center gap-4">
              <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
                <i class="fas fa-check text-green-600"></i>
              </div>
              <div>
                <p class="font-semibold text-gray-800">Approved</p>
                <p class="text-sm text-gray-500">{{ formatDateTime(invoice.approved_at) }} by {{ invoice.approved_by || 'N/A' }}</p>
              </div>
            </div>
            <div v-if="invoice.posted_at" class="flex items-center gap-4">
              <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
                <i class="fas fa-book text-purple-600"></i>
              </div>
              <div>
                <p class="font-semibold text-gray-800">Posted to GL</p>
                <p class="text-sm text-gray-500">{{ formatDateTime(invoice.posted_at) }} by {{ invoice.posted_by || 'N/A' }}</p>
              </div>
            </div>
            <div v-if="invoice.paid_date" class="flex items-center gap-4">
              <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
                <i class="fas fa-dollar-sign text-green-600"></i>
              </div>
              <div>
                <p class="font-semibold text-gray-800">Fully Paid</p>
                <p class="text-sm text-gray-500">{{ formatDate(invoice.paid_date) }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- SECTION 8: ITEM-WISE DOCUMENT FLOW (SAP EKBE) - Bilkul Last -->
      <!-- ============================================================ -->
      <ItemFlow v-if="invoice" :prId="linkedPrId" :poId="tracedPoId || invoice.purchase_order_id" :grnId="invoice.grn_id" />
    </div>

    <!-- Not Found State -->
    <div v-else class="bg-white rounded-lg shadow-md p-8 text-center">
      <div class="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <i class="fas fa-exclamation-triangle text-red-500 text-3xl"></i>
      </div>
      <h3 class="text-lg font-semibold text-gray-800 mb-2">Purchasing Document Not Found</h3>
      <p class="text-gray-500 mb-4">The requested document could not be found.</p>
      <button @click="goBack" class="px-6 py-2 bg-[#284b44] text-white rounded-lg hover:bg-[#1e3a35]">
        Back to List
      </button>
    </div>
    
    <!-- Notification Toast -->
    <div v-if="notification.show" 
         :class="notification.type === 'success' ? 'bg-green-500' : notification.type === 'error' ? 'bg-red-500' : 'bg-blue-500'"
         class="fixed bottom-4 right-4 px-6 py-3 text-white rounded-lg shadow-lg z-50 flex items-center gap-2">
      <i :class="notification.type === 'success' ? 'fas fa-check-circle' : notification.type === 'error' ? 'fas fa-times-circle' : 'fas fa-info-circle'"></i>
      <span>{{ notification.message }}</span>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { asUuidOrNull } from '@/utils/uuidUtils';
import { useAuthStore } from '@/stores/auth';
import DocumentFlow from '@/components/common/DocumentFlow.vue';
import ItemFlow from '@/components/common/ItemFlow.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const authStore = useAuthStore();

// State
const invoice = ref(null);
const linkedPrId = ref(null);
const tracedPoId = ref(null);
const invoiceItems = ref([]);
const payments = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const isEditing = ref(true);

// Form Data (for editable fields)
const formData = ref({
  vendor_invoice_number: '',
  invoice_date: '',
  due_date: '',
  payment_method: 'CASH_ON_HAND',
  atm_id: '',
  payment_reference: ''
});

// ATM master (for ATM / Market Purchase)
const atms = ref([]);

// Original data for change detection
const originalData = ref({});

// DB-driven: show "Record Payment" only when fn_can_create_next_document('PURCHASE', id) is true
const canCreatePayment = ref(false);

// New Payment Form
const newPayment = ref({
  payment_date: new Date().toISOString().split('T')[0],
  payment_amount: 0,
  payment_channel: 'BANK_TRANSFER',
  reference_number: ''
});

// Notification
const notification = ref({ show: false, message: '', type: 'info' });

// Computed Properties
const isOverdue = computed(() => {
  if (!invoice.value?.due_date || invoice.value?.payment_status === 'paid') return false;
  const today = new Date().toISOString().split('T')[0];
  return invoice.value.due_date < today;
});

const isEditable = computed(() => {
  return invoice.value?.status === 'draft';
});

const hasChanges = computed(() => {
  return JSON.stringify(formData.value) !== JSON.stringify(originalData.value);
});

const calculatedPaymentTerms = computed(() => {
  if (!formData.value.invoice_date || !formData.value.due_date) return 30;
  const invoiceDate = new Date(formData.value.invoice_date);
  const dueDate = new Date(formData.value.due_date);
  const diffTime = dueDate - invoiceDate;
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  return diffDays > 0 ? diffDays : 0;
});

const isAutoPayMethod = computed(() => {
  return ['CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE', 'ONLINE_GATEWAY'].includes(formData.value.payment_method);
});

const showFinancePaymentSection = computed(() => false);

// ATM payment requires ATM selection; Online Gateway requires transaction reference
const paymentValidationError = computed(() => {
  if (formData.value.payment_method === 'ATM_MARKET_PURCHASE' && !formData.value.atm_id) return 'Select an ATM for ATM / Market Purchase.';
  if (formData.value.payment_method === 'ONLINE_GATEWAY' && !(formData.value.payment_reference || '').trim()) return 'Enter transaction reference for Online Gateway.';
  return null;
});

// Item total (live): quantity * unit_cost
function itemTotal(item) {
  const q = Number(item.quantity) || 0;
  const u = Number(item.unit_cost) || 0;
  return q * u;
}
function recalcItemTotal(item) {
  const total = itemTotal(item);
  item.total_cost = total;
}
async function persistItemCost(item) {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const total = itemTotal(item);
    await supabaseClient.from('purchasing_invoice_items').update({
      unit_cost: Number(item.unit_cost) || 0,
      total_cost: total
    }).eq('id', item.id);
    item.total_cost = total;
    await loadInvoice();
  } catch (e) {
    console.error('Persist item cost:', e);
    showNotification('Failed to save item cost.', 'error');
  }
}

const outstandingAmount = computed(() => {
  if (!invoice.value) return 0;
  return (invoice.value.grand_total || 0) - (invoice.value.paid_amount || 0);
});

const canRecordPayment = computed(() => {
  return newPayment.value.payment_date && 
         newPayment.value.payment_amount > 0 && 
         newPayment.value.payment_amount <= outstandingAmount.value;
});

// Watchers

// Load invoice data
const loadInvoice = async () => {
  isLoading.value = true;
  const invoiceId = route.params.id;
  
  try {
    const { ensureSupabaseReady, supabaseClient } = await import('@/services/supabase.js');
    const ready = await ensureSupabaseReady();
    
    if (!ready) {
      console.error('Supabase not ready');
      invoice.value = null;
      return;
    }
    
    console.log('📋 Loading purchasing document:', invoiceId);
    
    // Load invoice header
    const { data: invoiceData, error: invoiceError } = await supabaseClient
      .from('purchasing_invoices')
      .select('*')
      .eq('id', invoiceId)
      .single();
    
    if (invoiceError) {
      console.error('❌ Error loading invoice:', invoiceError);
      invoice.value = null;
      return;
    }
    
    // Fix supplier_name if it's JSON
    if (invoiceData.supplier_name && typeof invoiceData.supplier_name === 'object') {
      invoiceData.supplier_name = invoiceData.supplier_name.name || 'N/A';
    }
    if (typeof invoiceData.supplier_name === 'string' && invoiceData.supplier_name.startsWith('{')) {
      try {
        const parsed = JSON.parse(invoiceData.supplier_name);
        invoiceData.supplier_name = parsed.name || 'N/A';
      } catch (e) {}
    }
    
    // If no supplier name, fetch from suppliers table
    if ((!invoiceData.supplier_name || invoiceData.supplier_name === 'N/A') && invoiceData.supplier_id) {
      const { data: supplierData } = await supabaseClient
        .from('suppliers')
        .select('name')
        .eq('id', invoiceData.supplier_id)
        .single();
      if (supplierData) {
        invoiceData.supplier_name = supplierData.name;
      }
    }
    
    invoice.value = invoiceData;

    const { canCreateNextDocument } = await import('@/services/erpViews.js');
    const rpcResult = await canCreateNextDocument('PURCHASE', invoiceData.id);
    canCreatePayment.value = rpcResult;
    console.log('RPC fn_can_create_next_document', { docType: 'PURCHASE', purchaseId: invoiceData.id, result: rpcResult });
    
    // Initialize form data
    formData.value = {
      vendor_invoice_number: invoiceData.vendor_invoice_number || '',
      invoice_date: invoiceData.invoice_date || new Date().toISOString().split('T')[0],
      due_date: invoiceData.due_date || '',
      payment_method: ['CASH_ON_HAND', 'ATM_MARKET_PURCHASE', 'FREE_SAMPLE', 'ONLINE_GATEWAY'].includes(invoiceData.payment_method)
        ? invoiceData.payment_method : 'CASH_ON_HAND',
      atm_id: invoiceData.atm_id || '',
      payment_reference: invoiceData.payment_reference || ''
    };
    originalData.value = { ...formData.value };
    
    // Load invoice items
    const { data: itemsData, error: itemsError } = await supabaseClient
      .from('purchasing_invoice_items')
      .select('*')
      .eq('purchasing_invoice_id', invoiceId);
    
    if (!itemsError) {
      invoiceItems.value = itemsData || [];
      // Default unit_cost from PO if 0 (PUR cost flow: default from PO)
      const poId = invoiceData.purchase_order_id;
      if (poId && invoiceItems.value.some(i => !Number(i.unit_cost))) {
        const { data: poItems } = await supabaseClient.from('purchase_order_items').select('item_id, unit_price').eq('purchase_order_id', poId);
        const poPriceByItem = (poItems || []).reduce((acc, r) => { acc[r.item_id] = Number(r.unit_price) || 0; return acc; }, {});
        invoiceItems.value.forEach(i => {
          if (!Number(i.unit_cost) && i.item_id && poPriceByItem[i.item_id] > 0) {
            i.unit_cost = poPriceByItem[i.item_id];
            i.total_cost = (Number(i.quantity) || 0) * i.unit_cost;
          }
        });
      }
    }
    
    // Load payments
    const { data: paymentsData, error: paymentsError } = await supabaseClient
      .from('ap_payments')
      .select('*')
      .eq('purchasing_invoice_id', invoiceId)
      .order('payment_date', { ascending: false });
    
    if (!paymentsError) {
      payments.value = paymentsData || [];
    }
    
    console.log('✅ Document loaded:', invoiceData.purchasing_number);

    // Trace back to PR for ItemFlow and DocumentFlow
    linkedPrId.value = null;
    tracedPoId.value = null;
    try {
      let currentPoId = invoice.value.purchase_order_id;
      
      // If no PO ID, try GRN or purchase_order_number
      if (!currentPoId && invoice.value.grn_id) {
        const { data: grn } = await supabaseClient
          .from('grn_inspections')
          .select('purchase_order_id, purchase_order_number')
          .eq('id', invoice.value.grn_id)
          .single();
        if (grn?.purchase_order_id) currentPoId = grn.purchase_order_id;
        else if (grn?.purchase_order_number) {
          const { data: po } = await supabaseClient.from('purchase_orders').select('id').eq('po_number', grn.purchase_order_number.trim()).maybeSingle();
          if (po?.id) currentPoId = po.id;
        }
      }
      if (!currentPoId && invoice.value.purchase_order_number) {
        const { data: po } = await supabaseClient.from('purchase_orders').select('id').eq('po_number', invoice.value.purchase_order_number.trim()).maybeSingle();
        if (po?.id) currentPoId = po.id;
      }
      
      if (currentPoId) {
        const poIdNum = typeof currentPoId === 'number' ? currentPoId : (parseInt(currentPoId, 10) || currentPoId);
        let linkData = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_id', poIdNum).limit(1)).data;
        if (!linkData?.length && (invoice.value?.purchase_order_number || invoice.value?.grn_number)) {
          const poNum = invoice.value.purchase_order_number?.trim();
          if (poNum) {
            linkData = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', poNum).limit(1)).data;
          }
        }
        if (!linkData?.length) {
          const { data: poRow } = await supabaseClient.from('purchase_orders').select('po_number').eq('id', poIdNum).maybeSingle();
          if (poRow?.po_number) {
            linkData = (await supabaseClient.from('pr_po_linkage').select('pr_id').eq('po_number', (poRow.po_number || '').trim()).limit(1)).data;
          }
        }
        if (linkData?.length) {
          linkedPrId.value = linkData[0].pr_id;
          console.log('🔗 Linked PR found:', linkedPrId.value);
        }
        tracedPoId.value = currentPoId;
      }
    } catch(e) { 
      console.warn('Trace back failed', e); 
    }
    
  } catch (error) {
    console.error('❌ Error loading document:', error);
    invoice.value = null;
  } finally {
    isLoading.value = false;
  }
};

// Save Changes
const saveChanges = async () => {
  if (!hasChanges.value) return;
  
  isSaving.value = true;
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const updateData = {
      vendor_invoice_number: formData.value.vendor_invoice_number,
      invoice_date: formData.value.invoice_date,
      due_date: formData.value.due_date,
      payment_terms_days: calculatedPaymentTerms.value,
      payment_method: formData.value.payment_method,
      atm_id: formData.value.atm_id || null,
      payment_reference: (formData.value.payment_reference || '').trim() || null,
      updated_at: new Date().toISOString()
    };
    
    const { error } = await supabaseClient
      .from('purchasing_invoices')
      .update(updateData)
      .eq('id', invoice.value.id);
    
    if (error) throw error;
    
    originalData.value = { ...formData.value };
    showNotification('Changes saved successfully.', 'success');
    await loadInvoice();
    
  } catch (error) {
    console.error('Error saving:', error);
    showNotification('Error saving changes: ' + error.message, 'error');
  } finally {
    isSaving.value = false;
  }
};

// Record Payment
const recordPayment = async () => {
  if (!canRecordPayment.value) return;
  
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const paymentData = {
      purchasing_invoice_id: invoice.value.id,
      payment_date: newPayment.value.payment_date,
      payment_amount: newPayment.value.payment_amount,
      payment_channel: newPayment.value.payment_channel,
      reference_number: newPayment.value.reference_number,
      created_by: asUuidOrNull(authStore.user?.id)
    };
    
    const { error } = await supabaseClient
      .from('ap_payments')
      .insert(paymentData);
    
    if (error) throw error;
    
    // Reset form
    newPayment.value = {
      payment_date: new Date().toISOString().split('T')[0],
      payment_amount: 0,
      payment_channel: 'BANK_TRANSFER',
      reference_number: ''
    };
    
    showNotification('Payment recorded successfully.', 'success');
    await loadInvoice();
    const { forceSystemSync } = await import('@/services/erpViews.js');
    await forceSystemSync();
  } catch (error) {
    console.error('Error recording payment:', error);
    showNotification('Error recording payment: ' + error.message, 'error');
  }
};

// Navigation
const goBack = () => router.push('/homeportal/purchasing');
const viewGRN = () => invoice.value?.grn_id && router.push(`/homeportal/grn-detail/${invoice.value.grn_id}`);
const viewPO = () => invoice.value?.purchase_order_id && router.push(`/homeportal/purchase-order-detail/${invoice.value.purchase_order_id}`);

// Actions
const submitForApproval = async () => {
  if (paymentValidationError.value) return;
  // First save any changes
  if (hasChanges.value) await saveChanges();
  
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const { error } = await supabaseClient
      .from('purchasing_invoices')
      .update({ 
        status: 'pending_approval',
        updated_at: new Date().toISOString()
      })
      .eq('id', invoice.value.id);
    
    if (error) throw error;
    
    showNotification('Submitted for approval.', 'success');
    await loadInvoice();
  } catch (error) {
    showNotification('Error: ' + error.message, 'error');
  }
};

const approveInvoice = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const { error } = await supabaseClient
      .from('purchasing_invoices')
      .update({ 
        status: 'approved',
        approved_by: asUuidOrNull(authStore.user?.id),
        approved_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', invoice.value.id);
    
    if (error) throw error;
    
    showNotification('Invoice approved.', 'success');
    await loadInvoice();
  } catch (error) {
    showNotification('Error: ' + error.message, 'error');
  }
};

const rejectInvoice = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const { error } = await supabaseClient
      .from('purchasing_invoices')
      .update({ 
        status: 'draft',
        updated_at: new Date().toISOString()
      })
      .eq('id', invoice.value.id);
    
    if (error) throw error;
    
    showNotification('Invoice rejected, returned to draft.', 'info');
    await loadInvoice();
  } catch (error) {
    showNotification('Error: ' + error.message, 'error');
  }
};

const postToGL = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    
    const { error } = await supabaseClient
      .from('purchasing_invoices')
      .update({ 
        status: 'posted',
        posted_by: asUuidOrNull(authStore.user?.id),
        posted_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', invoice.value.id);
    
    if (error) throw error;
    
    showNotification('Posted to General Ledger.', 'success');
    await loadInvoice();
  } catch (error) {
    showNotification('Error: ' + error.message, 'error');
  }
};

const printInvoice = () => window.print();

// Formatters
const formatDate = (date) => date ? new Date(date).toLocaleDateString('en-GB') : '—';
const formatDateTime = (date) => date ? new Date(date).toLocaleString('en-GB') : '—';
const formatNumber = (num) => num?.toLocaleString() || '0';
const formatCurrency = (amount) => new Intl.NumberFormat('en-US', { style: 'currency', currency: 'SAR' }).format(amount || 0);

const formatStatus = (status) => {
  const map = { 'draft': 'Draft', 'pending_approval': 'Pending Approval', 'approved': 'Approved', 'posted': 'Posted' };
  return map[status] || status;
};

const formatPaymentStatus = (status) => {
  const map = { 'unpaid': 'Unpaid', 'partial': 'Partial', 'paid': 'Paid' };
  return map[status] || status;
};

const formatPaymentChannel = (channel) => {
  const map = { 'BANK_TRANSFER': 'Bank Transfer', 'CASH': 'Cash', 'CARD': 'Card', 'ONLINE': 'Online', 'CHECK': 'Check' };
  return map[channel] || channel;
};

const getStatusClass = (status) => {
  const classes = {
    'draft': 'bg-yellow-100 text-yellow-800',
    'pending_approval': 'bg-blue-100 text-blue-800',
    'approved': 'bg-green-100 text-green-800',
    'posted': 'bg-purple-100 text-purple-800'
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
};

const getPaymentStatusClass = (status) => {
  const classes = { 'unpaid': 'bg-red-100 text-red-800', 'partial': 'bg-yellow-100 text-yellow-800', 'paid': 'bg-green-100 text-green-800' };
  return classes[status] || 'bg-gray-100 text-gray-800';
};

// Notification
const showNotification = (message, type = 'info') => {
  notification.value = { show: true, message, type };
  setTimeout(() => notification.value.show = false, 4000);
};

const loadAtms = async () => {
  try {
    const { supabaseClient } = await import('@/services/supabase.js');
    const { data } = await supabaseClient.from('finance_atms').select('id, atm_name, atm_number, linked_bank_name, bank_name').eq('is_active', true).order('atm_name');
    atms.value = data || [];
  } catch (e) {
    atms.value = [];
  }
};

onMounted(async () => {
  await loadAtms();
  await loadInvoice();
});
</script>
