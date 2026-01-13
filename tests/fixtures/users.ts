// tests/fixtures/users.ts

import type { User } from '@supabase/supabase-js'

export const completeUser: Partial<User> = {
  id: 'test-user-123',
  email: 'complete@example.com',
  aud: 'authenticated',
  role: 'authenticated',
  email_confirmed_at: '2026-01-01T00:00:00Z',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
  user_metadata: {
    profile_complete: true,
  },
  app_metadata: {
    provider: 'email',
  },
}

export const incompleteProfileUser: Partial<User> = {
  id: 'test-user-456',
  email: 'incomplete@example.com',
  aud: 'authenticated',
  role: 'authenticated',
  email_confirmed_at: '2026-01-01T00:00:00Z',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z',
  user_metadata: {
    profile_complete: false,
  },
  app_metadata: {
    provider: 'email',
  },
}

export const nullUser = null
