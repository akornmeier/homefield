// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-01-12',
  devtools: { enabled: true },

  modules: [
    '@nuxt/ui',
    '@nuxtjs/supabase'
  ],

  css: ['~/assets/css/main.css'],

  supabase: {
    redirect: true,
    redirectOptions: {
      login: '/login',
      callback: '/auth/callback',
      exclude: ['/', '/join']
    }
  },

  runtimeConfig: {
    paypalClientSecret: process.env.PAYPAL_CLIENT_SECRET,
    public: {
      paypalClientId: process.env.PAYPAL_CLIENT_ID
    }
  },

  future: {
    compatibilityVersion: 4
  }
})
