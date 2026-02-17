<template>
  <div class="app-layout" data-homeportal>
    <!-- Sidebar Overlay -->
    <div 
      id="sidebar-overlay" 
      :class="['sidebar-overlay', { 'open': sidebarOpen }]" 
      @click="toggleSidebar"
      @touchstart.prevent="toggleSidebar"
    ></div>

    <!-- Sidebar -->
    <aside 
      id="sidebar" 
      :class="['sidebar', 'w-64', 'text-white', 'flex-shrink-0', 'flex', 'flex-col', 'fixed', 'inset-y-0', 'z-50', 'transition-transform', 'duration-300', 'ease-in-out', 'md:relative', 'md:h-full', { 'open': sidebarOpen }]"
    >
      <div class="flex flex-col items-center justify-center p-6 border-b border-gray-700">
        <img 
          id="sidebar-user-image" 
          :src="user?.profilePhotoUrl || 'https://images.deliveryhero.io/image/hungerstation/restaurant/logo/8556a1377e5154c66adf844d9c5ecb9f.jpg'" 
          alt="User Photo" 
          class="h-16 w-16 rounded-full ring-2 ring-white mb-3 object-cover"
        >
        <div id="sidebar-welcome-message" class="text-center">
          <p class="text-xs text-gray-300 mb-1">{{ $t('homePortal.welcome') }},</p>
          <p id="sidebar-user-name" class="text-lg font-bold" style="color: #ea8990;">{{ user?.name || '...' }}</p>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto">
        <nav class="p-4">
        <router-link 
          to="/homeportal/dashboard" 
          class="nav-link flex items-center p-4 my-2 rounded-lg"
          active-class="active"
        >
          <i class="fas fa-tachometer-alt w-6 text-center"></i>
          <span>{{ $t('homePortal.title') }}</span>
        </router-link>

        <!-- Finance Expandable Section (SAP: Purchasing/MIRO, Payments, AP) -->
        <div class="nav-group">
          <a 
            href="#" 
            @click.prevent="toggleNavGroup('finance-group')" 
            class="nav-link nav-group-header flex items-center p-4 my-2 rounded-lg justify-between"
          >
            <div class="flex items-center">
              <i class="fas fa-university w-6 text-center"></i>
              <span>{{ $t('homePortal.finance') }}</span>
            </div>
            <i 
              :class="['fas', 'nav-group-icon', 'transition-transform', 'duration-200', financeGroupOpen ? 'fa-chevron-down' : 'fa-chevron-up']"
              id="finance-group-icon"
            ></i>
          </a>
          <div 
            id="finance-group" 
            :class="['nav-group-content', 'pl-8', { 'hidden': !financeGroupOpen }]"
          >
            <router-link 
              to="/homeportal/purchasing" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-file-invoice-dollar w-5 text-center"></i>
              <span>{{ $t('homePortal.financePurchasing') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/payments" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-money-check-alt w-5 text-center"></i>
              <span>{{ $t('homePortal.payments') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/accounts-payable" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-hand-holding-usd w-5 text-center"></i>
              <span>{{ $t('homePortal.accountsPayable') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/finance-more" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-ellipsis-h w-5 text-center"></i>
              <span>{{ $t('homePortal.financeMore') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/finance-reports" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-chart-pie w-5 text-center"></i>
              <span>{{ $t('homePortal.financeReports') }}</span>
            </router-link>
          </div>
        </div>

        <!-- Reports Expandable Section -->
        <div class="nav-group">
          <a 
            href="#" 
            @click.prevent="toggleNavGroup('reports-group')" 
            class="nav-link nav-group-header flex items-center p-4 my-2 rounded-lg justify-between"
          >
            <div class="flex items-center">
              <i class="fas fa-chart-bar w-6 text-center"></i>
              <span>{{ $t('homePortal.reports') }}</span>
            </div>
            <i 
              :class="['fas', 'nav-group-icon', 'transition-transform', 'duration-200', reportsGroupOpen ? 'fa-chevron-down' : 'fa-chevron-up']"
              id="reports-group-icon"
            ></i>
          </a>
          <div 
            id="reports-group" 
            :class="['nav-group-content', 'pl-8', { 'hidden': !reportsGroupOpen }]"
          >
            <router-link 
              to="/homeportal/reports/inventory-reports" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-boxes w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryReports') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/reports/business-reports" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-chart-bar w-5 text-center"></i>
              <span>{{ $t('homePortal.businessReports') }}</span>
            </router-link>
          </div>
        </div>

        <!-- Inventory Expandable Section -->
        <div class="nav-group">
          <a 
            href="#" 
            @click.prevent="toggleNavGroup('inventory-group')" 
            class="nav-link nav-group-header flex items-center p-4 my-2 rounded-lg justify-between"
          >
            <div class="flex items-center">
              <i class="fas fa-shopping-bag w-6 text-center"></i>
              <span>{{ $t('homePortal.inventory') }}</span>
            </div>
            <i 
              :class="['fas', 'nav-group-icon', 'transition-transform', 'duration-200', inventoryGroupOpen ? 'fa-chevron-down' : 'fa-chevron-up']"
              id="inventory-group-icon"
            ></i>
          </a>
          <div 
            id="inventory-group" 
            :class="['nav-group-content', 'pl-8', { 'hidden': !inventoryGroupOpen }]"
          >
            <router-link 
              to="/homeportal/items" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-box w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryItems') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/suppliers" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-truck w-5 text-center"></i>
              <span>{{ $t('homePortal.inventorySuppliers') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/pr" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-file-alt w-5 text-center"></i>
              <span>{{ $t('homePortal.purchaseRequests') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/purchase-orders" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-file-invoice w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryPurchaseOrders') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/transfer-orders" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-exchange-alt w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryTransferOrders') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/grns" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-clipboard-list w-5 text-center"></i>
              <span>{{ $t('inventory.grn.title') }}</span>
            </router-link>
            <a href="#" @click.prevent="loadDashboard('inventory/inventory-count.html')" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg">
              <i class="fas fa-clipboard-check w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryCount') }}</span>
            </a>
            <router-link 
              to="/homeportal/transfers" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-arrows-alt w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryTransfers') }}</span>
            </router-link>
            <a href="#" @click.prevent="loadDashboard('inventory/production.html')" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg">
              <i class="fas fa-industry w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryProduction') }}</span>
            </a>
            <router-link 
              to="/homeportal/more" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-ellipsis-h w-5 text-center"></i>
              <span>{{ $t('homePortal.inventoryMore') }}</span>
            </router-link>
          </div>
        </div>

        <!-- User Management Expandable Section (SAP-style RBAC) -->
        <div class="nav-group">
          <a 
            href="#" 
            @click.prevent="toggleNavGroup('userManagement-group')" 
            class="nav-link nav-group-header flex items-center p-4 my-2 rounded-lg justify-between"
          >
            <div class="flex items-center">
              <i class="fas fa-users-cog w-6 text-center"></i>
              <span>{{ $t('homePortal.userManagement') }}</span>
              <span v-if="pendingUsersCount > 0" class="ml-2 bg-red-500 text-white text-xs font-bold rounded-full h-5 w-5 flex items-center justify-center">
                {{ pendingUsersCount }}
              </span>
            </div>
            <i 
              :class="['fas', 'nav-group-icon', 'transition-transform', 'duration-200', userManagementGroupOpen ? 'fa-chevron-down' : 'fa-chevron-up']"
            ></i>
          </a>
          <div 
            id="userManagement-group" 
            :class="['nav-group-content', 'pl-8', { 'hidden': !userManagementGroupOpen }]"
          >
            <router-link to="/homeportal/user-management/users" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-user w-5 text-center"></i>
              <span>{{ $t('userManagement.users') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/roles" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-user-shield w-5 text-center"></i>
              <span>{{ $t('userManagement.roles') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/permissions" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-key w-5 text-center"></i>
              <span>{{ $t('userManagement.permissions') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/access-matrix" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-th-list w-5 text-center"></i>
              <span>{{ $t('userManagement.accessMatrix') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/activity-logs" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-history w-5 text-center"></i>
              <span>{{ $t('userManagement.activityLogs') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/login-sessions" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-sign-in-alt w-5 text-center"></i>
              <span>{{ $t('userManagement.loginSessions') }}</span>
            </router-link>
            <router-link to="/homeportal/user-management/security-settings" class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg" active-class="active">
              <i class="fas fa-shield-alt w-5 text-center"></i>
              <span>{{ $t('userManagement.securitySettings') }}</span>
            </router-link>
          </div>
        </div>

        <!-- Manage Expandable Section -->
        <div class="nav-group">
          <a 
            href="#" 
            @click.prevent="toggleNavGroup('manage-group')" 
            class="nav-link nav-group-header flex items-center p-4 my-2 rounded-lg justify-between"
          >
            <div class="flex items-center">
              <i class="fas fa-cog w-6 text-center"></i>
              <span>{{ $t('homePortal.manage') }}</span>
            </div>
            <i 
              :class="['fas', 'nav-group-icon', 'transition-transform', 'duration-200', manageGroupOpen ? 'fa-chevron-down' : 'fa-chevron-up']"
              id="manage-group-icon"
            ></i>
          </a>
          <div 
            id="manage-group" 
            :class="['nav-group-content', 'pl-8', { 'hidden': !manageGroupOpen }]"
          >
            <router-link 
              to="/homeportal/tags" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-tags w-5 text-center"></i>
              <span>{{ $t('homePortal.manageMore') }}</span>
            </router-link>
            <router-link 
              to="/homeportal/settings/inventory-locations" 
              class="nav-link nav-sub-item flex items-center p-3 my-1 rounded-lg"
              active-class="active"
            >
              <i class="fas fa-map-marker-alt w-5 text-center"></i>
              <span>{{ $t('inventory.locations.title') }}</span>
            </router-link>
          </div>
        </div>
        </nav>
      </div>

      <div class="mt-auto flex-shrink-0 border-t border-gray-700">
        <div class="p-4">
          <a 
            href="#" 
            @click.prevent="openSettings" 
            class="flex items-center p-2 my-1 text-gray-300 rounded-lg hover:bg-white/10"
          >
            <i class="fas fa-cog w-6 text-center"></i>
            <span>{{ $t('homePortal.settings') }}</span>
          </a>
        </div>
      </div>

      <div class="p-4 text-center text-sm text-gray-400 border-t border-gray-700">
        <p>{{ $t('homePortal.portalFooter') }} {{ new Date().getFullYear().toString() }}</p>
      </div>
    </aside>

    <!-- Main Content -->
    <main class="main-content">
      <!-- Header -->
      <header class="gradient-header shadow-md p-4 flex items-center justify-between z-20 sticky top-0">
        <div class="flex-1 flex justify-start">
          <button 
            id="menu-toggle" 
            @click="toggleSidebar"
            class="md:hidden text-white text-2xl"
          >
            <i class="fas fa-bars"></i>
          </button>
        </div>

        <div class="flex items-center justify-center gap-3">
          <img 
            src="/Sakura_Pink_Logo.png" 
            alt="Sakura Logo" 
            class="h-10 w-10 rounded-full"
            onerror="this.src='/sakura-logo.png'"
          >
          <h1 id="header-title" class="text-xl md:text-2xl font-bold text-white whitespace-nowrap">
            <span>{{ $t('homePortal.hubTitle') }}</span>
          </h1>
          <div v-if="dataConsistent" id="data-consistency-indicator" class="ml-2 flex items-center gap-1 text-xs text-white/80">
            <i class="fas fa-shield-alt text-green-400"></i>
            <span>{{ $t('homePortal.consistent') }}</span>
          </div>
        </div>

        <div class="flex-1 flex justify-end">
          <div class="hidden md:block">
            <div class="font-semibold text-white/90 text-xs md:text-base" id="current-date-time">
              {{ currentDateTime }}
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content Area -->
      <div class="router-view-wrapper">
        <!-- Router View - Single Source of Truth -->
        <!-- Key forces proper re-render on navigation -->
        <router-view :key="$route.fullPath" />
      </div>
    </main>

    <!-- Sakura AI Assistant Chatbot -->
    <SakuraAIAssistant />

    <!-- Settings Modal (Complete - Original Structure) -->
    <div 
      v-if="showSettingsModal"
      id="settings-modal"
      class="fixed inset-0 bg-black bg-opacity-60 z-50 flex items-center justify-center p-4"
      @click.self="closeSettings"
    >
      <div 
        id="settings-modal-content"
        class="bg-white rounded-xl shadow-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto"
        style="scrollbar-width: thin; scrollbar-color: #cbd5e0 #f7fafc;"
      >
        <div class="flex justify-between items-center pb-4 border-b sticky top-0 bg-white z-10 mb-4">
          <h3 class="text-xl font-bold flex items-center gap-2" style="color: #ea8990;">
            <i class="fas fa-cog" style="color: #ea8990;"></i>
            <span>{{ $t('homePortal.settings') }}</span>
          </h3>
          <button 
            @click="closeSettings"
            class="rounded-full w-10 h-10 flex items-center justify-center text-2xl font-bold transition-all cursor-pointer border-2 bg-white shadow-md hover:shadow-lg"
            style="line-height: 1; min-width: 40px; min-height: 40px; font-size: 24px; z-index: 1000; font-weight: 900; color: #ea8990; border-color: #ea8990;"
            @mouseover="$event.target.style.background='#ea8990'; $event.target.style.color='white';"
            @mouseout="$event.target.style.background='white'; $event.target.style.color='#ea8990';"
          >
            &times;
          </button>
        </div>

        <!-- Accordion Style Settings Rows -->
        <div class="space-y-3">
          <!-- My Profile Row (Accordion) -->
          <div class="settings-accordion-item border border-gray-200 rounded-lg overflow-hidden shadow-sm">
            <button 
              @click="toggleSettingsAccordion('profile-accordion')"
              class="settings-accordion-header w-full flex items-center justify-between p-4 bg-gradient-to-r from-pink-50 to-white hover:from-pink-100 hover:to-pink-50 transition-all text-left"
              style="background: linear-gradient(to right, rgba(234, 137, 144, 0.1) 0%, rgba(255, 255, 255, 1) 100%);"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-gradient-to-br from-pink-400 to-pink-600 flex items-center justify-center text-white shadow-md" style="background: linear-gradient(135deg, #ea8990 0%, #d9739f 100%);">
                  <i class="fas fa-user-circle"></i>
                </div>
                <div>
                  <h4 class="text-sm font-semibold text-gray-800">{{ $t('homePortal.myProfile') }}</h4>
                  <p class="text-xs text-gray-500">{{ $t('homePortal.manageProfile') }}</p>
                </div>
              </div>
              <i 
                :id="'profile-accordion-icon'"
                :class="['fas', 'fa-chevron-down', 'text-gray-400', 'transition-transform', 'duration-300', { 'fa-chevron-up': profileAccordionOpen }]"
              ></i>
            </button>
            <div 
              :id="'profile-accordion-content'"
              :class="['settings-accordion-content', 'border-t', 'border-gray-200', 'bg-white', { 'hidden': !profileAccordionOpen }]"
            >
              <div class="p-4 space-y-4">
                <!-- Photo Upload Section -->
                <div>
                  <label class="text-sm font-medium text-gray-700 block mb-3">{{ $t('homePortal.profilePhoto') }}</label>
                  <div class="flex flex-col items-center gap-4">
                    <div class="relative">
                      <img 
                        :id="'profile-photo-preview'"
                        :src="profilePhotoPreview || user?.profilePhotoUrl || 'https://images.deliveryhero.io/image/hungerstation/restaurant/logo/8556a1377e5154c66adf844d9c5ecb9f.jpg'" 
                        alt="Profile Photo" 
                        class="w-24 h-24 rounded-full object-cover border-4 border-gray-200 shadow-lg cursor-pointer hover:border-gray-400 transition-all"
                        @click="triggerPhotoUpload"
                      >
                      <div 
                        class="absolute bottom-0 right-0 bg-gray-700 text-white rounded-full p-2 cursor-pointer hover:bg-gray-800 transition-all"
                        @click="triggerPhotoUpload"
                      >
                        <i class="fas fa-camera text-sm"></i>
                      </div>
                    </div>
                    <input 
                      type="file" 
                      ref="photoUploadInput"
                      id="photo-upload-input" 
                      accept="image/*" 
                      class="hidden" 
                      @change="handlePhotoUpload"
                    >
                    <button 
                      type="button" 
                      @click="triggerPhotoUpload"
                      class="px-4 py-2 bg-gradient-to-r from-gray-600 to-gray-700 text-white rounded-lg hover:from-gray-700 hover:to-gray-800 transition-all text-sm font-medium shadow-md"
                    >
                      <i class="fas fa-upload mr-2"></i><span>{{ $t('homePortal.uploadPhoto') }}</span>
                    </button>
                    <button 
                      v-if="profilePhotoPreview || user?.profilePhotoUrl"
                      type="button" 
                      @click="removeProfilePhoto"
                      class="px-4 py-2 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-all text-sm font-medium shadow-md"
                    >
                      <i class="fas fa-trash mr-2"></i><span>{{ $t('homePortal.removePhoto') }}</span>
                    </button>
                    <p class="text-xs text-gray-500 text-center">{{ $t('homePortal.photoUploadInfo') }}</p>
                  </div>
                </div>

                <!-- Profile Edit Form -->
                <div class="space-y-3">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('homePortal.fullName') }}</label>
                    <input 
                      v-model="profileForm.name"
                      type="text" 
                      id="profile-name" 
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-400 text-sm"
                    >
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('homePortal.emailAddress') }}</label>
                    <input 
                      v-model="profileForm.email"
                      type="email" 
                      id="profile-email" 
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-400 text-sm"
                    >
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('homePortal.phoneNumber') }}</label>
                    <input 
                      v-model="profileForm.phone"
                      type="tel" 
                      id="profile-phone" 
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-400 text-sm"
                    >
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">{{ $t('homePortal.changePassword') }}</label>
                    <input 
                      v-model="profileForm.password"
                      type="password" 
                      id="profile-password" 
                      :placeholder="$t('homePortal.enterNewPassword')" 
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-400 text-sm"
                    >
                    <p class="text-xs text-gray-500 mt-1">{{ $t('homePortal.passwordLeaveBlank') }}</p>
                  </div>
                  <div class="flex gap-2 pt-2">
                    <button 
                      type="button" 
                      @click="updateMyProfile"
                      class="flex-1 px-4 py-2 bg-gradient-to-r from-green-600 to-green-700 text-white rounded-lg hover:from-green-700 hover:to-green-800 transition-all text-sm font-medium shadow-md"
                    >
                      <i class="fas fa-save mr-2"></i><span>{{ $t('homePortal.updateProfile') }}</span>
                    </button>
                    <button 
                      type="button" 
                      @click="handleLogout"
                      class="flex-1 px-4 py-2 bg-gradient-to-r from-red-600 to-red-700 text-white rounded-lg hover:from-red-700 hover:to-red-800 transition-all text-sm font-medium shadow-md"
                    >
                      <i class="fas fa-sign-out-alt mr-2"></i><span>{{ $t('homePortal.logout') }}</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Language Switching Row (Accordion) -->
          <div class="settings-accordion-item border border-gray-200 rounded-lg overflow-hidden shadow-sm">
            <button 
              @click="toggleSettingsAccordion('language-accordion')"
              class="settings-accordion-header w-full flex items-center justify-between p-4 bg-gradient-to-r from-pink-50 to-white hover:from-pink-100 hover:to-pink-50 transition-all text-left"
              style="background: linear-gradient(to right, rgba(234, 137, 144, 0.1) 0%, rgba(255, 255, 255, 1) 100%);"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-gradient-to-br from-pink-400 to-pink-600 flex items-center justify-center text-white shadow-md" style="background: linear-gradient(135deg, #ea8990 0%, #d9739f 100%);">
                  <i class="fas fa-language"></i>
                </div>
                <div>
                  <h4 class="text-sm font-semibold text-gray-800">{{ $t('homePortal.language') }}</h4>
                  <p class="text-xs text-gray-500">{{ $t('homePortal.languageDesc') }}</p>
                </div>
              </div>
              <i 
                :id="'language-accordion-icon'"
                :class="['fas', 'fa-chevron-down', 'text-gray-400', 'transition-transform', 'duration-300', { 'fa-chevron-up': languageAccordionOpen }]"
              ></i>
            </button>
            <div 
              :id="'language-accordion-content'"
              :class="['settings-accordion-content', 'border-t', 'border-gray-200', 'bg-white', { 'hidden': !languageAccordionOpen }]"
            >
              <div class="p-4 space-y-3">
                <div class="grid grid-cols-2 gap-3">
                  <button 
                    @click="changeLanguage('en')"
                    :class="['lang-btn-modal', 'flex', 'items-center', 'justify-center', 'gap-2', 'px-4', 'py-3', 'rounded-lg', 'border-2', 'font-medium', 'shadow-sm', 'hover:shadow-md', 'transition-all', locale === 'en' ? 'bg-[#284b44] text-white border-[#284b44]' : 'bg-white text-gray-700 border-gray-300 hover:border-[#284b44]']"
                    data-lang="en"
                  >
                    <i class="fas fa-flag text-[#284b44]"></i>
                    <span>English</span>
                    <i v-if="locale === 'en'" class="fas fa-check-circle ml-auto text-[#284b44]"></i>
                  </button>
                  <button 
                    @click="changeLanguage('ar')"
                    :class="['lang-btn-modal', 'flex', 'items-center', 'justify-center', 'gap-2', 'px-4', 'py-3', 'rounded-lg', 'border-2', 'font-medium', 'shadow-sm', 'hover:shadow-md', 'transition-all', locale === 'ar' ? 'bg-[#284b44] text-white border-[#284b44]' : 'bg-white text-gray-700 border-gray-300 hover:border-[#284b44]']"
                    data-lang="ar"
                  >
                    <i class="fas fa-flag text-[#284b44]"></i>
                    <span>العربية</span>
                    <i v-if="locale === 'ar'" class="fas fa-check-circle ml-auto text-[#284b44]"></i>
                  </button>
                </div>
                <div class="mt-3 p-3 bg-[#284b44]/10 border border-[#284b44]/20 rounded-lg">
                  <div class="flex items-start gap-2">
                    <i class="fas fa-info-circle text-[#284b44] mt-0.5"></i>
                    <p class="text-xs text-[#284b44]">{{ $t('homePortal.languageInfo') }}</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { useI18n } from '@/composables/useI18n';
import { formatDateTime } from '@/utils/dateFormat';
import { formatNumber } from '@/utils/numberFormat';
import { updateUserInSupabase, initSupabase, USE_SUPABASE, supabaseClient, getUsers } from '@/services/supabase';
import SakuraAIAssistant from '@/components/SakuraAIAssistant.vue';
// Advanced ERP Features - lazy loaded for performance
// import { 
//   AuditLogger, 
//   ActivityTracker, 
//   SessionManager, 
//   NotificationSystem, 
//   AnalyticsManager, 
//   APIKeyManager, 
//   SystemSettings 
// } from '@/services/advancedERPFeatures';

const router = useRouter();
const route = useRoute();
const authStore = useAuthStore();

// Route tracking for debugging + Auto-collapse sidebar on route change
watch(() => route.fullPath, (newPath, oldPath) => {
  console.log('🔵 [HomePortal] Route changed:', {
    from: oldPath,
    to: newPath,
    matched: route.matched.map(r => ({ path: r.path, name: r.name })),
    params: route.params,
    query: route.query
  });
  
  // Auto-expand User Management section when on user-management routes
  if (newPath && newPath.includes('user-management')) {
    userManagementGroupOpen.value = true;
  }
  // Auto-collapse sidebar on mobile when route changes (mobile-first)
  if (window.innerWidth < 768 && sidebarOpen.value) {
    sidebarOpen.value = false;
    const overlay = document.getElementById('sidebar-overlay');
    if (overlay) {
      overlay.classList.remove('open');
    }
    document.body.classList.remove('sidebar-open');
  }
}, { immediate: true });

// i18n support - using new enterprise system
const { t, locale, isRTL, textAlign, setLocale } = useI18n();

// State
const sidebarOpen = ref(false);
const dashboardFrameSrc = ref('');
const iframeLoading = ref(true);
const inventoryGroupOpen = ref(true);
const financeGroupOpen = ref(true);
const userManagementGroupOpen = ref(false);
const manageGroupOpen = ref(false);
const reportsGroupOpen = ref(false);
const pendingUsersCount = ref(0);
const dataConsistent = ref(true);
const currentDateTime = ref('');

// Computed
const user = computed(() => authStore.user);

// Methods
const toggleSidebar = () => {
  sidebarOpen.value = !sidebarOpen.value;
  const overlay = document.getElementById('sidebar-overlay');
  if (overlay) {
    if (sidebarOpen.value) {
      overlay.classList.add('open');
      if (window.innerWidth < 768) {
        document.body.classList.add('sidebar-open');
      }
    } else {
      overlay.classList.remove('open');
      document.body.classList.remove('sidebar-open');
    }
  }
};

const toggleNavGroup = (groupName) => {
  if (groupName === 'inventory-group') {
    inventoryGroupOpen.value = !inventoryGroupOpen.value;
  } else if (groupName === 'userManagement-group') {
    userManagementGroupOpen.value = !userManagementGroupOpen.value;
  } else if (groupName === 'finance-group') {
    financeGroupOpen.value = !financeGroupOpen.value;
  } else if (groupName === 'manage-group') {
    manageGroupOpen.value = !manageGroupOpen.value;
  } else if (groupName === 'reports-group') {
    reportsGroupOpen.value = !reportsGroupOpen.value;
  }
};

const loadDashboard = (dashboardUrl) => {
  console.log('Loading dashboard:', dashboardUrl);
  
  // Only handle external HTML files (iframe cases)
  // Vue routes are handled by router-link in the sidebar
  if (dashboardUrl.endsWith('.html') || (dashboardUrl.includes('/') && !dashboardUrl.startsWith('/'))) {
        iframeLoading.value = true;
        
        // External HTML files are in project root (outside frontend folder)
        // We need to use relative path from frontend to project root
        // Path structure: ../../sakura-accounts-payable-dashboard/payable.html
        const pathParts = dashboardUrl.split('/');
        const fileName = pathParts[pathParts.length - 1];
        const folderName = pathParts.length > 1 ? pathParts[pathParts.length - 2] : '';
        
        // Files are now in public folder, so use absolute path from root
        // e.g., /sakura-accounts-payable-dashboard/payable.html
        let iframePath = '';
        if (folderName) {
          // e.g., sakura-accounts-payable-dashboard/payable.html
          iframePath = `/${folderName}/${fileName}`;
        } else {
          // e.g., inventory/items.html
          iframePath = `/${dashboardUrl}`;
        }
        
        dashboardFrameSrc.value = iframePath;
        iframeLoading.value = true;
        console.log('Loading iframe from:', iframePath);
        
        // Send language immediately when iframe src is set (for faster language sync)
        nextTick(() => {
          setTimeout(() => {
            const iframe = document.getElementById('dashboard-frame');
            if (iframe && iframe.contentWindow) {
              const lang = locale.value || 'en';
              console.log('📤 Sending initial language to iframe:', lang);
              iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang }, '*');
              iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: lang }, '*');
            }
          }, 100);
        });
        
        // Optimize loading: Preload iframe for faster display
        const iframe = document.getElementById('dashboard-frame');
        if (iframe) {
          // Set loading="lazy" only for non-critical dashboards
          if (!iframePath.includes('payable.html')) {
            iframe.setAttribute('loading', 'lazy');
          } else {
            // For Accounts Payable, use eager loading but optimize
            iframe.setAttribute('loading', 'eager');
            // Preconnect to speed up loading
            const link = document.createElement('link');
            link.rel = 'preconnect';
            link.href = iframePath;
            document.head.appendChild(link);
          }
        }
        
        // Fallback timeout to hide loading indicator after 5 seconds (reduced from 10)
        setTimeout(() => {
          if (iframeLoading.value) {
            console.warn('Iframe loading timeout - hiding loading indicator');
            iframeLoading.value = false;
          }
        }, 5000);
      } else {
    // Vue routes should use router-link, not loadDashboard
    console.warn('loadDashboard called for Vue route:', dashboardUrl, '- Use router-link instead');
    }
  
  // Close sidebar on mobile
  if (window.innerWidth < 768) {
    sidebarOpen.value = false;
  }
};

const showSettingsModal = ref(false);
const profileAccordionOpen = ref(false);
const languageAccordionOpen = ref(false);
const profilePhotoPreview = ref(null);
const photoUploadInput = ref(null);

const profileForm = ref({
  name: '',
  email: '',
  phone: '',
  password: ''
});

const toggleSettingsAccordion = (accordionId) => {
  if (accordionId === 'profile-accordion') {
    profileAccordionOpen.value = !profileAccordionOpen.value;
  } else if (accordionId === 'language-accordion') {
    languageAccordionOpen.value = !languageAccordionOpen.value;
  }
};

const openSettings = async () => {
  console.log('Opening settings modal');
  showSettingsModal.value = true;
  
  // Load user profile data
  if (user.value) {
    profileForm.value = {
      name: user.value.name || '',
      email: user.value.email || '',
      phone: user.value.phone || '',
      password: ''
    };
    
    // Load profile photo
    if (user.value.profilePhotoUrl) {
      profilePhotoPreview.value = user.value.profilePhotoUrl;
    } else {
      // Try localStorage
      const savedPhoto = localStorage.getItem('sakura_profile_photo');
      if (savedPhoto) {
        profilePhotoPreview.value = savedPhoto;
      }
    }
  }
};

const closeSettings = () => {
  showSettingsModal.value = false;
  profileAccordionOpen.value = false;
  languageAccordionOpen.value = false;
};

const triggerPhotoUpload = () => {
  if (photoUploadInput.value) {
    photoUploadInput.value.click();
  }
};

const handlePhotoUpload = async (event) => {
  const file = event.target.files[0];
  if (!file) return;

  // Validate file type
  if (!file.type.startsWith('image/')) {
    showNotification('Please select an image file.', 'warning');
    return;
  }

  // Validate file size (5MB max)
  if (file.size > 5 * 1024 * 1024) {
    showNotification('Image size should be less than 5MB.', 'warning');
    return;
  }

  // Read file and convert to base64
  const reader = new FileReader();
  reader.onload = async (e) => {
    const base64Image = e.target.result;
    
    // Optimistic UI update (instant)
    profilePhotoPreview.value = base64Image;
    const sidebarImage = document.getElementById('sidebar-user-image');
    if (sidebarImage) {
      sidebarImage.src = base64Image;
    }
    
    // Update user object immediately
    if (user.value) {
      user.value.profilePhotoUrl = base64Image;
      authStore.setUser({ ...user.value });
    }
    
    // Save to localStorage (backup)
    try {
      localStorage.setItem('sakura_profile_photo', base64Image);
    } catch (error) {
      console.error('Error saving photo to localStorage:', error);
    }
    
    // Save to Supabase in background (non-blocking)
    if (user.value?.id) {
      try {
        await initSupabase();
        if (USE_SUPABASE && supabaseClient) {
          await updateUserInSupabase(user.value.id, {
            profile_photo_url: base64Image
          });
          console.log('✅ Profile photo saved to Supabase');
        }
      } catch (error) {
        console.error('Error saving photo to Supabase:', error);
        // Don't show error to user - optimistic update already applied
      }
    }
  };
  
  reader.readAsDataURL(file);
};

const removeProfilePhoto = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Remove Photo',
    message: 'Are you sure you want to remove your profile photo?',
    confirmText: 'Remove',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-trash'
  });
  if (confirmed) {
    profilePhotoPreview.value = null;
    localStorage.removeItem('sakura_profile_photo');
    
    // Reset to default
    const sidebarImage = document.getElementById('sidebar-user-image');
    if (sidebarImage) {
      sidebarImage.src = 'https://images.deliveryhero.io/image/hungerstation/restaurant/logo/8556a1377e5154c66adf844d9c5ecb9f.jpg';
    }
  }
};

const updateMyProfile = async () => {
  try {
    // Validate
    if (!profileForm.value.name || !profileForm.value.email) {
      showNotification('Name and Email are required', 'error');
      return;
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(profileForm.value.email)) {
      showNotification('Please enter a valid email address', 'error');
      return;
    }

    if (profileForm.value.password && profileForm.value.password.length < 6) {
      showNotification('Password must be at least 6 characters', 'error');
      return;
    }

    if (!user.value?.id) {
      showNotification('User not found', 'error');
      return;
    }

    // Optimistic UI update (instant)
    const updatedUser = {
      ...user.value,
      name: profileForm.value.name,
      email: profileForm.value.email,
      phone: profileForm.value.phone || '',
      profilePhotoUrl: profilePhotoPreview.value || user.value.profilePhotoUrl
    };
    
    // Update UI immediately
    authStore.setUser(updatedUser);
    user.value = updatedUser;
    
    // Update sidebar immediately
    const sidebarName = document.getElementById('sidebar-user-name');
    if (sidebarName) {
      sidebarName.textContent = updatedUser.name;
    }
    
    const sidebarImage = document.getElementById('sidebar-user-image');
    if (sidebarImage && updatedUser.profilePhotoUrl) {
      sidebarImage.src = updatedUser.profilePhotoUrl;
    }
    
    // Save to Supabase in background (non-blocking)
    try {
      await initSupabase();
      if (USE_SUPABASE && supabaseClient) {
        const updateData = {
          name: profileForm.value.name.trim(),
          email: profileForm.value.email.trim().toLowerCase(),
          phone: profileForm.value.phone || '',
          profile_photo_url: profilePhotoPreview.value || user.value.profilePhotoUrl || null
        };
        
        if (profileForm.value.password) {
          updateData.password_hash = profileForm.value.password.trim();
        }
        
        await updateUserInSupabase(user.value.id, updateData);
        console.log('✅ Profile updated in Supabase');
      }
    } catch (error) {
      console.error('Error updating profile in Supabase:', error);
      // Rollback on error
      authStore.setUser(user.value);
      showNotification('Error saving to database. Changes reverted.', 'error');
      return;
    }
    
    // Update localStorage
    localStorage.setItem('sakura_current_user', JSON.stringify(updatedUser));
    
    showNotification('Profile updated successfully!', 'success');
    closeSettings();
  } catch (error) {
    console.error('Error updating profile:', error);
    showNotification('Error updating profile. Please try again.', 'error');
  }
};

const updateDateTime = () => {
  const now = new Date();
  currentDateTime.value = formatDateTime(now, locale.value);
};

const changeLanguage = (lang) => {
  // Use the global language store (single source of truth)
  // This automatically updates:
  // - Vue i18n locale
  // - Document direction (RTL/LTR)
  // - localStorage
  // - Broadcasts to iframes
  // - All components using useI18n()
  setLocale(lang);
  
  // Close modal after short delay
  setTimeout(() => {
    closeSettings();
  }, 300);
};

const handleIframeLoad = () => {
  console.log('✅ Iframe loaded successfully');
  iframeLoading.value = false;
  
  // Send language to iframe - wait a bit for iframe to be ready
  setTimeout(() => {
    const iframe = document.getElementById('dashboard-frame');
    if (iframe && iframe.contentWindow) {
      // Use the active locale from the centralized i18n system
      const lang = locale.value || localStorage.getItem('portalLang') || 'en';
      console.log('📤 Sending language to iframe:', lang);
      iframe.contentWindow.postMessage({ type: 'SET_LANGUAGE', lang }, '*');
      // Also try alternative message format
      iframe.contentWindow.postMessage({ type: 'LANGUAGE_CHANGE', language: lang }, '*');
    }
  }, 500);
};

const handleIframeError = () => {
  console.error('❌ Error loading iframe');
  iframeLoading.value = false;
  showNotification('Could not load dashboard. The file may not exist or the path is incorrect. Please ensure the external HTML files are in the project root folder.', 'error', 5000);
};

const handleLogout = async () => {
  const { showConfirmDialog } = await import('@/utils/confirmDialog');
  const confirmed = await showConfirmDialog({
    title: 'Logout',
    message: 'Are you sure you want to logout?',
    confirmText: 'Logout',
    cancelText: 'Cancel',
    type: 'warning',
    icon: 'fas fa-sign-out-alt'
  });
  if (confirmed) {
    authStore.logout();
    router.push('/login');
  }
};

// Advanced ERP Features (initialized after Supabase is ready)
let auditLogger = null;
let activityTracker = null;
let sessionManager = null;
let notificationSystem = null;
let analyticsManager = null;
let apiKeyManager = null;
let systemSettings = null;

// Router is now the single source of truth - no sync needed

// Load profile photo from Supabase on mount
const loadProfilePhoto = async () => {
  if (!user.value?.id) return;
  
  try {
    await initSupabase();
    if (USE_SUPABASE && supabaseClient) {
      // Try to load from Supabase first
      const { data, error } = await supabaseClient
        .from('users')
        .select('profile_photo_url')
        .eq('id', user.value.id)
        .single();
      
      if (!error && data?.profile_photo_url) {
        // Update user object with profile photo
        user.value.profilePhotoUrl = data.profile_photo_url;
        authStore.setUser({ ...user.value });
  
        // Update sidebar image immediately
        const sidebarImage = document.getElementById('sidebar-user-image');
        if (sidebarImage) {
          sidebarImage.src = data.profile_photo_url;
        }
        
        // Cache in localStorage
        localStorage.setItem('sakura_profile_photo', data.profile_photo_url);
        return;
      }
        }
        
    // Fallback: try localStorage cache
    const cachedPhoto = localStorage.getItem('sakura_profile_photo');
    if (cachedPhoto) {
      user.value.profilePhotoUrl = cachedPhoto;
      authStore.setUser({ ...user.value });
      const sidebarImage = document.getElementById('sidebar-user-image');
      if (sidebarImage) {
        sidebarImage.src = cachedPhoto;
      }
    }
  } catch (error) {
    console.error('Error loading profile photo:', error);
    // Silent fail - use default logo
  }
};

// Lifecycle
onMounted(() => {
  // Initialize sidebar overlay state (synchronous, fast)
  try {
    const overlay = document.getElementById('sidebar-overlay');
    if (overlay && sidebarOpen.value) {
      overlay.classList.add('open');
    } else if (overlay) {
      overlay.classList.remove('open');
    }
    // Ensure body is not locked on mount
    document.body.classList.remove('sidebar-open');
  } catch (error) {
    console.error('Error initializing sidebar overlay:', error);
  }
  
  // Expose loadDashboard to window for child components (for iframe handling)
  window.loadDashboard = loadDashboard;
  
  // Listen for messages from iframes (e.g., inventory/more.html)
  window.addEventListener('message', (event) => {
    if (event.data && event.data.type === 'LOAD_DASHBOARD') {
      const url = event.data.url;
      // Only handle external HTML files - Vue routes should use router-link
      if (url.endsWith('.html') || (url.includes('/') && !url.startsWith('/'))) {
        loadDashboard(url);
      } else {
        // For Vue routes, use router
        router.push(`/${url}`);
      }
    }
  });
  
  updateDateTime();
  setInterval(updateDateTime, 1000);
  
  // Load user data (non-blocking)
  if (!authStore.user) {
    authStore.fetchCurrentUser();
  }
  
  // Initialize Supabase and Advanced ERP Features in background (non-blocking)
  // Use requestIdleCallback or setTimeout to defer heavy initialization
  if (window.requestIdleCallback) {
    requestIdleCallback(() => {
      initializeAdvancedFeatures();
    }, { timeout: 1000 });
  } else {
    setTimeout(() => {
      initializeAdvancedFeatures();
    }, 100);
  }
});

// Initialize Advanced ERP Features in background (non-blocking)
async function initializeAdvancedFeatures() {
  try {
    await initSupabase();
    
    // Load profile photo from Supabase (non-blocking)
    loadProfilePhoto();
    
    // Initialize Advanced ERP Features if Supabase is available (lazy loaded)
    if (USE_SUPABASE && supabaseClient) {
      try {
        const {
          AuditLogger,
          ActivityTracker,
          SessionManager,
          NotificationSystem,
          AnalyticsManager,
          APIKeyManager,
          SystemSettings
        } = await import('@/services/advancedERPFeatures');
        
        auditLogger = new AuditLogger(supabaseClient);
        activityTracker = new ActivityTracker(supabaseClient);
        sessionManager = new SessionManager(supabaseClient);
        notificationSystem = new NotificationSystem(supabaseClient);
        analyticsManager = new AnalyticsManager(supabaseClient);
        apiKeyManager = new APIKeyManager(supabaseClient);
        systemSettings = new SystemSettings(supabaseClient);
        console.log('✅ Advanced ERP features initialized');
        
        // Initialize session and notifications for current user (non-blocking)
        if (authStore.user && authStore.user.id) {
          // Create session (fire and forget)
          sessionManager.createSession(authStore.user.id).then(session => {
            if (session) {
              console.log('✅ Session created:', session.id);
            }
          }).catch(err => console.warn('Session creation failed:', err));
          
          // Track login activity (fire and forget)
          activityTracker.trackActivity('login', 'User logged in successfully', 'Authentication')
            .catch(err => console.warn('Activity tracking failed:', err));
          
          // Start notification polling (fire and forget)
          notificationSystem.startNotificationPolling(authStore.user.id);
          notificationSystem.getNotifications(authStore.user.id, true).then(notifications => {
            notificationSystem.updateNotificationBadge(notifications.length);
          }).catch(err => console.warn('Notification fetch failed:', err));
        }
      } catch (error) {
        console.error('❌ Advanced ERP features initialization failed:', error);
      }
    }
  } catch (error) {
    console.error('❌ Supabase initialization failed:', error);
  }
}

onUnmounted(() => {
  // Cleanup sidebar state
  try {
    document.body.classList.remove('sidebar-open');
    const overlay = document.getElementById('sidebar-overlay');
    if (overlay) {
      overlay.classList.remove('open');
    }
  } catch (error) {
    console.error('Error cleaning up sidebar:', error);
  }
});

// Router params are now accessed directly via route.params in child components
</script>

<style scoped>
/* HomePortal Layout - Enterprise Mobile ERP Standard - Mobile-First */
.app-layout {
  display: flex;
  height: 100vh;
  overflow: hidden;
  position: relative;
}

@media (max-width: 768px) {
  .app-layout {
    flex-direction: column;
  }
}

.sidebar {
  background-color: #284b44;
  display: flex;
  flex-direction: column;
  width: clamp(240px, 30vw, 256px);
}

/* Mobile: Sidebar as Slide-in Drawer */
@media (max-width: 767px) {
  .sidebar {
    position: fixed;
    top: 0;
    left: 0;
    bottom: 0;
    height: 100vh;
    width: clamp(260px, 80vw, 320px);
    max-width: 85vw;
    z-index: 1000;
    transform: translateX(-100%);
    transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
    box-shadow: 4px 0 12px rgba(0, 0, 0, 0.15);
  }
  
  .sidebar.open {
    transform: translateX(0);
  }
  
  /* RTL: Slide from right */
  [dir="rtl"] .sidebar {
    left: auto;
    right: 0;
    transform: translateX(100%);
  }
  
  [dir="rtl"] .sidebar.open {
    transform: translateX(0);
  }
}

.sidebar-overlay {
  display: none;
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  z-index: 999;
  pointer-events: none;
  touch-action: none;
  opacity: 0;
  transition: opacity 0.3s ease;
  -webkit-backdrop-filter: blur(2px);
  backdrop-filter: blur(2px);
}

.sidebar-overlay.open {
  display: block;
  pointer-events: auto;
  opacity: 1;
  touch-action: auto;
}

/* Mobile: Sidebar overlay blocks background ONLY when open */
@media (max-width: 767px) {
  .sidebar-overlay {
    pointer-events: none;
  }
  
  .sidebar-overlay.open {
    pointer-events: auto;
  }
}

/* Mobile-specific fixes */
@media (max-width: 768px) {
  .sidebar {
    z-index: 50;
  }
  
  .sidebar-overlay {
    z-index: 40;
  }
  
  .sidebar-overlay.open {
    pointer-events: auto;
  }
  
  /* Cards stack vertically on mobile */
  .card-grid,
  .grid {
    grid-template-columns: 1fr !important;
    gap: 12px;
  }
  
  /* Main content scrolls on mobile */
  .main-content {
    flex: 1;
    overflow-y: auto;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }
}

/* Router View Wrapper - Allow full content rendering - Mobile-First */
.router-view-wrapper {
  flex: 1;
  padding: clamp(0.5rem, 2vw, 1rem);
  height: auto;
  min-height: 100%;
  overflow-y: auto;
  overflow-x: hidden; /* Prevent horizontal scroll */
  -webkit-overflow-scrolling: touch;
  width: 100%;
  max-width: 100vw;
}

/* Sticky Header - Must NOT overlap content */
.gradient-header {
  position: sticky;
  top: 0;
  z-index: 100;
  min-height: clamp(56px, 14vw, 64px);
  padding: clamp(0.75rem, 2vw, 1rem);
}

/* Mobile: Prevent header from covering content */
@media (max-width: 767px) {
  .gradient-header {
    position: sticky;
    top: 0;
    z-index: 100;
  }
  
  .router-view-wrapper {
    padding-top: 0.5rem;
  }
}

.gradient-header {
  background: linear-gradient(135deg, #284b44 0%, #3d6b5f 100%);
}

.nav-link {
  transition: background-color 0.2s ease, transform 0.1s ease;
  font-weight: 500;
  min-height: 44px; /* Touch target */
  display: flex;
  align-items: center;
  padding: clamp(0.75rem, 2vw, 1rem);
  font-size: clamp(0.875rem, 2.5vw, 1rem);
  -webkit-tap-highlight-color: transparent;
}

.nav-link:hover {
  background-color: rgba(255, 255, 255, 0.1);
}

.nav-link:active {
  transform: scale(0.98);
  background-color: rgba(255, 255, 255, 0.15);
}

.nav-link.active {
  background-color: rgba(234, 137, 144, 0.3) !important;
  border-left: 3px solid #ea8990;
  font-weight: 600;
}

/* RTL: Active border on right */
[dir="rtl"] .nav-link.active {
  border-left: none;
  border-right: 3px solid #ea8990;
}

.nav-sub-item {
  font-weight: 500;
  min-height: 44px; /* Touch target */
  display: flex;
  align-items: center;
  padding: clamp(0.625rem, 1.5vw, 0.75rem);
  font-size: clamp(0.8125rem, 2vw, 0.875rem);
  -webkit-tap-highlight-color: transparent;
}

.nav-sub-item:active {
  transform: scale(0.98);
  background-color: rgba(255, 255, 255, 0.1);
}

.nav-sub-item.active {
  background-color: rgba(234, 137, 144, 0.25) !important;
  border-left: 3px solid #ea8990;
  font-weight: 600;
}

/* RTL: Active border on right */
[dir="rtl"] .nav-sub-item.active {
  border-left: none;
  border-right: 3px solid #ea8990;
}

.nav-group-content {
  max-height: 1000px;
  transition: max-height 0.3s ease;
}

.nav-group-content.hidden {
  max-height: 0;
  overflow: hidden;
}

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
  text-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.kpi-card .title {
  color: #284b44;
  font-weight: 600;
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
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
}

.insight-card {
  background: linear-gradient(145deg, #f0e1cd 0%, #e8d5c0 100%);
  border-radius: 0.75rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(149, 108, 42, 0.2);
}

.analysis-card {
  background: white;
  border: 2px solid;
  border-radius: 0.5rem;
  padding: 1rem;
}

.analysis-card .value {
  font-size: 1.5rem;
  font-weight: 700;
  margin-top: 0.5rem;
}

.health-gauge {
  width: 120px;
  height: 120px;
  border-radius: 50%;
  background: conic-gradient(
    from 0deg,
    #ef4444 0%,
    #f59e0b 25%,
    #eab308 50%,
    #84cc16 75%,
    #22c55e 100%
  );
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}

.health-gauge::before {
  content: '';
  position: absolute;
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: white;
}

.health-score-text {
  position: relative;
  z-index: 1;
  font-size: 1.5rem;
  font-weight: 700;
  color: #284b44;
}

.aging-bar-bg {
  background-color: #e5e7eb;
  border-radius: 9999px;
}

.aging-bar {
  transition: width 0.5s ease;
}

.loading-spinner {
  display: inline-block;
  width: 40px;
  height: 40px;
  border: 4px solid rgba(40, 75, 68, 0.1);
  border-radius: 50%;
  border-top-color: #284b44;
  animation: spin 1s ease-in-out infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
