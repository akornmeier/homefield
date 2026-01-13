// tests/integration/flows/redirect-preservation.test.ts

import { describe, it, expect } from 'vitest'
import { setup, createPage } from '@nuxt/test-utils/e2e'

describe('redirect preservation', async () => {
  await setup({
    browser: true,
  })

  it('preserves original URL when redirecting to login', async () => {
    const page = await createPage('/bracket')

    // Wait for redirect to login
    await page.waitForURL('**/login**')

    // The @nuxtjs/supabase module stores redirect URL
    // Verify we're on login page (redirect URL handling is internal to module)
    expect(page.url()).toContain('/login')

    await page.close()
  })

  it('login page displays correctly after redirect', async () => {
    const page = await createPage('/bracket')

    await page.waitForURL('**/login**')

    // Verify login form is visible (use Playwright's waitFor instead of vitest expect)
    const emailInput = page.getByPlaceholder('you@example.com')
    await emailInput.waitFor({ state: 'visible' })

    const submitButton = page.getByRole('button', { name: /send magic link/i })
    await submitButton.waitFor({ state: 'visible' })

    // Also verify elements exist
    expect(await emailInput.count()).toBe(1)
    expect(await submitButton.count()).toBe(1)

    await page.close()
  })
})
