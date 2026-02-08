/**
 * ISO 22000 / FSSC 22000 Compliant GRN Inspection Module
 * Complete Goods Receipt & Quality Inspection System
 */

const GRNInspection = {
    /**
     * Generate unique GRN number (system-generated only)
     */
    generateGRNNumber() {
        const date = new Date();
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        const timestamp = Date.now().toString().slice(-6);
        return `GRN-${year}${month}${day}-${timestamp}`;
    },

    /**
     * Show comprehensive ISO-compliant GRN inspection form
     */
    async showGRNInspectionForm(purchaseId) {
        // Load purchase data
        let purchaseData = null;
        try {
            const data = await QualityAPI.getPurchases();
            purchaseData = data.purchases?.find(p => (p.id || p.purchase_id) === purchaseId);
            if (!purchaseData) {
                alert('Purchase order not found');
                return;
            }
        } catch (error) {
            alert(`Error loading purchase: ${error.message}`);
            return;
        }

        const grnNumber = this.generateGRNNumber();
        const currentDateTime = new Date().toISOString().slice(0, 16);

        // Create comprehensive GRN inspection modal
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 95vw; max-height: 95vh; overflow-y: auto;">
                <div class="modal-header">
                    <h3 class="modal-title">
                        <i class="fas fa-clipboard-check mr-2"></i>
                        <span data-key="grn_inspection_form">GRN Inspection Form</span> - ${grnNumber}
                    </h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body" style="padding: 24px;">
                    <form id="grn-inspection-form">
                        <!-- GRN HEADER SECTION -->
                        <div class="mb-6 p-4 bg-gray-50 rounded-lg border-2 border-[#284b44]">
                            <h4 class="text-lg font-bold mb-4 text-[#284b44]">
                                <i class="fas fa-file-alt mr-2"></i>
                                <span data-key="grn_header">GRN Header Information</span>
                            </h4>
                            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="grn_number">GRN Number</span> *
                                    </label>
                                    <input type="text" id="grn-number" value="${grnNumber}" 
                                           class="w-full px-4 py-2 border rounded-lg bg-gray-100 font-mono font-bold" 
                                           readonly required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="grn_date_time">GRN Date & Time</span> *
                                    </label>
                                    <input type="datetime-local" id="grn-date-time" 
                                           value="${currentDateTime}" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="purchase_order_number">Purchase Order Number</span>
                                    </label>
                                    <input type="text" id="grn-po-number" 
                                           value="${purchaseData.id || purchaseData.purchase_id || ''}" 
                                           class="w-full px-4 py-2 border rounded-lg" readonly>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="supplier_name">Supplier Name</span> *
                                    </label>
                                    <input type="text" id="grn-supplier-name" 
                                           value="${purchaseData.supplier_name || ''}" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="supplier_code">Supplier Code</span>
                                    </label>
                                    <input type="text" id="grn-supplier-code" 
                                           class="w-full px-4 py-2 border rounded-lg">
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="vendor_batch_number">Vendor Batch Number</span> *
                                    </label>
                                    <input type="text" id="grn-vendor-batch" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="receiving_location">Receiving Location</span> *
                                    </label>
                                    <select id="grn-location" class="w-full px-4 py-2 border rounded-lg" required>
                                        <option value="">-- <span data-key="select_location">Select Location</span> --</option>
                                        <option value="Main Warehouse">Main Warehouse</option>
                                        <option value="Production Area">Production Area</option>
                                        <option value="Cold Storage">Cold Storage</option>
                                        <option value="Branch 1">Branch 1</option>
                                        <option value="Branch 2">Branch 2</option>
                                    </select>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="invoice_number">Invoice Number</span>
                                    </label>
                                    <input type="text" id="grn-invoice-number" 
                                           class="w-full px-4 py-2 border rounded-lg">
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="external_reference_id">External Reference ID</span>
                                    </label>
                                    <input type="text" id="grn-external-ref" 
                                           value="GRN-EXT-${Date.now()}" 
                                           class="w-full px-4 py-2 border rounded-lg">
                                </div>
                            </div>
                        </div>

                        <!-- ITEM INSPECTION TABLE -->
                        <div class="mb-6">
                            <h4 class="text-lg font-bold mb-4 text-[#284b44]">
                                <i class="fas fa-list-check mr-2"></i>
                                <span data-key="item_inspection_table">Item Inspection Table</span>
                            </h4>
                            <div class="table-container">
                                <table class="data-table w-full" id="grn-items-table">
                                    <thead>
                                        <tr>
                                            <th data-key="item_code">Item Code</th>
                                            <th data-key="item_description">Item Description</th>
                                            <th data-key="unit">Unit</th>
                                            <th data-key="received_quantity">Received Qty</th>
                                            <th data-key="packaging_condition">Packaging</th>
                                            <th data-key="expiry_date">Expiry Date *</th>
                                            <th data-key="visual_inspection">Visual Inspection</th>
                                            <th data-key="temperature_check">Temp Check</th>
                                            <th data-key="non_conformance">Non-Conformance</th>
                                            <th data-key="severity">Severity</th>
                                        </tr>
                                    </thead>
                                    <tbody id="grn-items-tbody">
                                        ${this.renderGRNItems(purchaseData.items || [])}
                                    </tbody>
                                </table>
                            </div>
                        </div>

                        <!-- QUALITY DECISION SECTION -->
                        <div class="mb-6 p-4 bg-blue-50 rounded-lg border-2 border-blue-300">
                            <h4 class="text-lg font-bold mb-4 text-[#284b44]">
                                <i class="fas fa-check-circle mr-2"></i>
                                <span data-key="quality_decision">Quality Decision</span>
                            </h4>
                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="overall_qc_status">Overall QC Status</span> *
                                    </label>
                                    <select id="grn-qc-status" class="w-full px-4 py-2 border rounded-lg" required 
                                            onchange="GRNInspection.handleQCStatusChange()">
                                        <option value="">-- <span data-key="select_status">Select Status</span> --</option>
                                        <option value="PASS">PASS</option>
                                        <option value="HOLD">HOLD</option>
                                        <option value="REJECT">REJECT</option>
                                    </select>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="disposition">Disposition</span> *
                                    </label>
                                    <select id="grn-disposition" class="w-full px-4 py-2 border rounded-lg" required>
                                        <option value="">-- <span data-key="select_disposition">Select Disposition</span> --</option>
                                        <option value="Accept to Stock">Accept to Stock</option>
                                        <option value="Hold for Investigation">Hold for Investigation</option>
                                        <option value="Return to Supplier">Return to Supplier</option>
                                        <option value="Destroy">Destroy</option>
                                    </select>
                                </div>
                                <div class="md:col-span-2">
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="qa_remarks">QA Remarks</span>
                                    </label>
                                    <textarea id="grn-qa-remarks" rows="3" 
                                              class="w-full px-4 py-2 border rounded-lg" 
                                              placeholder="Enter quality inspection remarks..."></textarea>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="corrective_action_required">Corrective Action Required</span> *
                                    </label>
                                    <select id="grn-corrective-action" class="w-full px-4 py-2 border rounded-lg" required>
                                        <option value="No">No</option>
                                        <option value="Yes">Yes</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        <!-- APPROVAL SECTION -->
                        <div class="mb-6 p-4 bg-green-50 rounded-lg border-2 border-green-300">
                            <h4 class="text-lg font-bold mb-4 text-[#284b44]">
                                <i class="fas fa-user-check mr-2"></i>
                                <span data-key="approval_responsibility">Approval & Responsibility</span>
                            </h4>
                            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="received_by">Received By</span> (Warehouse User) *
                                    </label>
                                    <input type="text" id="grn-received-by" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="quality_checked_by">Quality Checked By</span> (QA User) *
                                    </label>
                                    <input type="text" id="grn-qa-checked-by" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="approved_by">Approved By</span> (QA Manager) *
                                    </label>
                                    <input type="text" id="grn-approved-by" 
                                           class="w-full px-4 py-2 border rounded-lg" required>
                                </div>
                                <div>
                                    <label class="block text-sm font-medium mb-2">
                                        <span data-key="approval_date_time">Approval Date & Time</span>
                                    </label>
                                    <input type="datetime-local" id="grn-approval-datetime" 
                                           value="${currentDateTime}" 
                                           class="w-full px-4 py-2 border rounded-lg bg-gray-100" readonly>
                                </div>
                            </div>
                        </div>

                        <!-- ACTION BUTTONS -->
                        <div class="flex gap-3 justify-end">
                            <button type="button" class="btn btn-outline" 
                                    onclick="this.closest('.modal').remove()">
                                <i class="fas fa-times"></i> <span data-key="cancel">Cancel</span>
                            </button>
                            <button type="button" class="btn btn-secondary" 
                                    onclick="GRNInspection.saveDraft()">
                                <i class="fas fa-save"></i> <span data-key="save_draft">Save Draft</span>
                            </button>
                            <button type="submit" class="btn btn-primary" id="grn-submit-btn">
                                <i class="fas fa-check-circle"></i> 
                                <span data-key="submit_approve_grn">Submit & Approve GRN</span>
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        // Handle form submission
        document.getElementById('grn-inspection-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.submitGRNInspection(purchaseId, grnNumber);
        });

        // Apply translations
        if (typeof translatePage === 'function') {
            const currentLang = localStorage.getItem('portalLang') || 'en';
            translatePage(currentLang);
        }
    },

    /**
     * Render GRN items table rows
     */
    renderGRNItems(items) {
        if (!items || items.length === 0) {
            return '<tr><td colspan="10" class="text-center py-4 text-gray-500">No items found</td></tr>';
        }

        return items.map((item, index) => `
            <tr class="grn-item-row" data-item-index="${index}">
                <td>
                    <input type="text" name="item-code-${index}" 
                           value="${item.item_code || item.material_id || ''}" 
                           class="w-full px-2 py-1 border rounded text-sm" 
                           placeholder="Item Code" required>
                </td>
                <td>
                    <input type="text" name="item-description-${index}" 
                           value="${item.name || item.material_name || ''}" 
                           class="w-full px-2 py-1 border rounded text-sm" 
                           placeholder="Item Description" required readonly>
                </td>
                <td>
                    <input type="text" name="item-unit-${index}" 
                           value="${item.unit || 'kg'}" 
                           class="w-full px-2 py-1 border rounded text-sm" 
                           placeholder="Unit" required readonly>
                </td>
                <td>
                    <input type="number" step="0.01" min="0" name="item-quantity-${index}" 
                           value="${item.quantity || 0}" 
                           class="w-full px-2 py-1 border rounded text-sm" 
                           placeholder="Qty" required>
                </td>
                <td>
                    <select name="item-packaging-${index}" 
                            class="w-full px-2 py-1 border rounded text-sm" required>
                        <option value="Good">Good</option>
                        <option value="Damaged">Damaged</option>
                    </select>
                </td>
                <td>
                    <input type="date" name="item-expiry-${index}" 
                           class="w-full px-2 py-1 border rounded text-sm expiry-date-input" 
                           required onchange="GRNInspection.validateExpiryDate(this)">
                    <small class="text-red-500 hidden expiry-error">Expiry required!</small>
                </td>
                <td>
                    <select name="item-visual-${index}" 
                            class="w-full px-2 py-1 border rounded text-sm" required
                            onchange="GRNInspection.handleVisualInspectionChange(this, ${index})">
                        <option value="Pass">Pass</option>
                        <option value="Fail">Fail</option>
                    </select>
                </td>
                <td>
                    <input type="number" step="0.1" name="item-temperature-${index}" 
                           class="w-full px-2 py-1 border rounded text-sm" 
                           placeholder="°C">
                </td>
                <td>
                    <input type="text" name="item-nonconformance-${index}" 
                           class="w-full px-2 py-1 border rounded text-sm nonconformance-input" 
                           placeholder="Reason (if Fail)" 
                           style="display: none;">
                </td>
                <td>
                    <select name="item-severity-${index}" 
                            class="w-full px-2 py-1 border rounded text-sm severity-input" 
                            style="display: none;">
                        <option value="">-- Select --</option>
                        <option value="Critical">Critical</option>
                        <option value="Major">Major</option>
                        <option value="Minor">Minor</option>
                    </select>
                </td>
            </tr>
        `).join('');
    },

    /**
     * Handle visual inspection change
     */
    handleVisualInspectionChange(select, index) {
        const row = select.closest('tr');
        const nonconformanceInput = row.querySelector('.nonconformance-input');
        const severitySelect = row.querySelector('.severity-input');
        
        if (select.value === 'Fail') {
            nonconformanceInput.style.display = 'block';
            nonconformanceInput.required = true;
            severitySelect.style.display = 'block';
            severitySelect.required = true;
        } else {
            nonconformanceInput.style.display = 'none';
            nonconformanceInput.required = false;
            nonconformanceInput.value = '';
            severitySelect.style.display = 'none';
            severitySelect.required = false;
            severitySelect.value = '';
        }
    },

    /**
     * Handle QC status change
     */
    handleQCStatusChange() {
        const qcStatus = document.getElementById('grn-qc-status').value;
        const disposition = document.getElementById('grn-disposition');
        const submitBtn = document.getElementById('grn-submit-btn');
        
        // Auto-set disposition based on QC status
        if (qcStatus === 'PASS') {
            disposition.value = 'Accept to Stock';
        } else if (qcStatus === 'HOLD') {
            disposition.value = 'Hold for Investigation';
        } else if (qcStatus === 'REJECT') {
            disposition.value = 'Return to Supplier';
        }

        // Disable submit if HOLD or REJECT (requires approval workflow)
        if (qcStatus === 'HOLD' || qcStatus === 'REJECT') {
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fas fa-lock"></i> Requires Manager Approval';
        } else {
            submitBtn.disabled = false;
            submitBtn.innerHTML = '<i class="fas fa-check-circle"></i> Submit & Approve GRN';
        }
    },

    /**
     * Validate expiry date
     */
    validateExpiryDate(input) {
        const errorMsg = input.parentElement.querySelector('.expiry-error');
        if (!input.value) {
            errorMsg.classList.remove('hidden');
            return false;
        }
        errorMsg.classList.add('hidden');
        return true;
    },

    /**
     * Validate all expiry dates before submission
     */
    validateAllExpiryDates() {
        const expiryInputs = document.querySelectorAll('.expiry-date-input');
        let allValid = true;
        
        expiryInputs.forEach(input => {
            if (!this.validateExpiryDate(input)) {
                allValid = false;
            }
        });
        
        return allValid;
    },

    /**
     * Submit GRN inspection with full validation
     */
    async submitGRNInspection(purchaseId, grnNumber) {
        // Validate expiry dates (mandatory for ISO compliance)
        if (!this.validateAllExpiryDates()) {
            alert('Error: Expiry date is mandatory for all items. Please fill all expiry dates before approval.');
            return;
        }

        // Collect all form data
        const formData = {
            grn_number: grnNumber,
            grn_date_time: document.getElementById('grn-date-time').value,
            purchase_order_number: document.getElementById('grn-po-number').value,
            supplier_name: document.getElementById('grn-supplier-name').value,
            supplier_code: document.getElementById('grn-supplier-code').value,
            vendor_batch_number: document.getElementById('grn-vendor-batch').value,
            receiving_location: document.getElementById('grn-location').value,
            invoice_number: document.getElementById('grn-invoice-number').value,
            external_reference_id: document.getElementById('grn-external-ref').value,
            qc_status: document.getElementById('grn-qc-status').value,
            disposition: document.getElementById('grn-disposition').value,
            qa_remarks: document.getElementById('grn-qa-remarks').value,
            corrective_action_required: document.getElementById('grn-corrective-action').value,
            received_by: document.getElementById('grn-received-by').value,
            quality_checked_by: document.getElementById('grn-qa-checked-by').value,
            approved_by: document.getElementById('grn-approved-by').value,
            approval_date_time: document.getElementById('grn-approval-datetime').value,
            items: this.collectGRNItems()
        };

        // Validate QC status
        if (formData.qc_status === 'HOLD' || formData.qc_status === 'REJECT') {
            alert('GRN with HOLD or REJECT status requires manager approval. Cannot auto-approve.');
            return;
        }

        try {
            // Submit GRN
            const result = await QualityAPI.createGRNInspection(formData);
            
            if (result.success) {
                alert('GRN approved successfully! Batches have been auto-generated.');
                
                // Close modal
                document.querySelector('.modal.show').remove();
                
                // Refresh data
                if (typeof qualityUI !== 'undefined') {
                    qualityUI.loadPurchases();
                    qualityUI.loadBatches();
                    const stockTab = document.getElementById('tab-stock');
                    if (stockTab && stockTab.classList.contains('active')) {
                        qualityUI.loadStock();
                    }
                }
            } else {
                alert(`Error: ${result.message || 'Failed to create GRN'}`);
            }
        } catch (error) {
            alert(`Error submitting GRN: ${error.message}`);
        }
    },

    /**
     * Collect all GRN items data
     */
    collectGRNItems() {
        const rows = document.querySelectorAll('.grn-item-row');
        const items = [];

        rows.forEach((row, index) => {
            const item = {
                item_code: row.querySelector(`[name="item-code-${index}"]`).value,
                item_description: row.querySelector(`[name="item-description-${index}"]`).value,
                unit: row.querySelector(`[name="item-unit-${index}"]`).value,
                received_quantity: parseFloat(row.querySelector(`[name="item-quantity-${index}"]`).value),
                packaging_condition: row.querySelector(`[name="item-packaging-${index}"]`).value,
                expiry_date: row.querySelector(`[name="item-expiry-${index}"]`).value,
                visual_inspection: row.querySelector(`[name="item-visual-${index}"]`).value,
                temperature_check: row.querySelector(`[name="item-temperature-${index}"]`).value || null,
                non_conformance_reason: row.querySelector(`[name="item-nonconformance-${index}"]`).value || null,
                non_conformance_severity: row.querySelector(`[name="item-severity-${index}"]`).value || null
            };
            items.push(item);
        });

        return items;
    },

    /**
     * Save draft (future implementation)
     */
    saveDraft() {
        alert('Draft saving feature will be implemented soon.');
    }
};

// Make available globally
window.GRNInspection = GRNInspection;
