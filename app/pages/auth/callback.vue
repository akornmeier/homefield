<template>
  <UContainer>
    <div class="max-w-md mx-auto py-16 text-center">
      <div class="text-4xl mb-4">🔐</div>
      <h1 class="text-2xl font-bold mb-2">Signing you in...</h1>
      <p class="text-gray-600 dark:text-gray-400">
        Please wait while we verify your login.
      </p>
      <UProgress class="mt-8" animation="carousel" />
    </div>
  </UContainer>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'default'
})

const supabase = useSupabaseClient()
const user = useSupabaseUser()

onMounted(async () => {
  // Supabase handles the token exchange automatically via the module
  // We just need to wait for the user to be set and redirect
  
  // Watch for user to be set
  const unwatch = watch(user, async (newUser) => {
    if (newUser) {
      // Check if user has completed profile
      const { data: profile } = await supabase
        .from('users')
        .select('first_name, last_name')
        .eq('id', newUser.id)
        .single()
      
      if (!profile?.first_name || !profile?.last_name) {
        navigateTo('/profile/setup')
      } else {
        navigateTo('/bracket')
      }
      unwatch()
    }
  }, { immediate: true })
  
  // Fallback timeout
  setTimeout(() => {
    if (!user.value) {
      navigateTo('/login')
    }
  }, 5000)
})
</script>
