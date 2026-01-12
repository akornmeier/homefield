<template>
  <UContainer>
    <div class="max-w-2xl mx-auto text-center py-16">
      <!-- Hero -->
      <h1 class="text-5xl font-bold mb-4">
        🏈 Homefield
      </h1>
      <p class="text-xl text-gray-600 dark:text-gray-400 mb-8">
        Fill out your NFL playoff bracket, pay your entry, and compete with friends.
      </p>

      <!-- Pool Info Card -->
      <UCard class="mb-8">
        <div class="grid grid-cols-2 gap-6 text-left">
          <div>
            <p class="text-sm text-gray-500 dark:text-gray-400">Entry Fee</p>
            <p class="text-2xl font-semibold">${{ entryFee }}</p>
          </div>
          <div>
            <p class="text-sm text-gray-500 dark:text-gray-400">Picks Lock In</p>
            <p class="text-2xl font-semibold">{{ locksAtDisplay }}</p>
          </div>
        </div>
        
        <!-- Countdown -->
        <template v-if="timeRemaining">
          <UDivider class="my-4" />
          <div class="text-center">
            <p class="text-sm text-gray-500 dark:text-gray-400 mb-1">Time Remaining</p>
            <p class="text-3xl font-mono font-bold text-primary">
              {{ timeRemaining }}
            </p>
          </div>
        </template>
      </UCard>

      <!-- CTA -->
      <div class="flex justify-center gap-4">
        <template v-if="user">
          <NuxtLink to="/bracket">
            <UButton size="lg">Go to My Brackets</UButton>
          </NuxtLink>
        </template>
        <template v-else>
          <NuxtLink to="/login">
            <UButton size="lg">Sign In to Play</UButton>
          </NuxtLink>
        </template>
      </div>

      <!-- Scoring Info -->
      <div class="mt-16 text-left">
        <h2 class="text-2xl font-bold mb-4 text-center">How Scoring Works</h2>
        <UCard>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
            <div>
              <p class="text-3xl font-bold text-primary">1 pt</p>
              <p class="text-sm text-gray-500">Wild Card</p>
            </div>
            <div>
              <p class="text-3xl font-bold text-primary">2 pts</p>
              <p class="text-sm text-gray-500">Divisional</p>
            </div>
            <div>
              <p class="text-3xl font-bold text-primary">4 pts</p>
              <p class="text-sm text-gray-500">Conference</p>
            </div>
            <div>
              <p class="text-3xl font-bold text-primary">8 pts</p>
              <p class="text-sm text-gray-500">Super Bowl</p>
            </div>
          </div>
          <UDivider class="my-4" />
          <p class="text-sm text-gray-500 dark:text-gray-400 text-center">
            <strong>Tiebreakers:</strong> Closest to actual Super Bowl total points, then total yards.
          </p>
        </UCard>
      </div>
    </div>
  </UContainer>
</template>

<script setup lang="ts">
const user = useSupabaseUser()

// TODO: Fetch from pool settings
const entryFee = ref(20)
const locksAt = ref(new Date('2026-01-11T13:00:00')) // Example: Wild Card Saturday kickoff

const locksAtDisplay = computed(() => {
  return locksAt.value.toLocaleDateString('en-US', {
    weekday: 'short',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  })
})

const timeRemaining = ref('')

function updateCountdown() {
  const now = new Date()
  const diff = locksAt.value.getTime() - now.getTime()
  
  if (diff <= 0) {
    timeRemaining.value = ''
    return
  }
  
  const days = Math.floor(diff / (1000 * 60 * 60 * 24))
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
  const seconds = Math.floor((diff % (1000 * 60)) / 1000)
  
  timeRemaining.value = `${days}d ${hours}h ${minutes}m ${seconds}s`
}

onMounted(() => {
  updateCountdown()
  setInterval(updateCountdown, 1000)
})
</script>
