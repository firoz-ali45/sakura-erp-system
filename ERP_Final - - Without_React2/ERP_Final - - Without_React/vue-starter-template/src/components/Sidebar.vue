<template>
  <v-navigation-drawer
    permanent
    width="280"
    color="#284b44"
    class="sidebar"
  >
    <!-- Logo and Welcome Section -->
    <div class="d-flex flex-column align-center pa-6 border-b border-grey-darken-1">
      <img 
        src="https://images.deliveryhero.io/image/hungerstation/restaurant/logo/8556a1377e5154c66adf844d9c5ecb9f.jpg" 
        alt="Sakura Logo" 
        class="rounded-circle mb-3"
        style="width: 64px; height: 64px; object-fit: cover; border: 2px solid white;"
      />
      <div class="text-center">
        <p class="text-xs text-grey-lighten-1 mb-1">Welcome,</p>
        <p class="text-lg font-weight-bold" style="color: #ea8990;">{{ userName || 'Loading...' }}</p>
      </div>
    </div>

    <!-- Navigation -->
    <v-list nav density="compact" class="sidebar-nav flex-grow-1">
      <v-list-item
        :to="{ name: 'Home' }"
        class="nav-link"
        prepend-icon=""
      >
        <template v-slot:prepend>
          <i class="fas fa-tachometer-alt" style="width: 24px; text-align: center;"></i>
        </template>
        <v-list-item-title>Home Portal</v-list-item-title>
      </v-list-item>

      <v-list-group value="Inventory">
        <template v-slot:activator="{ props }">
          <v-list-item v-bind="props" class="nav-link">
            <template v-slot:prepend>
              <i class="fas fa-shopping-bag" style="width: 24px; text-align: center;"></i>
            </template>
            <v-list-item-title>Inventory</v-list-item-title>
          </v-list-item>
        </template>
        <v-list-item
          :to="{ name: 'Items' }"
          class="nav-sub-item"
          prepend-icon=""
        >
          <template v-slot:prepend>
            <i class="fas fa-box" style="width: 20px; text-align: center; margin-left: 24px;"></i>
          </template>
          <v-list-item-title>Items</v-list-item-title>
        </v-list-item>
        <v-list-item
          :to="{ name: 'Categories' }"
          class="nav-sub-item"
          prepend-icon=""
        >
          <template v-slot:prepend>
            <i class="fas fa-folder" style="width: 20px; text-align: center; margin-left: 24px;"></i>
          </template>
          <v-list-item-title>Categories</v-list-item-title>
        </v-list-item>
        <v-list-item
          :to="{ name: 'More' }"
          class="nav-sub-item"
          prepend-icon=""
        >
          <template v-slot:prepend>
            <i class="fas fa-ellipsis-h" style="width: 20px; text-align: center; margin-left: 24px;"></i>
          </template>
          <v-list-item-title>More</v-list-item-title>
        </v-list-item>
      </v-list-group>

      <v-list-item
        :to="{ name: 'Warehouse' }"
        class="nav-link"
        prepend-icon=""
      >
        <template v-slot:prepend>
          <i class="fas fa-warehouse" style="width: 24px; text-align: center;"></i>
        </template>
        <v-list-item-title>Warehouse</v-list-item-title>
      </v-list-item>

      <v-list-item
        :to="{ name: 'UserManagement' }"
        class="nav-link"
        prepend-icon=""
      >
        <template v-slot:prepend>
          <i class="fas fa-users-cog" style="width: 24px; text-align: center;"></i>
        </template>
        <v-list-item-title>User Management</v-list-item-title>
      </v-list-item>
    </v-list>

    <!-- Settings -->
    <div class="pa-4 border-t border-grey-darken-1">
      <v-list-item class="nav-link pa-2" prepend-icon="">
        <template v-slot:prepend>
          <i class="fas fa-cog" style="width: 24px; text-align: center;"></i>
        </template>
        <v-list-item-title class="text-grey-lighten-1">Settings</v-list-item-title>
      </v-list-item>
    </div>

    <!-- Footer -->
    <template v-slot:append>
      <div class="pa-4 text-center text-grey-lighten-1 text-caption border-t border-grey-darken-1">
        Sakura Portal © 2025
      </div>
    </template>
  </v-navigation-drawer>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '../lib/supabase'

const userName = ref('Loading...')

onMounted(async () => {
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (user) {
      // Try to get user name from users table
      const { data: userData } = await supabase
        .from('users')
        .select('name, email')
        .eq('email', user.email)
        .single()
      
      if (userData?.name) {
        userName.value = userData.name
      } else {
        userName.value = user.email?.split('@')[0] || 'User'
      }
    }
  } catch (error) {
    console.error('Error loading user:', error)
    userName.value = 'User'
  }
})
</script>

<style scoped>
.sidebar {
  overflow-y: auto;
}

.sidebar-nav {
  overflow-y: auto;
  overflow-x: hidden;
}

.nav-link {
  color: white !important;
}

.nav-link:hover {
  background-color: rgba(255, 255, 255, 0.1);
}

.nav-sub-item {
  padding-left: 48px !important;
}
</style>
