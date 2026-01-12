<template>
  <UContainer>
    <div class="max-w-4xl mx-auto">
      <!-- Header -->
      <div class="flex items-center justify-between mb-8">
        <h1 class="text-3xl font-bold">My Brackets</h1>
        <UButton @click="createBracket" :loading="creating">
          <template #leading>
            <UIcon name="i-heroicons-plus" />
          </template>
          New Bracket
        </UButton>
      </div>

      <!-- Brackets List -->
      <div v-if="brackets.length > 0" class="space-y-4">
        <UCard 
          v-for="bracket in brackets" 
          :key="bracket.id"
          class="hover:border-primary transition-colors"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-4">
              <div>
                <h3 class="font-semibold text-lg">
                  {{ bracket.name || `Bracket #${bracket.number}` }}
                </h3>
                <p class="text-sm text-gray-500">
                  Created {{ formatDate(bracket.created_at) }}
                </p>
              </div>
            </div>

            <div class="flex items-center gap-4">
              <!-- Status Badge -->
              <UBadge 
                :color="bracket.payment_status === 'paid' ? 'success' : 'warning'"
                variant="soft"
              >
                {{ bracket.payment_status === 'paid' ? 'Paid' : 'Unpaid' }}
              </UBadge>

              <!-- Actions -->
              <div class="flex gap-2">
                <NuxtLink :to="`/bracket/${bracket.id}`">
                  <UButton variant="soft">
                    {{ bracket.payment_status === 'paid' ? 'View' : 'Edit' }}
                  </UButton>
                </NuxtLink>
                <UButton 
                  v-if="bracket.payment_status !== 'paid'"
                  variant="ghost" 
                  color="error"
                  @click="deleteBracket(bracket.id)"
                >
                  <UIcon name="i-heroicons-trash" />
                </UButton>
              </div>
            </div>
          </div>
        </UCard>
      </div>

      <!-- Empty State -->
      <UCard v-else class="text-center py-12">
        <div class="text-4xl mb-4">🏈</div>
        <h3 class="text-xl font-semibold mb-2">No brackets yet</h3>
        <p class="text-gray-500 mb-6">Create your first bracket to get started!</p>
        <UButton @click="createBracket">Create Bracket</UButton>
      </UCard>

      <!-- Checkout Section -->
      <template v-if="unpaidBrackets.length > 0">
        <UDivider class="my-8" />
        
        <UCard>
          <div class="flex items-center justify-between">
            <div>
              <h3 class="font-semibold text-lg">Ready to Submit?</h3>
              <p class="text-gray-500">
                {{ unpaidBrackets.length }} unpaid bracket{{ unpaidBrackets.length > 1 ? 's' : '' }} 
                × ${{ entryFee }} = <strong>${{ unpaidBrackets.length * entryFee }}</strong>
              </p>
            </div>
            <NuxtLink to="/checkout">
              <UButton size="lg">
                Pay & Submit
              </UButton>
            </NuxtLink>
          </div>
        </UCard>
      </template>
    </div>
  </UContainer>
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'default',
  middleware: 'auth'
})

const supabase = useSupabaseClient()
const user = useSupabaseUser()
const toast = useToast()

const brackets = ref<any[]>([])
const creating = ref(false)
const entryFee = 20 // TODO: Fetch from pool

const unpaidBrackets = computed(() => 
  brackets.value.filter(b => b.payment_status !== 'paid')
)

async function fetchBrackets() {
  if (!user.value) return

  const { data, error } = await supabase
    .from('brackets')
    .select('*')
    .eq('user_id', user.value.id)
    .order('created_at', { ascending: false })

  if (error) {
    toast.add({ title: 'Error loading brackets', color: 'error' })
    return
  }

  // Add number for display
  brackets.value = (data || []).map((b, i, arr) => ({
    ...b,
    number: arr.length - i
  }))
}

async function createBracket() {
  if (!user.value) return

  creating.value = true

  try {
    // TODO: Get pool_id from context
    const { data, error } = await supabase
      .from('brackets')
      .insert({
        user_id: user.value.id,
        pool_id: '00000000-0000-0000-0000-000000000001', // Placeholder
        payment_status: 'unpaid'
      })
      .select()
      .single()

    if (error) throw error

    navigateTo(`/bracket/${data.id}`)
  } catch (e: any) {
    toast.add({ title: e.message || 'Error creating bracket', color: 'error' })
  } finally {
    creating.value = false
  }
}

async function deleteBracket(id: string) {
  const { error } = await supabase
    .from('brackets')
    .delete()
    .eq('id', id)

  if (error) {
    toast.add({ title: 'Error deleting bracket', color: 'error' })
    return
  }

  brackets.value = brackets.value.filter(b => b.id !== id)
  toast.add({ title: 'Bracket deleted', color: 'success' })
}

function formatDate(date: string) {
  return new Date(date).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  })
}

onMounted(fetchBrackets)
</script>
