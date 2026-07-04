import { createApp } from 'vue'
import { createPinia } from 'pinia'
import App from './App.vue'
import router from './router'
import { useThemeStore } from './stores/theme'
import { useLocaleStore } from './stores/locale'
import { i18n } from './i18n'
import './style.css'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(i18n)
app.use(router)

// Initialize theme before mounting
const themeStore = useThemeStore(pinia)
themeStore.initializeTheme()

// Initialize locale before mounting
const localeStore = useLocaleStore(pinia)
localeStore.initializeLocale()

app.mount('#app')
