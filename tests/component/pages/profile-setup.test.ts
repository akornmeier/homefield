// tests/component/pages/profile-setup.test.ts

import { describe, it, expect, vi } from 'vitest'
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime'
import ProfileSetupPage from '~/pages/profile/setup.vue'

// Mock Supabase composables using mockNuxtImport
mockNuxtImport('useSupabaseUser', () => {
  return () => ({
    value: { id: 'test-user', email: 'test@example.com' },
  })
})

mockNuxtImport('useSupabaseClient', () => {
  return () => ({
    from: vi.fn(() => ({
      upsert: vi.fn(() => Promise.resolve({ error: null })),
    })),
  })
})

describe('Profile Setup Page', () => {
  it('renders page heading', async () => {
    const wrapper = await mountSuspended(ProfileSetupPage)
    expect(wrapper.text()).toContain('Complete Your Profile')
  })

  it('has first name input', async () => {
    const wrapper = await mountSuspended(ProfileSetupPage)
    const input = wrapper.find('input[placeholder="John"]')
    expect(input.exists()).toBe(true)
  })

  it('has last name input', async () => {
    const wrapper = await mountSuspended(ProfileSetupPage)
    const input = wrapper.find('input[placeholder="Smith"]')
    expect(input.exists()).toBe(true)
  })

  it('has continue button', async () => {
    const wrapper = await mountSuspended(ProfileSetupPage)
    expect(wrapper.text()).toContain('Continue')
  })
})
