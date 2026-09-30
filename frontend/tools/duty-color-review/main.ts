import { createApp } from 'vue'
import { createI18n } from 'vue-i18n'
import '../../src/style.css'
import App from './ReviewApp.vue'
import ko from '../../src/i18n/messages/ko'
createApp(App).use(createI18n({ legacy: false, locale: 'ko', messages: { ko } })).mount('#app')
