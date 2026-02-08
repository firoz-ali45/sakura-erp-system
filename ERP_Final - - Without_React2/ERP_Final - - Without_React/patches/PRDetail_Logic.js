// REPLACE `canConvertToPO` in PRDetail.vue with this:
// This uses the Enterprise DB column `quantity_remaining` instead of frontend math.

const canConvertToPO = computed(() => {
    if (!pr.value) return false;

    // Status check
    if (!['approved', 'partially_ordered'].includes(pr.value.status)) return false;

    // Check DB-calculated remaining quantity
    // Now simpler and safer because triggers maintain quantity_remaining
    const items = pr.value.items || [];
    return items.some(item => parseFloat(item.quantity_remaining) > 0);
});

// REPLACEMENT: Calculate ordered percentage using DB fields for accuracy
const orderedPercentage = computed(() => {
    if (!pr.value?.items) return 0;

    const totalQty = pr.value.items.reduce((sum, item) => sum + (parseFloat(item.quantity) || 0), 0);
    const orderedQty = pr.value.items.reduce((sum, item) => sum + (parseFloat(item.quantity_ordered) || 0), 0);

    if (totalQty === 0) return 0;
    return Math.round((orderedQty / totalQty) * 100);
});
