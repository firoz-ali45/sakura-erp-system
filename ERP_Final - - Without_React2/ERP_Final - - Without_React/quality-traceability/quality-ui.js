/**
 * Food Quality Traceability UI Handler
 * Handles DOM rendering, user interactions, and data display
 */

const qualityUI = {
    /**
     * Show loading state
     */
    showLoading(elementId) {
        const element = document.getElementById(elementId);
        if (element) {
            element.innerHTML = '<tr><td colspan="100%" class="text-center py-8"><div class="loading-spinner mx-auto"></div><p class="mt-2 text-gray-500">Loading...</p></td></tr>';
        }
    },

    /**
     * Show error message
     */
    showError(elementId, message) {
        const element = document.getElementById(elementId);
        if (element) {
            element.innerHTML = `<tr><td colspan="100%" class="text-center py-8 text-red-500"><i class="fas fa-exclamation-circle mr-2"></i>${message}</td></tr>`;
        }
    },

    /**
     * Format date for display
     */
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        const date = new Date(dateString);
        return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    },

    /**
     * Calculate days until expiry
     */
    daysUntilExpiry(expiryDate) {
        if (!expiryDate) return null;
        const today = new Date();
        const expiry = new Date(expiryDate);
        const diffTime = expiry - today;
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
        return diffDays;
    },

    /**
     * Get expiry status badge
     */
    getExpiryBadge(expiryDate) {
        const days = this.daysUntilExpiry(expiryDate);
        if (days === null) return '<span class="px-2 py-1 rounded text-xs bg-gray-200">No Expiry</span>';
        if (days < 0) return '<span class="px-2 py-1 rounded text-xs bg-red-500 text-white">Expired</span>';
        if (days <= 7) return '<span class="px-2 py-1 rounded text-xs bg-red-200 text-red-800">Expiring Soon</span>';
        if (days <= 30) return '<span class="px-2 py-1 rounded text-xs bg-yellow-200 text-yellow-800">Near Expiry</span>';
        return '<span class="px-2 py-1 rounded text-xs bg-green-200 text-green-800">Good</span>';
    },

    /**
     * Load and display purchases
     */
    async loadPurchases() {
        const tbody = document.getElementById('purchases-table-body');
        this.showLoading('purchases-table-body');

        try {
            const data = await QualityAPI.getPurchases();
            
            if (!data || !data.purchases || data.purchases.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" class="text-center py-8 text-gray-500">No pending purchases found</td></tr>';
                return;
            }

            tbody.innerHTML = data.purchases.map(purchase => `
                <tr>
                    <td class="font-mono">${purchase.id || purchase.purchase_id}</td>
                    <td>${purchase.supplier_name || 'N/A'}</td>
                    <td>${this.formatDate(purchase.date || purchase.created_at)}</td>
                    <td>${purchase.items_count || purchase.items?.length || 0} items</td>
                    <td><span class="px-2 py-1 rounded text-xs bg-yellow-200">Pending GRN</span></td>
                    <td>
                        <button class="btn btn-primary btn-sm" onclick="GRNInspection.showGRNInspectionForm('${purchase.id || purchase.purchase_id}')">
                            <i class="fas fa-clipboard-check"></i> <span data-key="create_grn_inspection">Create GRN Inspection</span>
                        </button>
                    </td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('purchases-table-body', `Error loading purchases: ${error.message}`);
        }
    },

    /**
     * Show GRN creation modal
     */
    showGRNModal(purchaseId) {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 600px;">
                <div class="modal-header">
                    <h3 class="modal-title">Generate GRN for Purchase ${purchaseId}</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="grn-form">
                        <input type="hidden" id="grn-purchase-id" value="${purchaseId}">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="grn-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="GRN-${Date.now()}" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Received Date</label>
                            <input type="datetime-local" id="grn-received-date" class="w-full px-4 py-2 border rounded-lg" 
                                   value="${new Date().toISOString().slice(0, 16)}" required>
                        </div>
                        <div id="grn-items-container" class="mb-4">
                            <label class="block text-sm font-medium mb-2">Items Received</label>
                            <p class="text-sm text-gray-500 mb-2">Loading items...</p>
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Generate GRN
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        // Load purchase items and store purchase data
        let purchaseData = null;
        QualityAPI.getPurchases().then(data => {
            const purchase = data.purchases?.find(p => (p.id || p.purchase_id) === purchaseId);
            purchaseData = purchase;
            if (purchase && purchase.items) {
                const container = document.getElementById('grn-items-container');
                container.innerHTML = `
                    <label class="block text-sm font-medium mb-2">Items Received</label>
                    ${purchase.items.map((item, index) => `
                        <div class="mb-3 p-3 border rounded-lg">
                            <div class="font-medium mb-2">${item.name || item.material_name}</div>
                            <div class="text-sm text-gray-600 mb-2">
                                Ordered: ${item.quantity} ${item.unit}
                            </div>
                            <div>
                                <label class="text-sm">Received Quantity:</label>
                                <input type="number" step="0.01" min="0" max="${item.quantity}" 
                                       id="grn-item-${index}" class="w-full px-3 py-2 border rounded mt-1" 
                                       value="${item.quantity}" required
                                       data-item-id="${item.id || item.material_id || ''}"
                                       data-unit="${item.unit || ''}">
                                <span class="text-sm text-gray-500">${item.unit}</span>
                            </div>
                        </div>
                    `).join('')}
                `;
            }
        });

        // Handle form submission
        document.getElementById('grn-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const purchaseId = document.getElementById('grn-purchase-id').value;
            const externalRef = document.getElementById('grn-external-ref').value;
            const receivedDate = document.getElementById('grn-received-date').value;

            const items = [];
            const itemInputs = document.querySelectorAll('[id^="grn-item-"]');
            itemInputs.forEach((input) => {
                const itemId = input.getAttribute('data-item-id');
                const unit = input.getAttribute('data-unit');
                if (itemId && unit) {
                    items.push({
                        item_id: itemId,
                        quantity: parseFloat(input.value),
                        unit: unit
                    });
                }
            });

            try {
                await QualityAPI.generateGRN({
                    purchase_id: purchaseId,
                    external_reference_id: externalRef,
                    items: items,
                    received_date: new Date(receivedDate).toISOString()
                });
                alert('GRN generated successfully!');
                modal.remove();
                this.loadPurchases();
            } catch (error) {
                alert(`Error generating GRN: ${error.message}`);
            }
        });
    },

    /**
     * Load and display batches
     */
    async loadBatches() {
        const tbody = document.getElementById('batches-table-body');
        this.showLoading('batches-table-body');

        try {
            const data = await QualityAPI.getBatches();
            
            if (!data || !data.batches || data.batches.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" class="text-center py-8 text-gray-500">No batches found</td></tr>';
                return;
            }

            tbody.innerHTML = data.batches.map(batch => `
                <tr>
                    <td class="font-mono">${batch.id || batch.batch_id}</td>
                    <td class="font-mono">${batch.grn_id || 'N/A'}</td>
                    <td>${batch.material_name || 'N/A'}</td>
                    <td>${batch.quantity || 0}</td>
                    <td>${batch.unit || 'N/A'}</td>
                    <td>${this.formatDate(batch.expiry_date)}</td>
                    <td>${batch.location || 'N/A'}</td>
                    <td>${this.formatDate(batch.created_at)}</td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('batches-table-body', `Error loading batches: ${error.message}`);
        }
    },

    /**
     * Show create batch modal
     */
    showCreateBatchModal() {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 600px;">
                <div class="modal-header">
                    <h3 class="modal-title">Create Raw Material Batch</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="batch-form">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">GRN Reference ID *</label>
                            <input type="text" id="batch-grn-id" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Material Name *</label>
                            <input type="text" id="batch-material-name" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Material ID</label>
                            <input type="text" id="batch-material-id" class="w-full px-4 py-2 border rounded-lg">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Quantity *</label>
                            <input type="number" step="0.01" min="0" id="batch-quantity" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Unit *</label>
                            <input type="text" id="batch-unit" class="w-full px-4 py-2 border rounded-lg" value="kg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Expiry Date *</label>
                            <input type="date" id="batch-expiry" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Location *</label>
                            <select id="batch-location" class="w-full px-4 py-2 border rounded-lg" required>
                                <option value="Main Warehouse">Main Warehouse</option>
                                <option value="Production Area">Production Area</option>
                                <option value="Cold Storage">Cold Storage</option>
                            </select>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="batch-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="BATCH-${Date.now()}">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Supplier Batch Number</label>
                            <input type="text" id="batch-supplier-batch" class="w-full px-4 py-2 border rounded-lg">
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Create Batch
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        document.getElementById('batch-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            try {
                await QualityAPI.createRawBatch({
                    grn_id: document.getElementById('batch-grn-id').value,
                    material_id: document.getElementById('batch-material-id').value,
                    material_name: document.getElementById('batch-material-name').value,
                    quantity: parseFloat(document.getElementById('batch-quantity').value),
                    unit: document.getElementById('batch-unit').value,
                    expiry_date: new Date(document.getElementById('batch-expiry').value).toISOString(),
                    location: document.getElementById('batch-location').value,
                    external_reference_id: document.getElementById('batch-external-ref').value,
                    supplier_batch: document.getElementById('batch-supplier-batch').value
                });
                alert('Batch created successfully!');
                modal.remove();
                this.loadBatches();
                // Refresh stock if on stock tab
                const stockTab = document.getElementById('tab-stock');
                if (stockTab && stockTab.classList.contains('active')) {
                    this.loadStock();
                }
            } catch (error) {
                alert(`Error creating batch: ${error.message}`);
            }
        });
    },

    /**
     * Load and display production lots
     */
    async loadProductionLots() {
        const tbody = document.getElementById('production-table-body');
        this.showLoading('production-table-body');

        try {
            const data = await QualityAPI.getProductionLots();
            
            if (!data || !data.lots || data.lots.length === 0) {
                tbody.innerHTML = '<tr><td colspan="9" class="text-center py-8 text-gray-500">No production lots found</td></tr>';
                return;
            }

            tbody.innerHTML = data.lots.map(lot => `
                <tr>
                    <td class="font-mono">${lot.id || lot.lot_id}</td>
                    <td>${lot.product_name || 'N/A'}</td>
                    <td>${lot.quantity || 0}</td>
                    <td>${lot.unit || 'N/A'}</td>
                    <td>${this.formatDate(lot.production_date)}</td>
                    <td>${this.formatDate(lot.expiry_date)}</td>
                    <td>${lot.location || 'N/A'}</td>
                    <td>${lot.batch_sources?.length || 0} batches</td>
                    <td>${this.formatDate(lot.created_at)}</td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('production-table-body', `Error loading production lots: ${error.message}`);
        }
    },

    /**
     * Show create production modal
     */
    showCreateProductionModal() {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 700px;">
                <div class="modal-header">
                    <h3 class="modal-title">Create Production Lot</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="production-form">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Product Name *</label>
                            <input type="text" id="prod-product-name" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Product ID</label>
                            <input type="text" id="prod-product-id" class="w-full px-4 py-2 border rounded-lg">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Quantity *</label>
                            <input type="number" step="0.01" min="0" id="prod-quantity" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Unit *</label>
                            <input type="text" id="prod-unit" class="w-full px-4 py-2 border rounded-lg" value="pcs" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Production Date *</label>
                            <input type="date" id="prod-production-date" class="w-full px-4 py-2 border rounded-lg" 
                                   value="${new Date().toISOString().slice(0, 10)}" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Expiry Date *</label>
                            <input type="date" id="prod-expiry-date" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Location *</label>
                            <select id="prod-location" class="w-full px-4 py-2 border rounded-lg" required>
                                <option value="Main Warehouse">Main Warehouse</option>
                                <option value="Production Area">Production Area</option>
                                <option value="Cold Storage">Cold Storage</option>
                            </select>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Batch Sources (comma-separated Batch IDs)</label>
                            <input type="text" id="prod-batch-sources" class="w-full px-4 py-2 border rounded-lg" 
                                   placeholder="BATCH-001, BATCH-002">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="prod-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="LOT-${Date.now()}">
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Create Production Lot
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        document.getElementById('production-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const batchSources = document.getElementById('prod-batch-sources').value
                .split(',')
                .map(id => id.trim())
                .filter(id => id);

            try {
                await QualityAPI.createProduction({
                    product_id: document.getElementById('prod-product-id').value,
                    product_name: document.getElementById('prod-product-name').value,
                    quantity: parseFloat(document.getElementById('prod-quantity').value),
                    unit: document.getElementById('prod-unit').value,
                    production_date: new Date(document.getElementById('prod-production-date').value).toISOString(),
                    expiry_date: new Date(document.getElementById('prod-expiry-date').value).toISOString(),
                    location: document.getElementById('prod-location').value,
                    batch_sources: batchSources,
                    external_reference_id: document.getElementById('prod-external-ref').value
                });
                alert('Production lot created successfully!');
                modal.remove();
                this.loadProductionLots();
                // Refresh stock if on stock tab
                const stockTab = document.getElementById('tab-stock');
                if (stockTab && stockTab.classList.contains('active')) {
                    this.loadStock();
                }
            } catch (error) {
                alert(`Error creating production lot: ${error.message}`);
            }
        });
    },

    /**
     * Load and display stock
     */
    async loadStock() {
        const tbody = document.getElementById('stock-table-body');
        const locationFilter = document.getElementById('stock-location-filter')?.value || '';
        this.showLoading('stock-table-body');

        try {
            const data = await QualityAPI.getStock(locationFilter || null);
            
            if (!data || !data.stock || data.stock.length === 0) {
                tbody.innerHTML = '<tr><td colspan="9" class="text-center py-8 text-gray-500">No stock found</td></tr>';
                return;
            }

            tbody.innerHTML = data.stock.map(item => {
                const days = this.daysUntilExpiry(item.expiry_date);
                return `
                    <tr>
                        <td><span class="px-2 py-1 rounded text-xs ${item.type === 'batch' ? 'bg-blue-100' : 'bg-green-100'}">${item.type === 'batch' ? 'Batch' : 'Lot'}</span></td>
                        <td class="font-mono">${item.id || item.batch_id || item.lot_id}</td>
                        <td>${item.name || item.material_name || item.product_name}</td>
                        <td>${item.quantity || 0}</td>
                        <td>${item.unit || 'N/A'}</td>
                        <td>${item.location || 'N/A'}</td>
                        <td>${this.formatDate(item.expiry_date)}</td>
                        <td>${days !== null ? (days < 0 ? `${Math.abs(days)} days ago` : `${days} days`) : 'N/A'}</td>
                        <td>${this.getExpiryBadge(item.expiry_date)}</td>
                    </tr>
                `;
            }).join('');
        } catch (error) {
            this.showError('stock-table-body', `Error loading stock: ${error.message}`);
        }
    },

    /**
     * Load and display transfers
     */
    async loadTransfers() {
        const tbody = document.getElementById('transfers-table-body');
        this.showLoading('transfers-table-body');

        try {
            const data = await QualityAPI.getTransfers();
            
            if (!data || !data.transfers || data.transfers.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" class="text-center py-8 text-gray-500">No transfers found</td></tr>';
                return;
            }

            tbody.innerHTML = data.transfers
                .filter(t => t.type === 'TRS' || t.type === 'TRR') // Show both TRS and TRR
                .map(transfer => {
                    const isTRS = transfer.type === 'TRS';
                    const canReceive = isTRS && transfer.status !== 'completed';
                    return `
                        <tr>
                            <td class="font-mono">${transfer.id || transfer.transfer_id}</td>
                            <td><span class="px-2 py-1 rounded text-xs ${isTRS ? 'bg-yellow-200' : 'bg-green-200'}">${transfer.type || 'TRS'}</span></td>
                            <td>${transfer.from_location || 'N/A'}</td>
                            <td>${transfer.to_location || 'N/A'}</td>
                            <td>${transfer.items?.length || 0} items</td>
                            <td><span class="px-2 py-1 rounded text-xs ${transfer.status === 'completed' ? 'bg-green-200' : 'bg-yellow-200'}">${transfer.status || 'pending'}</span></td>
                            <td>${this.formatDate(transfer.created_at)}</td>
                            <td>
                                ${canReceive ? `
                                    <button class="btn btn-primary btn-sm" onclick="qualityUI.receiveTransfer('${transfer.id || transfer.transfer_id}')">
                                        <i class="fas fa-check"></i> Receive
                                    </button>
                                ` : '<span class="text-sm text-gray-500">Completed</span>'}
                            </td>
                        </tr>
                    `;
                }).join('');
        } catch (error) {
            this.showError('transfers-table-body', `Error loading transfers: ${error.message}`);
        }
    },

    /**
     * Show create transfer modal
     */
    showCreateTransferModal() {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 700px;">
                <div class="modal-header">
                    <h3 class="modal-title">Create Transfer (TRS)</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="transfer-form">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">From Location *</label>
                            <select id="transfer-from" class="w-full px-4 py-2 border rounded-lg" required>
                                <option value="Main Warehouse">Main Warehouse</option>
                                <option value="Production Area">Production Area</option>
                                <option value="Cold Storage">Cold Storage</option>
                            </select>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">To Location *</label>
                            <select id="transfer-to" class="w-full px-4 py-2 border rounded-lg" required>
                                <option value="Main Warehouse">Main Warehouse</option>
                                <option value="Production Area">Production Area</option>
                                <option value="Cold Storage">Cold Storage</option>
                            </select>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Items (one per line: Batch/Lot ID, Quantity)</label>
                            <textarea id="transfer-items" class="w-full px-4 py-2 border rounded-lg" rows="5" 
                                      placeholder="BATCH-001, 10.5&#10;LOT-002, 5"></textarea>
                            <p class="text-xs text-gray-500 mt-1">Format: ID, Quantity (one per line)</p>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="transfer-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="TRS-${Date.now()}">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Notes</label>
                            <textarea id="transfer-notes" class="w-full px-4 py-2 border rounded-lg" rows="3"></textarea>
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Create Transfer
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        document.getElementById('transfer-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const itemsText = document.getElementById('transfer-items').value;
            const items = itemsText.split('\n')
                .map(line => {
                    const [id, qty] = line.split(',').map(s => s.trim());
                    if (!id || !qty) return null;
                    
                    // Determine if it's a batch or lot ID
                    const isBatch = id.startsWith('BATCH-') || id.startsWith('batch-');
                    const isLot = id.startsWith('LOT-') || id.startsWith('lot-');
                    
                    if (isBatch) {
                        return { batch_id: id, quantity: parseFloat(qty) };
                    } else if (isLot) {
                        return { lot_id: id, quantity: parseFloat(qty) };
                    } else {
                        // Try to find by checking both
                        return { batch_id: id, lot_id: id, quantity: parseFloat(qty) };
                    }
                })
                .filter(item => item !== null);

            if (items.length === 0) {
                alert('Please enter at least one item');
                return;
            }

            try {
                await QualityAPI.createTransfer({
                    from_location: document.getElementById('transfer-from').value,
                    to_location: document.getElementById('transfer-to').value,
                    items: items,
                    external_reference_id: document.getElementById('transfer-external-ref').value,
                    notes: document.getElementById('transfer-notes').value
                });
                alert('Transfer created successfully!');
                modal.remove();
                this.loadTransfers();
            } catch (error) {
                alert(`Error creating transfer: ${error.message}`);
            }
        });
    },

    /**
     * Receive transfer
     */
    async receiveTransfer(transferId) {
        if (!confirm('Confirm receipt of this transfer?')) return;

        try {
            await QualityAPI.receiveTransfer(transferId);
            alert('Transfer received successfully!');
            this.loadTransfers();
        } catch (error) {
            alert(`Error receiving transfer: ${error.message}`);
        }
    },

    /**
     * Load and display sales
     */
    async loadSales() {
        const tbody = document.getElementById('sales-table-body');
        this.showLoading('sales-table-body');

        try {
            const data = await QualityAPI.getSales();
            
            if (!data || !data.sales || data.sales.length === 0) {
                tbody.innerHTML = '<tr><td colspan="8" class="text-center py-8 text-gray-500">No sales records found</td></tr>';
                return;
            }

            tbody.innerHTML = data.sales.map(sale => `
                <tr>
                    <td class="font-mono">${sale.id || sale.sale_id}</td>
                    <td class="font-mono">${sale.lot_id || 'N/A'}</td>
                    <td>${sale.product_name || 'N/A'}</td>
                    <td>${sale.quantity || 0}</td>
                    <td>${sale.unit || 'N/A'}</td>
                    <td>${sale.customer_outlet || 'N/A'}</td>
                    <td>${this.formatDate(sale.sale_date)}</td>
                    <td class="font-mono text-xs">${sale.external_reference_id || 'N/A'}</td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('sales-table-body', `Error loading sales: ${error.message}`);
        }
    },

    /**
     * Show record sale modal
     */
    showRecordSaleModal() {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 600px;">
                <div class="modal-header">
                    <h3 class="modal-title">Record Sale</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="sale-form">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Lot ID *</label>
                            <input type="text" id="sale-lot-id" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Quantity *</label>
                            <input type="number" step="0.01" min="0" id="sale-quantity" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Unit *</label>
                            <input type="text" id="sale-unit" class="w-full px-4 py-2 border rounded-lg" value="pcs" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Customer/Outlet *</label>
                            <input type="text" id="sale-customer" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Sale Date *</label>
                            <input type="date" id="sale-date" class="w-full px-4 py-2 border rounded-lg" 
                                   value="${new Date().toISOString().slice(0, 10)}" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="sale-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="SALE-${Date.now()}">
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Record Sale
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        document.getElementById('sale-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            try {
                await QualityAPI.recordSale({
                    lot_id: document.getElementById('sale-lot-id').value,
                    quantity: parseFloat(document.getElementById('sale-quantity').value),
                    unit: document.getElementById('sale-unit').value,
                    customer_outlet: document.getElementById('sale-customer').value,
                    sale_date: new Date(document.getElementById('sale-date').value).toISOString(),
                    external_reference_id: document.getElementById('sale-external-ref').value
                });
                alert('Sale recorded successfully!');
                modal.remove();
                this.loadSales();
                // Refresh stock if on stock tab
                const stockTab = document.getElementById('tab-stock');
                if (stockTab && stockTab.classList.contains('active')) {
                    this.loadStock();
                }
            } catch (error) {
                alert(`Error recording sale: ${error.message}`);
            }
        });
    },

    /**
     * Load and display adjustments
     */
    async loadAdjustments() {
        const tbody = document.getElementById('adjustments-table-body');
        this.showLoading('adjustments-table-body');

        try {
            const data = await QualityAPI.getAdjustments();
            
            if (!data || !data.adjustments || data.adjustments.length === 0) {
                tbody.innerHTML = '<tr><td colspan="9" class="text-center py-8 text-gray-500">No adjustments found</td></tr>';
                return;
            }

            tbody.innerHTML = data.adjustments.map(adj => `
                <tr>
                    <td class="font-mono">${adj.id || adj.adjustment_id}</td>
                    <td><span class="px-2 py-1 rounded text-xs bg-orange-200">${adj.type || 'N/A'}</span></td>
                    <td class="font-mono">${adj.batch_id || adj.lot_id || 'N/A'}</td>
                    <td>${adj.item_name || adj.material_name || adj.product_name || 'N/A'}</td>
                    <td>${adj.quantity || 0}</td>
                    <td>${adj.unit || 'N/A'}</td>
                    <td>${adj.reason || 'N/A'}</td>
                    <td>${this.formatDate(adj.created_at)}</td>
                    <td class="font-mono text-xs">${adj.external_reference_id || 'N/A'}</td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('adjustments-table-body', `Error loading adjustments: ${error.message}`);
        }
    },

    /**
     * Show adjustment modal
     */
    showAdjustmentModal() {
        const modal = document.createElement('div');
        modal.className = 'modal show';
        modal.innerHTML = `
            <div class="modal-content" style="max-width: 600px;">
                <div class="modal-header">
                    <h3 class="modal-title">Create Adjustment</h3>
                    <button class="modal-close-btn" onclick="this.closest('.modal').remove()">&times;</button>
                </div>
                <div class="modal-body">
                    <form id="adjustment-form">
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Adjustment Type *</label>
                            <select id="adj-type" class="w-full px-4 py-2 border rounded-lg" required>
                                <option value="waste">Waste</option>
                                <option value="test">Test</option>
                                <option value="damage">Damage</option>
                                <option value="expired">Expired</option>
                                <option value="other">Other</option>
                            </select>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Batch ID (for raw materials)</label>
                            <input type="text" id="adj-batch-id" class="w-full px-4 py-2 border rounded-lg">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Lot ID (for finished products)</label>
                            <input type="text" id="adj-lot-id" class="w-full px-4 py-2 border rounded-lg">
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Quantity *</label>
                            <input type="number" step="0.01" min="0" id="adj-quantity" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Unit *</label>
                            <input type="text" id="adj-unit" class="w-full px-4 py-2 border rounded-lg" required>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">Reason *</label>
                            <textarea id="adj-reason" class="w-full px-4 py-2 border rounded-lg" rows="3" required></textarea>
                        </div>
                        <div class="mb-4">
                            <label class="block text-sm font-medium mb-2">External Reference ID</label>
                            <input type="text" id="adj-external-ref" class="w-full px-4 py-2 border rounded-lg" 
                                   value="ADJ-${Date.now()}">
                        </div>
                        <div class="flex gap-3">
                            <button type="submit" class="btn btn-primary flex-1">
                                <i class="fas fa-check"></i> Submit Adjustment
                            </button>
                            <button type="button" class="btn btn-outline" onclick="this.closest('.modal').remove()">
                                Cancel
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        document.getElementById('adjustment-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            const batchId = document.getElementById('adj-batch-id').value;
            const lotId = document.getElementById('adj-lot-id').value;

            if (!batchId && !lotId) {
                alert('Please provide either a Batch ID or Lot ID');
                return;
            }

            try {
                await QualityAPI.submitAdjustment({
                    type: document.getElementById('adj-type').value,
                    batch_id: batchId || null,
                    lot_id: lotId || null,
                    quantity: parseFloat(document.getElementById('adj-quantity').value),
                    unit: document.getElementById('adj-unit').value,
                    reason: document.getElementById('adj-reason').value,
                    external_reference_id: document.getElementById('adj-external-ref').value
                });
                alert('Adjustment submitted successfully!');
                modal.remove();
                this.loadAdjustments();
                // Refresh stock if on stock tab
                const stockTab = document.getElementById('tab-stock');
                if (stockTab && stockTab.classList.contains('active')) {
                    this.loadStock();
                }
            } catch (error) {
                alert(`Error submitting adjustment: ${error.message}`);
            }
        });
    },

    /**
     * Trace lot or batch
     */
    async traceLot() {
        const identifier = document.getElementById('trace-lot-input').value.trim();
        if (!identifier) {
            alert('Please enter a Lot ID or Batch ID');
            return;
        }

        const tbody = document.getElementById('traceability-table-body');
        const resultsDiv = document.getElementById('traceability-results');
        const chainDiv = document.getElementById('traceability-chain');
        
        this.showLoading('traceability-table-body');
        resultsDiv.classList.add('hidden');

        try {
            const data = await QualityAPI.traceByLot(identifier);
            
            if (!data || !data.chain || data.chain.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="text-center py-8 text-gray-500">No traceability data found for this identifier</td></tr>';
                return;
            }

            // Display traceability chain
            chainDiv.innerHTML = data.chain.map((step, index) => `
                <div class="flex items-center gap-3 ${index < data.chain.length - 1 ? 'mb-2' : ''}">
                    <div class="flex-shrink-0 w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center font-bold">
                        ${index + 1}
                    </div>
                    <div class="flex-1">
                        <div class="font-medium">${step.type || 'Transaction'}</div>
                        <div class="text-sm text-gray-600">${step.description || step.reference_id || ''}</div>
                        <div class="text-xs text-gray-500">${this.formatDate(step.date || step.created_at)}</div>
                    </div>
                </div>
                ${index < data.chain.length - 1 ? '<div class="ml-4 border-l-2 border-blue-300 h-4"></div>' : ''}
            `).join('');
            resultsDiv.classList.remove('hidden');

            // Display detailed table
            tbody.innerHTML = data.chain.map(step => `
                <tr>
                    <td><span class="px-2 py-1 rounded text-xs bg-blue-100">${step.type || 'N/A'}</span></td>
                    <td class="font-mono">${step.reference_id || step.id || 'N/A'}</td>
                    <td>${step.item_name || step.material_name || step.product_name || 'N/A'}</td>
                    <td>${step.quantity || 0}</td>
                    <td>${this.formatDate(step.date || step.created_at)}</td>
                    <td>${step.location || 'N/A'}</td>
                    <td class="font-mono text-xs">${step.external_reference_id || 'N/A'}</td>
                </tr>
            `).join('');
        } catch (error) {
            this.showError('traceability-table-body', `Error tracing: ${error.message}`);
        }
    },

    /**
     * Simulate recall
     */
    async simulateRecall() {
        const lotId = prompt('Enter Lot ID to recall:');
        if (!lotId) return;

        const reason = prompt('Enter recall reason:', 'Quality issue detected');
        if (!reason) return;

        try {
            const data = await QualityAPI.simulateRecall(lotId, reason);
            alert(`Recall simulation completed!\n\nAffected lots: ${data.affected_lots || 0}\nAffected batches: ${data.affected_batches || 0}\n\nReference: ${data.external_reference_id || 'N/A'}`);
        } catch (error) {
            alert(`Error simulating recall: ${error.message}`);
        }
    }
};

// Initialize stock location filter change handler
document.addEventListener('DOMContentLoaded', () => {
    const locationFilter = document.getElementById('stock-location-filter');
    if (locationFilter) {
        locationFilter.addEventListener('change', () => {
            qualityUI.loadStock();
        });
    }
});

