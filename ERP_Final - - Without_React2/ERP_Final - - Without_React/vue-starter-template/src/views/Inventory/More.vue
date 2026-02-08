<template>
  <div class="pa-6">
    <h1 class="text-h4 mb-6">More Options</h1>
    
    <v-row>
      <v-col cols="12" md="4">
        <v-card @click="navigate('quantity-adjustment')" class="cursor-pointer">
          <v-card-title>Quantity Adjustment</v-card-title>
        </v-card>
      </v-col>
      
      <v-col cols="12" md="4">
        <v-card @click="navigate('cost-adjustment')" class="cursor-pointer">
          <v-card-title>Cost Adjustment</v-card-title>
        </v-card>
      </v-col>
      
      <v-col cols="12" md="4">
        <v-card @click="navigate('categories')" class="cursor-pointer">
          <v-card-title>Inventory Categories</v-card-title>
        </v-card>
      </v-col>
    </v-row>
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router'

const router = useRouter()

function navigate(option) {
  if (option === 'categories') {
    router.push({ name: 'Categories' })
  } else {
    alert(`${option} - To be implemented`)
  }
}
</script>

<style scoped>
.cursor-pointer {
  cursor: pointer;
}
</style>
