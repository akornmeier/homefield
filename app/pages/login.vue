<template>
  <UContainer>
    <div class="max-w-md mx-auto py-16">
      <div class="text-center mb-8">
        <h1 class="text-3xl font-bold mb-2">Sign In</h1>
        <p class="text-gray-600 dark:text-gray-400">
          Enter your email to receive a magic link
        </p>
      </div>

      <UCard>
        <template v-if="emailSent">
          <div class="text-center py-4">
            <div class="text-4xl mb-4">📧</div>
            <h2 class="text-xl font-semibold mb-2">Check Your Email</h2>
            <p class="text-gray-600 dark:text-gray-400 mb-4">
              We sent a magic link to <strong>{{ email }}</strong>
            </p>
            <p class="text-sm text-gray-500">
              Didn't receive it? Check your spam folder or
              <UButton variant="link" @click="resetForm">try again</UButton>
            </p>
          </div>
        </template>

        <template v-else>
          <UForm :state="state" :schema="schema" @submit="onSubmit" class="space-y-4">
            <UFormField label="Email" name="email">
              <UInput
                v-model="state.email"
                type="email"
                placeholder="you@example.com"
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
              Send Magic Link
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
        </template>
      </UCard>
    </div>
  </UContainer>
</template>

<script setup lang="ts">
import { z } from 'zod'

definePageMeta({
  layout: 'default'
})

const supabase = useSupabaseClient()

const schema = z.object({
  email: z.string().email('Please enter a valid email')
})

const state = reactive({
  email: ''
})

const email = ref('')
const loading = ref(false)
const emailSent = ref(false)
const error = ref('')

async function onSubmit() {
  loading.value = true
  error.value = ''

  try {
    const { error: authError } = await supabase.auth.signInWithOtp({
      email: state.email,
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback`
      }
    })

    if (authError) {
      throw authError
    }

    email.value = state.email
    emailSent.value = true
  } catch (e: any) {
    error.value = e.message || 'Something went wrong. Please try again.'
  } finally {
    loading.value = false
  }
}

function resetForm() {
  emailSent.value = false
  state.email = ''
  error.value = ''
}
</script>
