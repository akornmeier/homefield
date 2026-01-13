# Router Testing Design

## Overview

Add comprehensive testing for router logic with focus on protected route access patterns. Uses a layered testing pyramid with Vitest, MSW, and Playwright browser mode.

## Testing Stack

| Tool | Purpose |
|------|---------|
| Vitest (latest) | Test framework with workspace support |
| @vitest/browser | Browser mode for component + integration tests |
| Playwright | Browser provider for Vitest browser mode |
| MSW | Mocks Supabase auth API at network level |
| @vue/test-utils | Vue component mounting utilities |

## Dependencies

```json
{
  "devDependencies": {
    "vitest": "latest",
    "@vitest/browser": "latest",
    "@vitest/coverage-v8": "latest",
    "msw": "latest",
    "playwright": "latest",
    "@vue/test-utils": "latest"
  }
}
```

## Test Directory Structure

```
/tests
  /unit
    /middleware
      auth.test.ts              # Auth middleware logic tests
  /component
    /pages
      bracket.test.ts           # Bracket page with mocked auth
      profile-setup.test.ts     # Profile setup page with mocked auth
  /integration
    /flows
      protected-routes.test.ts      # Full navigation flows
      session-expiry.test.ts        # Session timeout scenarios
      redirect-preservation.test.ts # Return URL handling
  /mocks
    /handlers
      supabase-auth.ts          # MSW handlers for Supabase auth API
    browser.ts                  # MSW browser setup
  /fixtures
    users.ts                    # Test user data
```

## Vitest Configuration

Three workspaces with different environments:

### Unit Workspace
- **Environment**: `node` (fastest)
- **Purpose**: Test middleware logic in isolation
- **Mocking**: Nuxt composables via `vi.mock()`

### Component Workspace
- **Environment**: `browser` with Playwright provider
- **Purpose**: Test page components with real browser rendering
- **Mocking**: Auth composables mocked, MSW for API calls

### Integration Workspace
- **Environment**: `browser` with Playwright provider
- **Purpose**: Full page navigation and user flows
- **Mocking**: MSW intercepts all Supabase calls

### Package Scripts

```json
{
  "test": "vitest",
  "test:unit": "vitest --project unit",
  "test:component": "vitest --project component",
  "test:integration": "vitest --project integration",
  "test:coverage": "vitest --coverage"
}
```

## Test Scenarios

### Unit Tests (middleware/auth.test.ts)

| Scenario | Input | Expected |
|----------|-------|----------|
| Unauthenticated user | `useSupabaseUser()` returns `null` | Calls `navigateTo('/login')` |
| Authenticated user | `useSupabaseUser()` returns user object | Allows navigation (no redirect) |
| Auth state loading | `useSupabaseUser()` returns `undefined` | Handles loading state gracefully |

### Component Tests (pages)

| Page | Scenario | Expected |
|------|----------|----------|
| `/bracket` | Unauthenticated | Redirects to `/login` |
| `/bracket` | Authenticated, profile complete | Renders bracket content |
| `/bracket` | Authenticated, profile incomplete | Redirects to `/profile/setup` |
| `/profile/setup` | Unauthenticated | Redirects to `/login` |
| `/profile/setup` | Authenticated | Renders profile form |

### Integration Tests (full flows)

| Flow | Steps | Verification |
|------|-------|--------------|
| Protected route redirect | Visit `/bracket` unauthenticated | URL is `/login`, original URL preserved |
| Post-login redirect | Complete login | Redirected to original destination |
| Session expiry | Session expires mid-navigation | Graceful redirect to `/login` |
| Cross-route navigation | `/bracket` → `/profile/setup` → back | Auth state persists |
| Partial auth state | Logged in, missing profile → `/bracket` | Redirected to `/profile/setup` |

## MSW Mocking Strategy

### Supabase Auth Endpoints

```
POST /auth/v1/token?grant_type=password      # Login
POST /auth/v1/token?grant_type=refresh_token # Session refresh
GET  /auth/v1/user                           # Get current user
POST /auth/v1/logout                         # Sign out
POST /auth/v1/otp                            # Magic link request
```

### Handler Factory Pattern

```typescript
// tests/mocks/handlers/supabase-auth.ts

createAuthenticatedHandlers(user)     // Logged-in user responses
createUnauthenticatedHandlers()       // 401 responses
createExpiredSessionHandlers()        // Valid then expired on refresh
createIncompleteProfileHandlers()     // User exists, profile incomplete
```

### Test Fixtures

```typescript
// tests/fixtures/users.ts

export const completeUser = {
  id: 'uuid-123',
  email: 'test@example.com',
  user_metadata: { profile_complete: true }
}

export const incompleteProfileUser = {
  id: 'uuid-456',
  email: 'new@example.com',
  user_metadata: { profile_complete: false }
}
```

### Per-Test Handler Overrides

```typescript
test('handles session expiry', async () => {
  // Start authenticated
  server.use(...createAuthenticatedHandlers(completeUser))
  await page.goto('/bracket')

  // Simulate expiry
  server.use(...createExpiredSessionHandlers())
  await page.click('a[href="/profile/setup"]')

  // Should redirect to login
  expect(page.url()).toContain('/login')
})
```

## Files to Create

1. `vitest.config.ts` - Main config with 3 workspaces
2. `tests/mocks/handlers/supabase-auth.ts` - MSW handler factories
3. `tests/mocks/browser.ts` - MSW browser setup
4. `tests/fixtures/users.ts` - Test user data
5. `tests/unit/middleware/auth.test.ts` - Middleware unit tests
6. `tests/component/pages/bracket.test.ts` - Bracket page tests
7. `tests/component/pages/profile-setup.test.ts` - Profile setup tests
8. `tests/integration/flows/protected-routes.test.ts` - Navigation flow tests
9. `tests/integration/flows/session-expiry.test.ts` - Session expiry tests
10. `tests/integration/flows/redirect-preservation.test.ts` - Redirect tests
