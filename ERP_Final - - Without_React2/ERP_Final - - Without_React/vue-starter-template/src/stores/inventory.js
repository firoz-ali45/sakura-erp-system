import { defineStore } from 'pinia'
import { getItems, getItemById, createItem, updateItem, deleteItem } from '../lib/supabase'

export const useInventoryStore = defineStore('inventory', {
  state: () => ({
    items: [],
    currentItem: null,
    loading: false,
    error: null
  }),

  getters: {
    itemsByCategory: (state) => (category) => {
      return state.items.filter(item => item.category === category)
    }
  },

  actions: {
    async loadItems() {
      this.loading = true
      this.error = null
      try {
        this.items = await getItems()
      } catch (error) {
        this.error = error.message
        console.error('Error loading items:', error)
      } finally {
        this.loading = false
      }
    },

    async loadItem(id) {
      this.loading = true
      this.error = null
      try {
        this.currentItem = await getItemById(id)
      } catch (error) {
        this.error = error.message
        console.error('Error loading item:', error)
      } finally {
        this.loading = false
      }
    },

    async addItem(item) {
      this.loading = true
      this.error = null
      try {
        const newItem = await createItem(item)
        this.items.unshift(newItem)
        return newItem
      } catch (error) {
        this.error = error.message
        throw error
      } finally {
        this.loading = false
      }
    },

    async updateItem(id, updates) {
      this.loading = true
      this.error = null
      try {
        const updated = await updateItem(id, updates)
        const index = this.items.findIndex(item => item.id === id)
        if (index !== -1) {
          this.items[index] = updated
        }
        return updated
      } catch (error) {
        this.error = error.message
        throw error
      } finally {
        this.loading = false
      }
    },

    async removeItem(id) {
      this.loading = true
      this.error = null
      try {
        await deleteItem(id)
        this.items = this.items.filter(item => item.id !== id)
      } catch (error) {
        this.error = error.message
        throw error
      } finally {
        this.loading = false
      }
    }
  }
})
