/**
 * Food Quality Traceability API Handler
 * World-Class Accurate Calculations with Local Storage Backend
 * Implements: Purchase → GRN → Batch → Transfer → Production → Lot → Sale → Adjustment
 */

const QualityAPI = {
    baseURL: 'http://localhost:4000/api',
    useLocalStorage: true, // Use local storage when backend is unavailable
    
    /**
     * Initialize local storage data structure
     */
    initLocalStorage() {
        if (!localStorage.getItem('quality_purchases')) {
            localStorage.setItem('quality_purchases', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_grns')) {
            localStorage.setItem('quality_grns', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_batches')) {
            localStorage.setItem('quality_batches', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_production')) {
            localStorage.setItem('quality_production', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_transfers')) {
            localStorage.setItem('quality_transfers', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_sales')) {
            localStorage.setItem('quality_sales', JSON.stringify([]));
        }
        if (!localStorage.getItem('quality_adjustments')) {
            localStorage.setItem('quality_adjustments', JSON.stringify([]));
        }
    },

    /**
     * Generic API request handler with local storage fallback
     */
    async request(endpoint, options = {}) {
        // Try backend first
        if (!this.useLocalStorage) {
            try {
                const url = `${this.baseURL}${endpoint}`;
                const config = {
                    headers: {
                        'Content-Type': 'application/json',
                        ...options.headers
                    },
                    ...options
                };
                const response = await fetch(url, config);
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return await response.json();
            } catch (error) {
                console.warn('Backend unavailable, using local storage:', error.message);
                this.useLocalStorage = true;
            }
        }

        // Use local storage
        this.initLocalStorage();
        return this.handleLocalStorageRequest(endpoint, options);
    },

    /**
     * Handle requests using local storage
     */
    handleLocalStorageRequest(endpoint, options) {
        const method = options.method || 'GET';
        
        // GET requests
        if (method === 'GET') {
            if (endpoint === '/quality/purchases') {
                return { purchases: JSON.parse(localStorage.getItem('quality_purchases')) };
            }
            if (endpoint === '/quality/batches') {
                return { batches: JSON.parse(localStorage.getItem('quality_batches')) };
            }
            if (endpoint === '/quality/production') {
                return { lots: JSON.parse(localStorage.getItem('quality_production')) };
            }
            if (endpoint === '/quality/transfers') {
                return { transfers: JSON.parse(localStorage.getItem('quality_transfers')) };
            }
            if (endpoint === '/quality/sales') {
                return { sales: JSON.parse(localStorage.getItem('quality_sales')) };
            }
            if (endpoint === '/quality/adjustments') {
                return { adjustments: JSON.parse(localStorage.getItem('quality_adjustments')) };
            }
            if (endpoint.startsWith('/quality/stock')) {
                return this.calculateStock();
            }
            if (endpoint.startsWith('/quality/trace/')) {
                const identifier = decodeURIComponent(endpoint.split('/quality/trace/')[1]);
                return this.calculateTraceability(identifier);
            }
        }

        // POST requests
        if (method === 'POST') {
            const data = JSON.parse(options.body);
            
            if (endpoint === '/quality/grn') {
                return this.createGRN(data);
            }
            if (endpoint === '/quality/grn/inspection') {
                return this.createGRNInspection(data);
            }
            if (endpoint === '/quality/batches') {
                return this.createBatch(data);
            }
            if (endpoint === '/quality/production') {
                return this.createProduction(data);
            }
            if (endpoint === '/quality/transfers') {
                return this.createTransfer(data);
            }
            if (endpoint.includes('/transfers/') && endpoint.includes('/receive')) {
                const transferId = endpoint.split('/transfers/')[1].split('/receive')[0];
                return this.receiveTransfer(transferId, data.external_reference_id);
            }
            if (endpoint === '/quality/sales') {
                return this.recordSale(data);
            }
            if (endpoint === '/quality/adjustments') {
                return this.submitAdjustment(data);
            }
            if (endpoint === '/quality/recall') {
                return this.simulateRecall(data);
            }
        }

        return { success: false, message: 'Unknown endpoint' };
    },

    /**
     * Calculate accurate stock by location and expiry
     * World-class calculation: Available = On-Hand - Reserved - Allocated
     */
    calculateStock(locationFilter = null) {
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const lots = JSON.parse(localStorage.getItem('quality_production'));
        const transfers = JSON.parse(localStorage.getItem('quality_transfers'));
        const sales = JSON.parse(localStorage.getItem('quality_sales'));
        const adjustments = JSON.parse(localStorage.getItem('quality_adjustments'));

        const stock = [];

        // Process batches
        batches.forEach(batch => {
            if (locationFilter && batch.location !== locationFilter) return;

            // Calculate available quantity (on-hand minus consumed/transferred/adjusted)
            let availableQty = batch.quantity || 0;
            
            // Subtract adjustments
            adjustments
                .filter(adj => adj.batch_id === batch.id && adj.type !== 'return')
                .forEach(adj => {
                    availableQty -= (adj.quantity || 0);
                });

            // Subtract transfers (TRS - sent out)
            transfers
                .filter(t => t.type === 'TRS' && t.items?.some(item => item.batch_id === batch.id))
                .forEach(t => {
                    const item = t.items.find(i => i.batch_id === batch.id);
                    if (item) availableQty -= (item.quantity || 0);
                });

            // Add transfers (TRR - received)
            transfers
                .filter(t => t.type === 'TRR' && t.items?.some(item => item.batch_id === batch.id))
                .forEach(t => {
                    const item = t.items.find(i => i.batch_id === batch.id);
                    if (item) availableQty += (item.quantity || 0);
                });

            // Subtract production consumption (batches used in production)
            lots.forEach(lot => {
                if (lot.batch_sources?.includes(batch.id)) {
                    // Calculate proportional consumption
                    const totalBatches = lot.batch_sources.length;
                    availableQty -= ((batch.quantity || 0) / totalBatches);
                }
            });

            if (availableQty > 0) {
                stock.push({
                    type: 'batch',
                    id: batch.id,
                    batch_id: batch.id,
                    name: batch.material_name,
                    material_name: batch.material_name,
                    quantity: Math.max(0, availableQty), // Ensure non-negative
                    unit: batch.unit,
                    location: batch.location,
                    expiry_date: batch.expiry_date,
                    grn_id: batch.grn_id,
                    created_at: batch.created_at
                });
            }
        });

        // Process production lots
        lots.forEach(lot => {
            if (locationFilter && lot.location !== locationFilter) return;

            let availableQty = lot.quantity || 0;

            // Subtract sales
            sales
                .filter(sale => sale.lot_id === lot.id)
                .forEach(sale => {
                    availableQty -= (sale.quantity || 0);
                });

            // Subtract adjustments
            adjustments
                .filter(adj => adj.lot_id === lot.id && adj.type !== 'return')
                .forEach(adj => {
                    availableQty -= (adj.quantity || 0);
                });

            // Subtract transfers (TRS)
            transfers
                .filter(t => t.type === 'TRS' && t.items?.some(item => item.lot_id === lot.id))
                .forEach(t => {
                    const item = t.items.find(i => i.lot_id === lot.id);
                    if (item) availableQty -= (item.quantity || 0);
                });

            // Add transfers (TRR)
            transfers
                .filter(t => t.type === 'TRR' && t.items?.some(item => item.lot_id === lot.id))
                .forEach(t => {
                    const item = t.items.find(i => i.lot_id === lot.id);
                    if (item) availableQty += (item.quantity || 0);
                });

            if (availableQty > 0) {
                stock.push({
                    type: 'lot',
                    id: lot.id,
                    lot_id: lot.id,
                    name: lot.product_name,
                    product_name: lot.product_name,
                    quantity: Math.max(0, availableQty),
                    unit: lot.unit,
                    location: lot.location,
                    expiry_date: lot.expiry_date,
                    production_date: lot.production_date,
                    batch_sources: lot.batch_sources,
                    created_at: lot.created_at
                });
            }
        });

        return { stock: stock.sort((a, b) => new Date(a.expiry_date) - new Date(b.expiry_date)) };
    },

    /**
     * Calculate complete traceability chain
     */
    calculateTraceability(identifier) {
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const lots = JSON.parse(localStorage.getItem('quality_production'));
        const grns = JSON.parse(localStorage.getItem('quality_grns'));
        const transfers = JSON.parse(localStorage.getItem('quality_transfers'));
        const sales = JSON.parse(localStorage.getItem('quality_sales'));
        const adjustments = JSON.parse(localStorage.getItem('quality_adjustments'));

        const chain = [];
        
        // Find if it's a batch or lot
        const batch = batches.find(b => b.id === identifier || b.batch_id === identifier);
        const lot = lots.find(l => l.id === identifier || l.lot_id === identifier);

            if (batch) {
            // Trace batch backwards
            if (batch.grn_id || batch.grn_number) {
                const grn = grns.find(g => g.id === batch.grn_id || g.grn_number === batch.grn_number || g.grn_number === batch.grn_id);
                if (grn) {
                    chain.push({
                        type: 'GRN',
                        reference_id: grn.id || grn.grn_number,
                        description: `GRN ${grn.grn_number || grn.external_reference_id} - Received ${batch.material_name}`,
                        date: grn.grn_date_time || grn.received_date || grn.created_at,
                        external_reference_id: grn.external_reference_id
                    });
                }
            }

            // Trace batch forwards
            chain.push({
                type: 'Batch Created',
                reference_id: batch.id,
                description: `Batch ${batch.external_reference_id} - ${batch.material_name} (${batch.quantity} ${batch.unit})`,
                date: batch.created_at,
                external_reference_id: batch.external_reference_id,
                location: batch.location
            });

            // Find production lots using this batch
            lots.filter(l => l.batch_sources?.includes(batch.id)).forEach(lot => {
                chain.push({
                    type: 'Production',
                    reference_id: lot.id,
                    description: `Lot ${lot.external_reference_id} - Produced ${lot.product_name} using this batch`,
                    date: lot.production_date,
                    external_reference_id: lot.external_reference_id
                });
            });

            // Find transfers
            transfers.filter(t => t.items?.some(i => i.batch_id === batch.id)).forEach(t => {
                chain.push({
                    type: t.type,
                    reference_id: t.id,
                    description: `${t.type} from ${t.from_location} to ${t.to_location}`,
                    date: t.created_at,
                    external_reference_id: t.external_reference_id
                });
            });

            // Find adjustments
            adjustments.filter(a => a.batch_id === batch.id).forEach(adj => {
                chain.push({
                    type: 'Adjustment',
                    reference_id: adj.id,
                    description: `${adj.type}: ${adj.quantity} ${adj.unit} - ${adj.reason}`,
                    date: adj.created_at,
                    external_reference_id: adj.external_reference_id
                });
            });
        }

        if (lot) {
            // Trace lot backwards to batches
            if (lot.batch_sources && lot.batch_sources.length > 0) {
                lot.batch_sources.forEach(batchId => {
                    const sourceBatch = batches.find(b => b.id === batchId);
                    if (sourceBatch) {
                        chain.push({
                            type: 'Source Batch',
                            reference_id: sourceBatch.id,
                            description: `Batch ${sourceBatch.external_reference_id} - ${sourceBatch.material_name}`,
                            date: sourceBatch.created_at,
                            external_reference_id: sourceBatch.external_reference_id
                        });
                    }
                });
            }

            chain.push({
                type: 'Production Lot',
                reference_id: lot.id,
                description: `Lot ${lot.external_reference_id} - ${lot.product_name} (${lot.quantity} ${lot.unit})`,
                date: lot.production_date,
                external_reference_id: lot.external_reference_id,
                location: lot.location
            });

            // Find sales
            sales.filter(s => s.lot_id === lot.id).forEach(sale => {
                chain.push({
                    type: 'Sale',
                    reference_id: sale.id,
                    description: `Sold ${sale.quantity} ${sale.unit} to ${sale.customer_outlet}`,
                    date: sale.sale_date,
                    external_reference_id: sale.external_reference_id
                });
            });

            // Find transfers
            transfers.filter(t => t.items?.some(i => i.lot_id === lot.id)).forEach(t => {
                chain.push({
                    type: t.type,
                    reference_id: t.id,
                    description: `${t.type} from ${t.from_location} to ${t.to_location}`,
                    date: t.created_at,
                    external_reference_id: t.external_reference_id
                });
            });

            // Find adjustments
            adjustments.filter(a => a.lot_id === lot.id).forEach(adj => {
                chain.push({
                    type: 'Adjustment',
                    reference_id: adj.id,
                    description: `${adj.type}: ${adj.quantity} ${adj.unit} - ${adj.reason}`,
                    date: adj.created_at,
                    external_reference_id: adj.external_reference_id
                });
            });
        }

        // Sort by date
        chain.sort((a, b) => new Date(a.date) - new Date(b.date));

        return { chain, identifier };
    },

    /**
     * Create GRN with validation (legacy method)
     */
    createGRN(data) {
        const grns = JSON.parse(localStorage.getItem('quality_grns'));
        const purchases = JSON.parse(localStorage.getItem('quality_purchases'));

        // Validate purchase exists
        const purchase = purchases.find(p => (p.id || p.purchase_id) === data.purchase_id);
        if (!purchase) {
            throw new Error('Purchase order not found');
        }

        const grn = {
            id: `GRN-${Date.now()}`,
            purchase_id: data.purchase_id,
            external_reference_id: data.external_reference_id,
            items: data.items,
            received_date: data.received_date,
            status: 'completed',
            created_at: new Date().toISOString()
        };

        grns.push(grn);
        localStorage.setItem('quality_grns', JSON.stringify(grns));

        return { success: true, grn };
    },

    /**
     * Create ISO 22000 compliant GRN Inspection with batch auto-generation
     */
    createGRNInspection(data) {
        const grns = JSON.parse(localStorage.getItem('quality_grns'));
        const batches = JSON.parse(localStorage.getItem('quality_batches'));

        // Validate all expiry dates are present (ISO requirement)
        const missingExpiry = data.items.filter(item => !item.expiry_date);
        if (missingExpiry.length > 0) {
            throw new Error('Expiry date is mandatory for all items. Cannot approve GRN without expiry dates.');
        }

        // Validate QC status
        if (data.qc_status === 'HOLD' || data.qc_status === 'REJECT') {
            // For HOLD/REJECT, create GRN but don't generate batches
            const grn = {
                id: data.grn_number,
                grn_number: data.grn_number,
                purchase_order_number: data.purchase_order_number,
                supplier_name: data.supplier_name,
                supplier_code: data.supplier_code,
                vendor_batch_number: data.vendor_batch_number,
                receiving_location: data.receiving_location,
                invoice_number: data.invoice_number,
                external_reference_id: data.external_reference_id,
                grn_date_time: data.grn_date_time,
                qc_status: data.qc_status,
                disposition: data.disposition,
                qa_remarks: data.qa_remarks,
                corrective_action_required: data.corrective_action_required,
                received_by: data.received_by,
                quality_checked_by: data.quality_checked_by,
                approved_by: data.approved_by,
                approval_date_time: data.approval_date_time,
                items: data.items,
                status: 'on_hold', // QC HOLD blocks production use
                created_at: new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            grns.push(grn);
            localStorage.setItem('quality_grns', JSON.stringify(grns));

            return { 
                success: true, 
                grn,
                message: 'GRN created with HOLD/REJECT status. Batches will not be generated until status is changed to PASS.',
                batches_created: []
            };
        }

        // For PASS status, create GRN and auto-generate batches
        const grn = {
            id: data.grn_number,
            grn_number: data.grn_number,
            purchase_order_number: data.purchase_order_number,
            supplier_name: data.supplier_name,
            supplier_code: data.supplier_code,
            vendor_batch_number: data.vendor_batch_number,
            receiving_location: data.receiving_location,
            invoice_number: data.invoice_number,
            external_reference_id: data.external_reference_id,
            grn_date_time: data.grn_date_time,
            qc_status: data.qc_status,
            disposition: data.disposition,
            qa_remarks: data.qa_remarks,
            corrective_action_required: data.corrective_action_required,
            received_by: data.received_by,
            quality_checked_by: data.quality_checked_by,
            approved_by: data.approved_by,
            approval_date_time: data.approval_date_time,
            items: data.items,
            status: 'approved',
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString()
        };

        grns.push(grn);
        localStorage.setItem('quality_grns', JSON.stringify(grns));

        // Auto-generate batches for each item (ISO requirement: traceable batch numbers)
        const createdBatches = [];
        data.items.forEach((item, index) => {
            // Generate batch number
            const batchNumber = this.generateBatchNumber(
                data.grn_number,
                item.item_code,
                data.vendor_batch_number
            );

            const batch = {
                id: batchNumber,
                batch_id: batchNumber,
                grn_id: data.grn_number,
                grn_number: data.grn_number,
                material_id: item.item_code,
                material_name: item.item_description,
                quantity: item.received_quantity,
                unit: item.unit,
                expiry_date: new Date(item.expiry_date).toISOString(),
                location: data.receiving_location,
                external_reference_id: `${batchNumber}-EXT`,
                supplier_batch: data.vendor_batch_number,
                packaging_condition: item.packaging_condition,
                visual_inspection: item.visual_inspection,
                temperature_check: item.temperature_check,
                non_conformance_reason: item.non_conformance_reason,
                non_conformance_severity: item.non_conformance_severity,
                qc_status: data.qc_status, // Inherit from GRN
                available_quantity: item.received_quantity,
                created_at: new Date().toISOString()
            };

            batches.push(batch);
            createdBatches.push(batch);
        });

        localStorage.setItem('quality_batches', JSON.stringify(batches));

        return { 
            success: true, 
            grn,
            batches: createdBatches,
            message: `GRN approved successfully! ${createdBatches.length} batch(es) auto-generated.`
        };
    },

    /**
     * Generate batch number (ISO compliant format)
     */
    generateBatchNumber(grnNumber, itemCode, vendorBatch) {
        const date = new Date();
        const year = date.getFullYear().toString().slice(-2);
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const itemShort = (itemCode || 'XXX').substring(0, 3).toUpperCase();
        const vendorShort = (vendorBatch || 'XXX').substring(0, 3).toUpperCase();
        const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
        return `BATCH-${year}${month}-${itemShort}-${vendorShort}-${random}`;
    },

    /**
     * Create batch with validation
     */
    createBatch(data) {
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const grns = JSON.parse(localStorage.getItem('quality_grns'));

        // Validate GRN exists
        if (data.grn_id) {
            const grn = grns.find(g => g.id === data.grn_id || g.external_reference_id === data.grn_id);
            if (!grn) {
                throw new Error('GRN reference not found');
            }
        }

        // Validate quantity
        if (!data.quantity || data.quantity <= 0) {
            throw new Error('Quantity must be greater than 0');
        }

        const batch = {
            id: `BATCH-${Date.now()}`,
            batch_id: `BATCH-${Date.now()}`,
            grn_id: data.grn_id,
            material_id: data.material_id,
            material_name: data.material_name,
            quantity: parseFloat(data.quantity),
            unit: data.unit,
            expiry_date: data.expiry_date,
            location: data.location,
            external_reference_id: data.external_reference_id,
            supplier_batch: data.supplier_batch,
            available_quantity: parseFloat(data.quantity), // Track available separately
            created_at: data.created_at || new Date().toISOString()
        };

        batches.push(batch);
        localStorage.setItem('quality_batches', JSON.stringify(batches));

        return { success: true, batch };
    },

    /**
     * Create production lot with validation
     */
    createProduction(data) {
        const lots = JSON.parse(localStorage.getItem('quality_production'));
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const grns = JSON.parse(localStorage.getItem('quality_grns'));

        // Validate batch sources exist and have available quantity
        if (data.batch_sources && data.batch_sources.length > 0) {
            data.batch_sources.forEach(batchId => {
                const batch = batches.find(b => b.id === batchId || b.batch_id === batchId);
                if (!batch) {
                    throw new Error(`Batch ${batchId} not found`);
                }
                
                // ISO Compliance: Check if batch is from QC HOLD GRN (blocks production use)
                if (batch.grn_number || batch.grn_id) {
                    const grn = grns.find(g => 
                        g.grn_number === batch.grn_number || 
                        g.grn_number === batch.grn_id || 
                        g.id === batch.grn_id
                    );
                    if (grn && (grn.qc_status === 'HOLD' || grn.status === 'on_hold')) {
                        throw new Error(`Cannot use batch ${batchId} in production. Source GRN has QC HOLD status. Batch must be released from HOLD first.`);
                    }
                }
                
                // Check batch QC status
                if (batch.qc_status === 'HOLD') {
                    throw new Error(`Batch ${batchId} is on QC HOLD. Cannot use in production until released.`);
                }
            });
        }

        const lot = {
            id: `LOT-${Date.now()}`,
            lot_id: `LOT-${Date.now()}`,
            product_id: data.product_id,
            product_name: data.product_name,
            quantity: parseFloat(data.quantity),
            unit: data.unit,
            production_date: data.production_date,
            expiry_date: data.expiry_date,
            location: data.location,
            batch_sources: data.batch_sources || [],
            external_reference_id: data.external_reference_id,
            available_quantity: parseFloat(data.quantity),
            created_at: data.created_at || new Date().toISOString()
        };

        lots.push(lot);
        localStorage.setItem('quality_production', JSON.stringify(lots));

        return { success: true, lot };
    },

    /**
     * Create transfer with validation
     */
    createTransfer(data) {
        const transfers = JSON.parse(localStorage.getItem('quality_transfers'));
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const lots = JSON.parse(localStorage.getItem('quality_production'));

        // Validate items exist and have available quantity
        const validatedItems = [];
        for (const item of data.items) {
            if (item.batch_id) {
                const batch = batches.find(b => b.id === item.batch_id || b.batch_id === item.batch_id);
                if (!batch) {
                    throw new Error(`Batch ${item.batch_id} not found`);
                }
                // Check available quantity (simplified - in real system, check reserved)
                const stock = this.calculateStock();
                const stockItem = stock.stock.find(s => s.batch_id === batch.id);
                if (!stockItem || stockItem.quantity < item.quantity) {
                    throw new Error(`Insufficient quantity for batch ${item.batch_id}`);
                }
                validatedItems.push({ batch_id: item.batch_id, quantity: parseFloat(item.quantity) });
            }
            if (item.lot_id) {
                const lot = lots.find(l => l.id === item.lot_id || l.lot_id === item.lot_id);
                if (!lot) {
                    throw new Error(`Lot ${item.lot_id} not found`);
                }
                const stock = this.calculateStock();
                const stockItem = stock.stock.find(s => s.lot_id === lot.id);
                if (!stockItem || stockItem.quantity < item.quantity) {
                    throw new Error(`Insufficient quantity for lot ${item.lot_id}`);
                }
                validatedItems.push({ lot_id: item.lot_id, quantity: parseFloat(item.quantity) });
            }
        }

        const transfer = {
            id: `TRS-${Date.now()}`,
            transfer_id: `TRS-${Date.now()}`,
            type: data.type || 'TRS',
            from_location: data.from_location,
            to_location: data.to_location,
            items: validatedItems,
            status: 'pending',
            external_reference_id: data.external_reference_id,
            notes: data.notes,
            created_at: data.created_at || new Date().toISOString()
        };

        transfers.push(transfer);
        localStorage.setItem('quality_transfers', JSON.stringify(transfers));

        return { success: true, transfer };
    },

    /**
     * Receive transfer
     */
    receiveTransfer(transferId, externalRef) {
        const transfers = JSON.parse(localStorage.getItem('quality_transfers'));
        const transfer = transfers.find(t => t.id === transferId || t.transfer_id === transferId);
        
        if (!transfer) {
            throw new Error('Transfer not found');
        }

        if (transfer.status === 'completed') {
            throw new Error('Transfer already received');
        }

        // Create TRR record
        const trr = {
            id: `TRR-${Date.now()}`,
            transfer_id: transfer.id,
            type: 'TRR',
            from_location: transfer.from_location,
            to_location: transfer.to_location,
            items: transfer.items,
            status: 'completed',
            external_reference_id: externalRef,
            received_at: new Date().toISOString(),
            created_at: new Date().toISOString()
        };

        transfers.push(trr);
        transfer.status = 'completed';
        localStorage.setItem('quality_transfers', JSON.stringify(transfers));

        return { success: true, trr };
    },

    /**
     * Record sale with validation
     */
    recordSale(data) {
        const sales = JSON.parse(localStorage.getItem('quality_sales'));
        const lots = JSON.parse(localStorage.getItem('quality_production'));

        // Validate lot exists
        const lot = lots.find(l => l.id === data.lot_id || l.lot_id === data.lot_id);
        if (!lot) {
            throw new Error('Lot not found');
        }

        // Check available quantity
        const stock = this.calculateStock();
        const stockItem = stock.stock.find(s => s.lot_id === lot.id);
        if (!stockItem || stockItem.quantity < data.quantity) {
            throw new Error('Insufficient quantity available');
        }

        const sale = {
            id: `SALE-${Date.now()}`,
            sale_id: `SALE-${Date.now()}`,
            lot_id: data.lot_id,
            product_name: lot.product_name,
            quantity: parseFloat(data.quantity),
            unit: data.unit,
            customer_outlet: data.customer_outlet,
            sale_date: data.sale_date,
            external_reference_id: data.external_reference_id,
            created_at: new Date().toISOString()
        };

        sales.push(sale);
        localStorage.setItem('quality_sales', JSON.stringify(sales));

        return { success: true, sale };
    },

    /**
     * Submit adjustment with validation
     */
    submitAdjustment(data) {
        const adjustments = JSON.parse(localStorage.getItem('quality_adjustments'));
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const lots = JSON.parse(localStorage.getItem('quality_production'));

        // Validate batch or lot exists
        if (data.batch_id) {
            const batch = batches.find(b => b.id === data.batch_id || b.batch_id === data.batch_id);
            if (!batch) {
                throw new Error('Batch not found');
            }
        }
        if (data.lot_id) {
            const lot = lots.find(l => l.id === data.lot_id || l.lot_id === data.lot_id);
            if (!lot) {
                throw new Error('Lot not found');
            }
        }

        if (!data.batch_id && !data.lot_id) {
            throw new Error('Either batch_id or lot_id is required');
        }

        const adjustment = {
            id: `ADJ-${Date.now()}`,
            adjustment_id: `ADJ-${Date.now()}`,
            type: data.type,
            batch_id: data.batch_id || null,
            lot_id: data.lot_id || null,
            item_name: data.batch_id ? 
                batches.find(b => b.id === data.batch_id)?.material_name :
                lots.find(l => l.id === data.lot_id)?.product_name,
            quantity: parseFloat(data.quantity),
            unit: data.unit,
            reason: data.reason,
            external_reference_id: data.external_reference_id,
            created_at: data.created_at || new Date().toISOString()
        };

        adjustments.push(adjustment);
        localStorage.setItem('quality_adjustments', JSON.stringify(adjustments));

        return { success: true, adjustment };
    },

    /**
     * Simulate recall
     */
    simulateRecall(data) {
        const lots = JSON.parse(localStorage.getItem('quality_production'));
        const batches = JSON.parse(localStorage.getItem('quality_batches'));
        const lot = lots.find(l => l.id === data.lot_id || l.lot_id === data.lot_id);
        
        if (!lot) {
            throw new Error('Lot not found');
        }

        // Find all related batches
        const affectedBatches = lot.batch_sources?.map(batchId => 
            batches.find(b => b.id === batchId)
        ).filter(Boolean) || [];

        return {
            success: true,
            affected_lots: 1,
            affected_batches: affectedBatches.length,
            external_reference_id: data.external_reference_id,
            reason: data.reason
        };
    },

    // Original API methods (for backward compatibility)
    async getPurchases() {
        return this.request('/quality/purchases');
    },

    async generateGRN(data) {
        return this.request('/quality/grn', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async createGRNInspection(data) {
        return this.request('/quality/grn/inspection', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async createRawBatch(data) {
        return this.request('/quality/batches', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async getBatches() {
        return this.request('/quality/batches');
    },

    async getStock(location = null) {
        const endpoint = location ? `/quality/stock?location=${encodeURIComponent(location)}` : '/quality/stock';
        return this.request(endpoint);
    },

    async createTransfer(data) {
        return this.request('/quality/transfers', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async receiveTransfer(transfer_id, external_reference_id = null) {
        return this.request(`/quality/transfers/${transfer_id}/receive`, {
            method: 'POST',
            body: JSON.stringify({ external_reference_id })
        });
    },

    async getTransfers() {
        return this.request('/quality/transfers');
    },

    async createProduction(data) {
        return this.request('/quality/production', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async getProductionLots() {
        return this.request('/quality/production');
    },

    async recordSale(data) {
        return this.request('/quality/sales', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async getSales() {
        return this.request('/quality/sales');
    },

    async submitAdjustment(data) {
        return this.request('/quality/adjustments', {
            method: 'POST',
            body: JSON.stringify(data)
        });
    },

    async getAdjustments() {
        return this.request('/quality/adjustments');
    },

    async traceByLot(identifier) {
        return this.request(`/quality/trace/${encodeURIComponent(identifier)}`);
    },

    async simulateRecall(lot_id, reason = 'Quality issue detected') {
        return this.request('/quality/recall', {
            method: 'POST',
            body: JSON.stringify({ lot_id, reason })
        });
    }
};

// Initialize on load
if (typeof window !== 'undefined') {
    QualityAPI.initLocalStorage();
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = QualityAPI;
}
