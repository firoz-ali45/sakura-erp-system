<template>
  <v-app>
    <Sidebar />
    <v-main>
      <Header />
      <router-view />
    </v-main>
  </v-app>
</template>

<script setup>
import Sidebar from './components/Sidebar.vue'
import Header from './components/Header.vue'
</script>

<style>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Cairo', sans-serif;
  background-color: #f8f4f0;
}

/* KPI Card Styling - Matching Original */
.kpi-card {
  background: linear-gradient(145deg, #f0e1cd 0%, #e8d5c0 100%);
  border-radius: 0.75rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
  border: 1px solid rgba(149, 108, 42, 0.2);
  position: relative;
  overflow: hidden;
  transition: all 0.3s ease;
}

.kpi-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, #284b44, #956c2a, #ea8990);
  opacity: 0.8;
  transition: all 0.3s ease;
}

.kpi-card .value {
  font-size: 1.75rem;
  font-weight: 700;
  color: #284b44;
  margin-top: 0.25rem;
  min-height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
}

.kpi-card .title {
  color: #284b44;
  font-weight: 600;
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.kpi-card .icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
  transition: all 0.3s ease;
}

.kpi-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
  border-color: rgba(149, 108, 42, 0.4);
}

.kpi-card:hover .value {
  color: #956c2a;
  transform: scale(1.05);
}

.kpi-card:hover .icon {
  transform: scale(1.1);
}

.kpi-card:hover::before {
  height: 5px;
  opacity: 1;
}

/* Sidebar Navigation Scrolling */
.sidebar-nav {
  overflow-y: auto;
  overflow-x: hidden;
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.3) transparent;
}

.sidebar-nav::-webkit-scrollbar {
  width: 6px;
}

.sidebar-nav::-webkit-scrollbar-track {
  background: transparent;
}

.sidebar-nav::-webkit-scrollbar-thumb {
  background-color: rgba(255, 255, 255, 0.3);
  border-radius: 3px;
}

.sidebar-nav::-webkit-scrollbar-thumb:hover {
  background-color: rgba(255, 255, 255, 0.5);
}
</style>
