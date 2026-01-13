// tests/mocks/handlers/supabase-auth.ts

import { http, HttpResponse } from 'msw'
import type { User } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL || 'http://127.0.0.1:54321'

interface Session {
  access_token: string
  token_type: string
  expires_in: number
  expires_at: number
  refresh_token: string
  user: Partial<User>
}

function createSession(user: Partial<User>): Session {
  return {
    access_token: 'test-access-token',
    token_type: 'bearer',
    expires_in: 3600,
    expires_at: Math.floor(Date.now() / 1000) + 3600,
    refresh_token: 'test-refresh-token',
    user,
  }
}

export function createAuthenticatedHandlers(user: Partial<User>) {
  const session = createSession(user)

  return [
    // Get current user
    http.get(`${SUPABASE_URL}/auth/v1/user`, () => {
      return HttpResponse.json(user)
    }),

    // Token refresh
    http.post(`${SUPABASE_URL}/auth/v1/token`, () => {
      return HttpResponse.json(session)
    }),

    // Get session
    http.get(`${SUPABASE_URL}/auth/v1/session`, () => {
      return HttpResponse.json(session)
    }),
  ]
}

export function createUnauthenticatedHandlers() {
  return [
    // Get current user - 401
    http.get(`${SUPABASE_URL}/auth/v1/user`, () => {
      return new HttpResponse(null, { status: 401 })
    }),

    // Token refresh - 401
    http.post(`${SUPABASE_URL}/auth/v1/token`, () => {
      return new HttpResponse(null, { status: 401 })
    }),

    // Get session - null
    http.get(`${SUPABASE_URL}/auth/v1/session`, () => {
      return HttpResponse.json(null)
    }),
  ]
}

export function createExpiredSessionHandlers(user: Partial<User>) {
  let callCount = 0

  return [
    // Get current user - works first time, then 401
    http.get(`${SUPABASE_URL}/auth/v1/user`, () => {
      callCount++
      if (callCount === 1) {
        return HttpResponse.json(user)
      }
      return new HttpResponse(null, { status: 401 })
    }),

    // Token refresh - always fails (expired)
    http.post(`${SUPABASE_URL}/auth/v1/token`, () => {
      return HttpResponse.json(
        { error: 'invalid_grant', error_description: 'Token has expired' },
        { status: 400 }
      )
    }),
  ]
}

// OTP (magic link) request handler
export function createOtpHandler(shouldSucceed = true) {
  return http.post(`${SUPABASE_URL}/auth/v1/otp`, () => {
    if (shouldSucceed) {
      return HttpResponse.json({})
    }
    return HttpResponse.json(
      { error: 'rate_limit', error_description: 'Too many requests' },
      { status: 429 }
    )
  })
}

// Logout handler
export function createLogoutHandler() {
  return http.post(`${SUPABASE_URL}/auth/v1/logout`, () => {
    return HttpResponse.json({})
  })
}
