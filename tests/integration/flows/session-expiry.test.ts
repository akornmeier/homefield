// tests/integration/flows/session-expiry.test.ts

import { describe, it, expect } from 'vitest'
import { setup, createPage } from '@nuxt/test-utils/e2e'

describe('session expiry', async () => {
  await setup({
    browser: true,
  })

  it('redirects to login when session expires during navigation', async () => {
    // This test verifies behavior when auth state changes mid-session
    // The @nuxtjs/supabase module handles session refresh automatically
    // When refresh fails, it should redirect to login

    const page = await createPage('/')

    // Simulate session expiry by clearing any stored auth
    await page.evaluate(() => {
      localStorage.clear()
      sessionStorage.clear()
    })

    // Try to navigate to protected route
    await page.goto('/bracket')

    // Should be redirected to login
    await page.waitForURL('**/login**')
    expect(page.url()).toContain('/login')

    await page.close()
  })

  it('handles graceful redirect without errors', async () => {
    const page = await createPage()

    // Register error listener before navigation to catch all errors
    const errors: string[] = []
    page.on('pageerror', (error) => {
      errors.push(error.message)
    })

    await page.goto('/bracket')
    await page.waitForURL('**/login**')

    // No critical errors should occur
    const criticalErrors = errors.filter(
      (e) => !e.includes('401') && !e.includes('Unauthorized')
    )
    expect(criticalErrors).toHaveLength(0)

    await page.close()
  })
})
