// tests/component/pages/bracket.test.ts

import { describe, it, expect, vi } from 'vitest'
import { mountSuspended, mockNuxtImport } from '@nuxt/test-utils/runtime'
import BracketPage from '~/pages/bracket/index.vue'

// Mock Supabase composables using mockNuxtImport
mockNuxtImport('useSupabaseUser', () => {
  return () => ({
    value: { id: 'test-user', email: 'test@example.com' },
  })
})

mockNuxtImport('useSupabaseClient', () => {
  return () => ({
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          order: vi.fn(() => Promise.resolve({ data: [], error: null })),
        })),
      })),
    })),
  })
})

mockNuxtImport('useToast', () => {
  return () => ({
    add: vi.fn(),
  })
})

describe('Bracket Page', () => {
  it('renders page heading', async () => {
    const wrapper = await mountSuspended(BracketPage)
    expect(wrapper.text()).toContain('My Brackets')
  })

  it('shows empty state when no brackets exist', async () => {
    const wrapper = await mountSuspended(BracketPage)
    expect(wrapper.text()).toContain('No brackets yet')
    expect(wrapper.text()).toContain('Create your first bracket')
  })

  it('has create bracket button', async () => {
    const wrapper = await mountSuspended(BracketPage)
    const button = wrapper.find('button')
    expect(button.exists()).toBe(true)
  })
})
