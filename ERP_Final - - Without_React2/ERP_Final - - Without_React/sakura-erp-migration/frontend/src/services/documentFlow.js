import { supabaseClient, ensureSupabaseReady } from './supabase';

/**
 * Get the full document flow for any document in the chain (PR -> PO -> GRN -> INV -> PAY)
 * This enhanced version handles cases where document_flow table might be empty
 * by falling back to direct table relationships.
 * 
 * @param {string} docType - Type of document ('pr', 'po', 'grn', 'invoice', 'payment')
 * @param {string} docId - ID of the document
 * @returns {Promise<Array>} List of flow nodes in order
 */
export async function getFullDocumentFlow(docType, docId) {
    const ready = await ensureSupabaseReady();
    if (!ready) return [];

    try {
        console.log('📊 Loading document flow for:', docType, docId);
        
        const normalizedType = docType?.toLowerCase() || '';
        const nodes = [];
        
        // Determine what type of document we're dealing with
        let prId = null, poId = null, grnId = null, invId = null;
        
        // STEP 1: Identify the current document and trace back to PR
        if (normalizedType.includes('request') || normalizedType === 'pr') {
            prId = docId;
        } else if (normalizedType.includes('order') || normalizedType === 'po') {
            poId = docId;
        } else if (normalizedType.includes('receipt') || normalizedType === 'grn') {
            grnId = docId;
        } else if (normalizedType.includes('invoice') || normalizedType === 'inv') {
            invId = docId;
        }
        
        // STEP 2: Trace backwards to find the root (PR)
        // From Invoice -> GRN -> PO -> PR
        if (invId && !grnId) {
            const { data: inv } = await supabaseClient
                .from('purchasing_invoices')
                .select('grn_id, purchase_order_id')
                .eq('id', invId)
                .single();
            if (inv?.grn_id) grnId = inv.grn_id;
            if (inv?.purchase_order_id) poId = inv.purchase_order_id;
        }
        
        if (grnId && !poId) {
            const { data: grn } = await supabaseClient
                .from('grn_inspections')
                .select('purchase_order_id')
                .eq('id', grnId)
                .single();
            if (grn?.purchase_order_id) poId = grn.purchase_order_id;
        }
        
        if (poId && !prId) {
            // Try to find PR from pr_po_linkage
            const { data: linkage } = await supabaseClient
                .from('pr_po_linkage')
                .select('pr_id')
                .eq('po_id', poId)
                .eq('status', 'active')
                .limit(1);
            if (linkage?.[0]?.pr_id) prId = linkage[0].pr_id;
            
            // Also try from purchase_request_items.po_id
            if (!prId) {
                const { data: items } = await supabaseClient
                    .from('purchase_request_items')
                    .select('pr_id')
                    .eq('po_id', poId)
                    .limit(1);
                if (items?.[0]?.pr_id) prId = items[0].pr_id;
            }
        }
        
        // STEP 3: Now build the flow from top to bottom
        
        // Add PR if found
        if (prId) {
            const { data: pr } = await supabaseClient
                .from('purchase_requests')
                .select('id, pr_number, status')
                .eq('id', prId)
                .single();
            if (pr) {
                nodes.push({
                    type: 'pr',
                    id: pr.id,
                    number: pr.pr_number,
                    status: pr.status,
                    isCurrent: normalizedType.includes('request') || normalizedType === 'pr'
                });
            }
        }
        
        // Get all linked POs (from PR or directly)
        let poIds = [];
        if (prId) {
            // Get POs linked to this PR
            const { data: linkages } = await supabaseClient
                .from('pr_po_linkage')
                .select('po_id')
                .eq('pr_id', prId)
                .eq('status', 'active');
            
            if (linkages?.length) {
                poIds = [...new Set(linkages.map(l => l.po_id).filter(Boolean))];
            }
            
            // Also check purchase_request_items
            const { data: prItems } = await supabaseClient
                .from('purchase_request_items')
                .select('po_id')
                .eq('pr_id', prId)
                .not('po_id', 'is', null);
            
            if (prItems?.length) {
                prItems.forEach(i => {
                    if (i.po_id && !poIds.includes(i.po_id)) poIds.push(i.po_id);
                });
            }
        } else if (poId) {
            poIds = [poId];
        }
        
        // Add POs
        if (poIds.length > 0) {
            const { data: pos } = await supabaseClient
                .from('purchase_orders')
                .select('id, po_number, status')
                .in('id', poIds);
            
            if (pos?.length) {
                for (const po of pos) {
                    nodes.push({
                        type: 'po',
                        id: po.id,
                        number: po.po_number,
                        status: po.status,
                        isCurrent: (normalizedType.includes('order') || normalizedType === 'po') && po.id == docId
                    });
                }
            }
        }
        
        // Get all GRNs for these POs
        let grnIds = [];
        if (poIds.length > 0) {
            const { data: grns } = await supabaseClient
                .from('grn_inspections')
                .select('id, grn_number, status, purchase_order_id')
                .in('purchase_order_id', poIds)
                .eq('deleted', false);
            
            if (grns?.length) {
                for (const grn of grns) {
                    grnIds.push(grn.id);
                    nodes.push({
                        type: 'grn',
                        id: grn.id,
                        number: grn.grn_number,
                        status: grn.status,
                        isCurrent: (normalizedType.includes('receipt') || normalizedType === 'grn') && grn.id === docId
                    });
                }
            }
        } else if (grnId) {
            grnIds = [grnId];
            const { data: grn } = await supabaseClient
                .from('grn_inspections')
                .select('id, grn_number, status')
                .eq('id', grnId)
                .single();
            if (grn) {
                nodes.push({
                    type: 'grn',
                    id: grn.id,
                    number: grn.grn_number,
                    status: grn.status,
                    isCurrent: normalizedType.includes('receipt') || normalizedType === 'grn'
                });
            }
        }
        
        // Get all Invoices for these GRNs
        let invIds = [];
        if (grnIds.length > 0) {
            const { data: invs } = await supabaseClient
                .from('purchasing_invoices')
                .select('id, purchasing_number, invoice_number, status, grn_id')
                .in('grn_id', grnIds)
                .eq('deleted', false);
            
            if (invs?.length) {
                for (const inv of invs) {
                    invIds.push(inv.id);
                    nodes.push({
                        type: 'invoice',
                        id: inv.id,
                        number: inv.purchasing_number || inv.invoice_number,
                        status: inv.status,
                        isCurrent: (normalizedType.includes('invoice') || normalizedType === 'inv') && inv.id === docId
                    });
                }
            }
        } else if (invId) {
            invIds = [invId];
            const { data: inv } = await supabaseClient
                .from('purchasing_invoices')
                .select('id, purchasing_number, invoice_number, status')
                .eq('id', invId)
                .single();
            if (inv) {
                nodes.push({
                    type: 'invoice',
                    id: inv.id,
                    number: inv.purchasing_number || inv.invoice_number,
                    status: inv.status,
                    isCurrent: normalizedType.includes('invoice') || normalizedType === 'inv'
                });
            }
        }
        
        // Get all Payments for these Invoices
        if (invIds.length > 0) {
            const { data: payments } = await supabaseClient
                .from('ap_payments')
                .select('id, payment_number, status, purchasing_invoice_id')
                .in('purchasing_invoice_id', invIds);
            
            if (payments?.length) {
                for (const pmt of payments) {
                    nodes.push({
                        type: 'payment',
                        id: pmt.id,
                        number: pmt.payment_number,
                        status: pmt.status,
                        isCurrent: normalizedType.includes('payment') && pmt.id === docId
                    });
                }
            }
        }
        
        // If no nodes found but we have the current doc, at least show it
        if (nodes.length === 0) {
            nodes.push({
                type: docType,
                id: docId,
                number: 'Current',
                isCurrent: true
            });
        }
        
        // Remove duplicates based on id
        const uniqueNodes = [];
        const seenIds = new Set();
        for (const node of nodes) {
            if (!seenIds.has(node.id)) {
                seenIds.add(node.id);
                uniqueNodes.push(node);
            }
        }
        
        // Sort by type order
        const typeOrder = {
            'pr': 1, 'purchase_request': 1,
            'po': 2, 'purchase_order': 2,
            'grn': 3, 'goods_receipt': 3,
            'invoice': 4, 'purchasing_invoice': 4, 'inv': 4,
            'payment': 5, 'ap_payment': 5
        };
        
        uniqueNodes.sort((a, b) => {
            const orderA = typeOrder[a.type?.toLowerCase()] || 99;
            const orderB = typeOrder[b.type?.toLowerCase()] || 99;
            return orderA - orderB;
        });
        
        console.log('📊 Document flow result:', uniqueNodes);
        return uniqueNodes;

    } catch (error) {
        console.error('Error fetching full document flow:', error);
        return [];
    }
}
