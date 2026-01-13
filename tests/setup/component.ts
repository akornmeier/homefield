// tests/setup/component.ts

import { beforeAll, afterAll, afterEach } from 'vitest'
import { startMSW, stopMSW, worker } from '../mocks/browser'

beforeAll(async () => {
  await startMSW()
})

afterEach(() => {
  worker.resetHandlers()
})

afterAll(() => {
  stopMSW()
})
