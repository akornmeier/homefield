// tests/setup/component.ts

import { beforeAll, afterAll, afterEach } from 'vitest'
import { worker } from '../mocks/browser'

beforeAll(async () => {
  await worker.start({
    onUnhandledRequest: 'bypass',
    serviceWorker: {
      url: '/mockServiceWorker.js',
    },
  })
})

afterEach(() => {
  worker.resetHandlers()
})

afterAll(() => {
  worker.stop()
})
