// vite.config.js
import { defineConfig } from "file:///C:/Users/shahf/Downloads/ERP_CLOUD/sakura-erp-system/ERP_Final%20-%20-%20Without_React2/ERP_Final%20-%20-%20Without_React/sakura-erp-migration/frontend/node_modules/vite/dist/node/index.js";
import vue from "file:///C:/Users/shahf/Downloads/ERP_CLOUD/sakura-erp-system/ERP_Final%20-%20-%20Without_React2/ERP_Final%20-%20-%20Without_React/sakura-erp-migration/frontend/node_modules/@vitejs/plugin-vue/dist/index.mjs";
import path from "path";
var __vite_injected_original_dirname = "C:\\Users\\shahf\\Downloads\\ERP_CLOUD\\sakura-erp-system\\ERP_Final - - Without_React2\\ERP_Final - - Without_React\\sakura-erp-migration\\frontend";
var vite_config_default = defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": path.resolve(__vite_injected_original_dirname, "./src")
    }
  },
  optimizeDeps: {
    include: ["vue-i18n"]
  },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true
      }
    },
    // Serve static files from project root for external HTML dashboards
    fs: {
      allow: [".."]
    }
  },
  // Copy external HTML files to public folder during build
  publicDir: "public",
  build: {
    outDir: "dist",
    assetsDir: "assets",
    sourcemap: false,
    minify: "esbuild",
    // Use esbuild (faster, less memory) instead of terser
    rollupOptions: {
      output: {
        manualChunks: {
          "vue-vendor": ["vue", "vue-router", "pinia"],
          "supabase": ["@supabase/supabase-js"]
        }
      }
    },
    chunkSizeWarningLimit: 1e3
  },
  base: "/"
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcuanMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCJDOlxcXFxVc2Vyc1xcXFxzaGFoZlxcXFxEb3dubG9hZHNcXFxcRVJQX0NMT1VEXFxcXHNha3VyYS1lcnAtc3lzdGVtXFxcXEVSUF9GaW5hbCAtIC0gV2l0aG91dF9SZWFjdDJcXFxcRVJQX0ZpbmFsIC0gLSBXaXRob3V0X1JlYWN0XFxcXHNha3VyYS1lcnAtbWlncmF0aW9uXFxcXGZyb250ZW5kXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ZpbGVuYW1lID0gXCJDOlxcXFxVc2Vyc1xcXFxzaGFoZlxcXFxEb3dubG9hZHNcXFxcRVJQX0NMT1VEXFxcXHNha3VyYS1lcnAtc3lzdGVtXFxcXEVSUF9GaW5hbCAtIC0gV2l0aG91dF9SZWFjdDJcXFxcRVJQX0ZpbmFsIC0gLSBXaXRob3V0X1JlYWN0XFxcXHNha3VyYS1lcnAtbWlncmF0aW9uXFxcXGZyb250ZW5kXFxcXHZpdGUuY29uZmlnLmpzXCI7Y29uc3QgX192aXRlX2luamVjdGVkX29yaWdpbmFsX2ltcG9ydF9tZXRhX3VybCA9IFwiZmlsZTovLy9DOi9Vc2Vycy9zaGFoZi9Eb3dubG9hZHMvRVJQX0NMT1VEL3Nha3VyYS1lcnAtc3lzdGVtL0VSUF9GaW5hbCUyMC0lMjAtJTIwV2l0aG91dF9SZWFjdDIvRVJQX0ZpbmFsJTIwLSUyMC0lMjBXaXRob3V0X1JlYWN0L3Nha3VyYS1lcnAtbWlncmF0aW9uL2Zyb250ZW5kL3ZpdGUuY29uZmlnLmpzXCI7aW1wb3J0IHsgZGVmaW5lQ29uZmlnIH0gZnJvbSAndml0ZSc7XHJcbmltcG9ydCB2dWUgZnJvbSAnQHZpdGVqcy9wbHVnaW4tdnVlJztcclxuaW1wb3J0IHBhdGggZnJvbSAncGF0aCc7XHJcblxyXG5leHBvcnQgZGVmYXVsdCBkZWZpbmVDb25maWcoe1xyXG4gIHBsdWdpbnM6IFt2dWUoKV0sXHJcbiAgcmVzb2x2ZToge1xyXG4gICAgYWxpYXM6IHtcclxuICAgICAgJ0AnOiBwYXRoLnJlc29sdmUoX19kaXJuYW1lLCAnLi9zcmMnKVxyXG4gICAgfVxyXG4gIH0sXHJcbiAgb3B0aW1pemVEZXBzOiB7XHJcbiAgICBpbmNsdWRlOiBbJ3Z1ZS1pMThuJ11cclxuICB9LFxyXG4gIHNlcnZlcjoge1xyXG4gICAgcG9ydDogNTE3MyxcclxuICAgIHByb3h5OiB7XHJcbiAgICAgICcvYXBpJzoge1xyXG4gICAgICAgIHRhcmdldDogJ2h0dHA6Ly9sb2NhbGhvc3Q6MzAwMCcsXHJcbiAgICAgICAgY2hhbmdlT3JpZ2luOiB0cnVlXHJcbiAgICAgIH1cclxuICAgIH0sXHJcbiAgICAvLyBTZXJ2ZSBzdGF0aWMgZmlsZXMgZnJvbSBwcm9qZWN0IHJvb3QgZm9yIGV4dGVybmFsIEhUTUwgZGFzaGJvYXJkc1xyXG4gICAgZnM6IHtcclxuICAgICAgYWxsb3c6IFsnLi4nXVxyXG4gICAgfVxyXG4gIH0sXHJcbiAgLy8gQ29weSBleHRlcm5hbCBIVE1MIGZpbGVzIHRvIHB1YmxpYyBmb2xkZXIgZHVyaW5nIGJ1aWxkXHJcbiAgcHVibGljRGlyOiAncHVibGljJyxcclxuICBidWlsZDoge1xyXG4gICAgb3V0RGlyOiAnZGlzdCcsXHJcbiAgICBhc3NldHNEaXI6ICdhc3NldHMnLFxyXG4gICAgc291cmNlbWFwOiBmYWxzZSxcclxuICAgIG1pbmlmeTogJ2VzYnVpbGQnLCAvLyBVc2UgZXNidWlsZCAoZmFzdGVyLCBsZXNzIG1lbW9yeSkgaW5zdGVhZCBvZiB0ZXJzZXJcclxuICAgIHJvbGx1cE9wdGlvbnM6IHtcclxuICAgICAgb3V0cHV0OiB7XHJcbiAgICAgICAgbWFudWFsQ2h1bmtzOiB7XHJcbiAgICAgICAgICAndnVlLXZlbmRvcic6IFsndnVlJywgJ3Z1ZS1yb3V0ZXInLCAncGluaWEnXSxcclxuICAgICAgICAgICdzdXBhYmFzZSc6IFsnQHN1cGFiYXNlL3N1cGFiYXNlLWpzJ11cclxuICAgICAgICB9XHJcbiAgICAgIH1cclxuICAgIH0sXHJcbiAgICBjaHVua1NpemVXYXJuaW5nTGltaXQ6IDEwMDBcclxuICB9LFxyXG4gIGJhc2U6ICcvJ1xyXG59KTtcclxuXHJcbiJdLAogICJtYXBwaW5ncyI6ICI7QUFBbW5CLFNBQVMsb0JBQW9CO0FBQ2hwQixPQUFPLFNBQVM7QUFDaEIsT0FBTyxVQUFVO0FBRmpCLElBQU0sbUNBQW1DO0FBSXpDLElBQU8sc0JBQVEsYUFBYTtBQUFBLEVBQzFCLFNBQVMsQ0FBQyxJQUFJLENBQUM7QUFBQSxFQUNmLFNBQVM7QUFBQSxJQUNQLE9BQU87QUFBQSxNQUNMLEtBQUssS0FBSyxRQUFRLGtDQUFXLE9BQU87QUFBQSxJQUN0QztBQUFBLEVBQ0Y7QUFBQSxFQUNBLGNBQWM7QUFBQSxJQUNaLFNBQVMsQ0FBQyxVQUFVO0FBQUEsRUFDdEI7QUFBQSxFQUNBLFFBQVE7QUFBQSxJQUNOLE1BQU07QUFBQSxJQUNOLE9BQU87QUFBQSxNQUNMLFFBQVE7QUFBQSxRQUNOLFFBQVE7QUFBQSxRQUNSLGNBQWM7QUFBQSxNQUNoQjtBQUFBLElBQ0Y7QUFBQTtBQUFBLElBRUEsSUFBSTtBQUFBLE1BQ0YsT0FBTyxDQUFDLElBQUk7QUFBQSxJQUNkO0FBQUEsRUFDRjtBQUFBO0FBQUEsRUFFQSxXQUFXO0FBQUEsRUFDWCxPQUFPO0FBQUEsSUFDTCxRQUFRO0FBQUEsSUFDUixXQUFXO0FBQUEsSUFDWCxXQUFXO0FBQUEsSUFDWCxRQUFRO0FBQUE7QUFBQSxJQUNSLGVBQWU7QUFBQSxNQUNiLFFBQVE7QUFBQSxRQUNOLGNBQWM7QUFBQSxVQUNaLGNBQWMsQ0FBQyxPQUFPLGNBQWMsT0FBTztBQUFBLFVBQzNDLFlBQVksQ0FBQyx1QkFBdUI7QUFBQSxRQUN0QztBQUFBLE1BQ0Y7QUFBQSxJQUNGO0FBQUEsSUFDQSx1QkFBdUI7QUFBQSxFQUN6QjtBQUFBLEVBQ0EsTUFBTTtBQUNSLENBQUM7IiwKICAibmFtZXMiOiBbXQp9Cg==
