import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import { fileURLToPath, URL } from 'node:url'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue(), tailwindcss()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/admin/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/logout': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
      '/docs': {
        target: 'http://localhost:8080',
        changeOrigin: true,
      },
    },
  },
  build: {
    rollupOptions: {
      input: {
        index: fileURLToPath(new URL('./index.html', import.meta.url)),
        'sw-runtime': fileURLToPath(new URL('./src/push/sw-runtime.ts', import.meta.url)),
      },
      output: {
        entryFileNames: (chunkInfo) => {
          if (chunkInfo.name === 'sw-runtime') {
            return 'sw-runtime.js'
          }
          return 'assets/[name]-[hash].js'
        },
      },
    },
  },
})
