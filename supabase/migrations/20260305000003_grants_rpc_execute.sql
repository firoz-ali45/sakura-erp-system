-- Grant EXECUTE on RPCs so frontend (anon/authenticated) can call them.
-- Run this if the RPCs exist but the API returns permission denied.

GRANT EXECUTE ON FUNCTION public.fn_get_pr_item_summary(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_get_pr_item_summary(uuid) TO anon;

GRANT EXECUTE ON FUNCTION public.fn_can_create_next_document(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_can_create_next_document(text, text) TO anon;
