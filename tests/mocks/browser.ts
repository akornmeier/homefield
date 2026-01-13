// tests/mocks/browser.ts

import { setupWorker } from 'msw/browser'
import { createUnauthenticatedHandlers } from './handlers/supabase-auth'

// Default to unauthenticated state
export const worker = setupWorker(...createUnauthenticatedHandlers())

export async function startMSW() {
  await worker.start({
    onUnhandledRequest: 'bypass',
    serviceWorker: {
      url: '/mockServiceWorker.js',
    },
  })
}

export async function stopMSW() {
  worker.stop()
}
