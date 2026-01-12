<template>
  <UContainer>
    <div class="max-w-md mx-auto py-16">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold mb-2">Complete Your Profile</h1>
        <p class="text-gray-600 dark:text-gray-400">
          Tell us your name for the leaderboard
        </p>
      </div>

      <UCard>
        <UForm :state="state" :schema="schema" @submit="onSubmit" class="space-y-4">
          <UFormField label="First Name" name="firstName">
            <UInput
              v-model="state.firstName"
              placeholder="John"
              size="lg"
              :disabled="loading"
            />
          </UFormField>

          <UFormField label="Last Name" name="lastName">
            <UInput
              v-model="state.lastName"
              placeholder="Smith"
              size="lg"
              :disabled="loading"
            />
          </UFormField>

          <UButton
            type="submit"
            block
            size="lg"
            :loading="loading"
          >
            Continue
          </UButton>
        </UForm>

        <template v-if="error">
          <UAlert
            class="mt-4"
            color="error"
            variant="soft"
            :title="error"
          />
        </template>
      </UCard>
    </div>
  </UContainer>
</template>

<script setup lang="ts">
import { z } from 'zod'

definePageMeta({
  layout: 'default',
  middleware: 'auth'
})

const supabase = useSupabaseClient()
const user = useSupabaseUser()

const schema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required')
})

const state = reactive({
  firstName: '',
  lastName: ''
})

const loading = ref(false)
const error = ref('')

async function onSubmit() {
  if (!user.value) return

  loading.value = true
  error.value = ''

  try {
    const { error: updateError } = await supabase
      .from('users')
      .upsert({
        id: user.value.id,
        email: user.value.email,
        first_name: state.firstName,
        last_name: state.lastName
      })

    if (updateError) {
      throw updateError
    }

    navigateTo('/bracket')
  } catch (e: any) {
    error.value = e.message || 'Something went wrong. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>
