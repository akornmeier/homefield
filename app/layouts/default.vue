<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-950">
    <!-- Navigation -->
    <UContainer>
      <header class="flex items-center justify-between py-4 border-b border-gray-200 dark:border-gray-800">
        <NuxtLink to="/" class="text-xl font-bold text-primary">
          Homefield
        </NuxtLink>
        
        <nav class="flex items-center gap-4">
          <template v-if="user">
            <NuxtLink to="/bracket">
              <UButton variant="ghost">My Brackets</UButton>
            </NuxtLink>
            <NuxtLink to="/leaderboard">
              <UButton variant="ghost">Leaderboard</UButton>
            </NuxtLink>
            <UButton variant="soft" @click="signOut">Sign Out</UButton>
          </template>
          <template v-else>
            <NuxtLink to="/login">
              <UButton>Sign In</UButton>
            </NuxtLink>
          </template>
        </nav>
      </header>
    </UContainer>

    <!-- Main Content -->
    <main class="py-8">
      <slot />
    </main>
  </div>
</template>

<script setup lang="ts">
const user = useSupabaseUser()
const supabase = useSupabaseClient()

async function signOut() {
  await supabase.auth.signOut()
  navigateTo('/login')
}
</script>
