import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://kexwnurwavszvmlpifsf.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtleHdudXJ3YXZzenZtbHBpZnNmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzk5OTksImV4cCI6MjA4MDg1NTk5OX0.w7RlFdXVFdKtqJJ99L0Q1ofzUiwillyy-g1ASEj1q-U'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Helper functions
export async function getItems() {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*')
    .order('created_at', { ascending: false })
  
  if (error) throw error
  return data
}

export async function getItemById(id) {
  const { data, error } = await supabase
    .from('inventory_items')
    .select('*')
    .eq('id', id)
    .single()
  
  if (error) throw error
  return data
}

export async function createItem(item) {
  const { data, error } = await supabase
    .from('inventory_items')
    .insert([item])
    .select()
    .single()
  
  if (error) throw error
  return data
}

export async function updateItem(id, updates) {
  const { data, error } = await supabase
    .from('inventory_items')
    .update(updates)
    .eq('id', id)
    .select()
    .single()
  
  if (error) throw error
  return data
}

export async function deleteItem(id) {
  const { error } = await supabase
    .from('inventory_items')
    .delete()
    .eq('id', id)
  
  if (error) throw error
}

export async function getCategories() {
  const { data, error } = await supabase
    .from('inventory_categories')
    .select('*')
    .eq('deleted', false)
    .order('name', { ascending: true })
  
  if (error) throw error
  return data
}

export async function createCategory(category) {
  const { data, error } = await supabase
    .from('inventory_categories')
    .insert([category])
    .select()
    .single()
  
  if (error) throw error
  return data
}

export async function updateCategory(id, updates) {
  const { data, error } = await supabase
    .from('inventory_categories')
    .update(updates)
    .eq('id', id)
    .select()
    .single()
  
  if (error) throw error
  return data
}

export async function deleteCategory(id) {
  const { error } = await supabase
    .from('inventory_categories')
    .update({ deleted: true })
    .eq('id', id)
  
  if (error) throw error
}
