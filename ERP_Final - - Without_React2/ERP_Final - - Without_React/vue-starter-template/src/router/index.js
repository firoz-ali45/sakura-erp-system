import { createRouter, createWebHistory } from 'vue-router'
import HomePortal from '../views/HomePortal.vue'
import Items from '../views/Inventory/Items.vue'
import Categories from '../views/Inventory/Categories.vue'
import More from '../views/Inventory/More.vue'
import Warehouse from '../views/Warehouse.vue'
import UserManagement from '../views/UserManagement.vue'

const routes = [
  {
    path: '/',
    name: 'Home',
    component: HomePortal
  },
  {
    path: '/Inventory/Items',
    name: 'Items',
    component: Items
  },
  {
    path: '/Inventory/Items/:id',
    name: 'ItemDetail',
    component: () => import('../views/Inventory/ItemDetail.vue')
  },
  {
    path: '/Inventory/Categories',
    name: 'Categories',
    component: Categories
  },
  {
    path: '/Inventory/More',
    name: 'More',
    component: More
  },
  {
    path: '/Warehouse',
    name: 'Warehouse',
    component: Warehouse
  },
  {
    path: '/UserManagement',
    name: 'UserManagement',
    component: UserManagement
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
