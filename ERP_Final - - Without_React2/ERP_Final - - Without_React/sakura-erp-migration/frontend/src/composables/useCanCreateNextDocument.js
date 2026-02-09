/**
 * Button auto-hide: use Supabase fn_can_create_next_document(doc_type, doc_id).
 * No manual button logic — DB is source of truth.
 */
import { ref, watch } from 'vue';
import { canCreateNextDocument } from '@/services/erpViews.js';

/**
 * @param {import('vue').Ref<string>} docTypeRef - 'PR' | 'PO' | 'GRN' | 'PURCHASE'
 * @param {import('vue').Ref<string>} docIdRef - document id
 * @returns {import('vue').Ref<boolean>} canCreate - true if "Create next" button should show
 */
export function useCanCreateNextDocument(docTypeRef, docIdRef) {
  const canCreate = ref(false);

  async function refresh() {
    const docType = docTypeRef?.value ?? docTypeRef;
    const docId = docIdRef?.value ?? docIdRef;
    if (!docType || !docId) {
      canCreate.value = false;
      return;
    }
    canCreate.value = await canCreateNextDocument(docType, docId);
  }

  if (docTypeRef && typeof docTypeRef === 'object' && 'value' in docTypeRef) {
    watch([docTypeRef, docIdRef], refresh, { immediate: true });
  }

  return { canCreate, refresh };
}

/**
 * One-off check (e.g. for list rows). Returns Promise<boolean>.
 */
export { canCreateNextDocument };
