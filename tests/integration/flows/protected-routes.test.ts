// tests/integration/flows/protected-routes.test.ts

import { describe, it, expect } from 'vitest'
import { setup, createPage } from '@nuxt/test-utils/e2e'

describe('protected routes', async () => {
  await setup({
    browser: true,
  })

  describe('when unauthenticated', () => {
    it('redirects /bracket to /login', async () => {
      const page = await createPage('/bracket')

      // Should be redirected to login
      await page.waitForURL('**/login**')
      expect(page.url()).toContain('/login')

      await page.close()
    })

    it('redirects /profile/setup to /login', async () => {
      const page = await createPage('/profile/setup')

      // Should be redirected to login
      await page.waitForURL('**/login**')
      expect(page.url()).toContain('/login')

      await page.close()
    })
  })

  describe('when authenticated with complete profile', () => {
    // Note: Full auth testing requires MSW in the Nuxt app context
    // These tests verify the pages render correctly
    it.todo('allows access to /bracket when authenticated')
    it.todo('allows access to /profile/setup when authenticated')
  })
})
