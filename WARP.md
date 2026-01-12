# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Tooling & Commands

This is a Nuxt 4 app using Node 18+ with a pnpm workspace.

### Dependency installation

- Preferred: `pnpm install`
- Alternative (matches `README.md`): `npm install`

### Core scripts (from `package.json`)

- Start dev server: `pnpm dev` (or `npm run dev`)
- Production build: `pnpm build` (or `npm run build`)
- Static generation: `pnpm generate` (or `npm run generate`)
- Preview production build: `pnpm preview` (or `npm run preview`)
- Type checking (Vue + TS via Nuxt): `pnpm typecheck` (or `npm run typecheck`)

There are currently **no lint or test scripts** defined. Before trying to run tests or linting, check `package.json` and project config to see if a test runner or linter has been added.

### Environment configuration

Local development depends on the following environment variables (see `.env.example` as referenced in `README.md` and `nuxt.config.ts`):

- `SUPABASE_URL`, `SUPABASE_KEY` – Supabase project URL and anon key
- `PAYPAL_CLIENT_ID`, `PAYPAL_CLIENT_SECRET` – PayPal JS SDK credentials

Nuxt runtime config:

- Server-only: `runtimeConfig.paypalClientSecret`
- Public: `runtimeConfig.public.paypalClientId`

## High-Level Architecture

### Overview

Single Nuxt 4 application with:

- UI: Nuxt UI v4 + Tailwind CSS v4 via `assets/css/main.css`
- Auth + data: Supabase (Postgres + Row-Level Security)
- Payments: PayPal JS SDK (configuration present; UI/flows are still being built)

Key top-level directories:

- `app/` – Nuxt application (layouts, pages, middleware)
- `supabase/migrations/` – Database schema and seed data

The `server/` and other directories shown in `README.md` may represent future structure; they don't exist yet in the current tree.

### Nuxt application structure (`app/`)

#### App shell and layout

- `app/app.vue`
  - Wraps the app in `<UApp>` and renders `<NuxtLayout>`/`<NuxtPage>`.
- `app/layouts/default.vue`
  - Global shell with header, navigation, and main content.
  - Uses `useSupabaseUser()` to show different navigation for authenticated vs anonymous users.
    - Authenticated nav links: `/bracket` ("My Brackets"), `/leaderboard` (not yet implemented), and a "Sign Out" button.
    - Anonymous nav: "Sign In" button linking to `/login`.
  - `signOut()` uses `useSupabaseClient()` to call `supabase.auth.signOut()` and redirects to `/login`.

#### Auth middleware

- `app/middleware/auth.ts`
  - Global auth gate for protected pages.
  - Reads `useSupabaseUser()` and redirects unauthenticated users to `/login`.
  - Used via `definePageMeta({ middleware: 'auth' })` on protected routes (e.g. profile setup, brackets).

#### Key pages and flows

- Landing (`app/pages/index.vue`)
  - Marketing/overview page for the pool.
  - Shows entry fee, lock time, and a live countdown.
    - `entryFee` and `locksAt` are currently hard-coded and intended to be wired up to Supabase pool configuration.
  - Displays scoring rules consistent with `README.md` (1/2/4/8 points by round and tiebreakers).
  - CTA depends on auth state (`useSupabaseUser()`):
    - Authenticated: link to `/bracket`.
    - Anonymous: link to `/login`.

- Login & magic link flow (`app/pages/login.vue` + `app/pages/auth/callback.vue`)
  - `login.vue`:
    - Uses `zod` schema validation and Nuxt UI form components.
    - Calls `supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: <origin>/auth/callback } })`.
    - Shows a confirmation state once the email is sent and allows retry.
  - `auth/callback.vue`:
    - Uses `useSupabaseUser()` and `useSupabaseClient()`.
    - On mount, `watch(user, ...)` waits for Supabase to complete token exchange.
    - On first non-null user:
      - Fetches `public.users` by `id` and checks `first_name`/`last_name`.
      - If missing, redirects to `/profile/setup`; otherwise to `/bracket`.
    - Includes a 5-second fallback timeout that returns to `/login` if the user never resolves.

- Profile completion (`app/pages/profile/setup.vue`)
  - Protected by `middleware: 'auth'`.
  - Collects `firstName`/`lastName` with `zod` validation and Nuxt UI forms.
  - Uses `useSupabaseClient()` and `useSupabaseUser()`.
  - Upserts into `public.users`:
    - `id` from `auth.users` (via `user.value.id`)
    - `email`, `first_name`, `last_name`
  - On success, navigates to `/bracket`.

- Bracket list & payment staging (`app/pages/bracket/index.vue`)
  - Protected by `middleware: 'auth'`.
  - Uses `useSupabaseClient()`, `useSupabaseUser()`, and `useToast()`.
  - State:
    - `brackets`: list of the current user's brackets.
    - `unpaidBrackets`: computed subset where `payment_status !== 'paid'`.
    - `entryFee`: currently a hard-coded number (20); database stores cents.
  - Data loading:
    - `fetchBrackets()` queries `public.brackets` with `eq('user_id', user.id)` and sorts by `created_at` desc.
    - Each bracket is annotated with a `number` for display (reverse index in the current list).
  - Actions:
    - `createBracket()` inserts into `public.brackets` with:
      - `user_id` from `useSupabaseUser()`
      - `pool_id` hard-coded to the seeded pool ID from `002_seed_data.sql` (`00000000-0000-0000-0000-000000000001`)
      - `payment_status: 'unpaid'`
      - On success, navigates to `/bracket/<id>` (route not yet implemented in this tree).
    - `deleteBracket(id)` deletes by bracket ID and updates local state.
  - Checkout summary:
    - If there are unpaid brackets, shows a summary card and a link to `/checkout` (checkout route is not implemented yet).

Routes referenced but not yet present in `app/pages/` include `/bracket/[id]`, `/checkout`, and `/leaderboard`. If you add them, follow the existing patterns for auth (`middleware: 'auth'`), Supabase access, and UI components.

## Supabase Schema & Data Model

All SQL lives in `supabase/migrations/` and should be applied in order.

### Core tables

From `001_initial_schema.sql`:

- `public.users`
  - Extends `auth.users` with profile fields.
  - Columns: `id` (PK, references `auth.users`), `email`, `first_name`, `last_name`, `created_at`.
  - Trigger `handle_new_user()` inserts into `public.users` whenever a new `auth.users` row is created.

- `public.pools`
  - Represents a pool instance (e.g., a specific year’s playoff pool).
  - Key fields: `name`, `invite_code` (unique), `owner_id` (FK to `public.users`), `entry_fee` (integer cents), `locks_at` (deadline after which picks/brackets are locked), timestamps.

- `public.pool_members`
  - Many-to-many between `pools` and `users`.
  - Composite primary key `(pool_id, user_id)`.

- `public.brackets`
  - A single user’s bracket for a given pool.
  - Key fields: `user_id`, `pool_id`, optional `name`, `payment_status` (`unpaid`/`paid`/`refunded`), `payment_id`, `submitted_at`, `created_at`.

- `public.games`
  - Describes all playoff games.
  - Fields include: `season_year`, `round` (`wild_card`/`divisional`/`conference`/`super_bowl`), `home_team`, `away_team`, optional seeds and conference, result fields (`winner`, `actual_total_points`, `actual_total_yards`), scheduling info.

- `public.picks`
  - User picks per game, tied to a bracket.
  - Fields: `bracket_id`, `game_id`, `picked_team`, tiebreaker fields (`super_bowl_total_points`, `super_bowl_total_yards`), timestamps.
  - Unique constraint on `(bracket_id, game_id)`.

Indexes are defined for common access paths (e.g., by user, pool, bracket, round).

### Row Level Security (RLS)

RLS is enabled on all core tables (`users`, `pools`, `pool_members`, `brackets`, `games`, `picks`). Policies are designed around:

- `users`
  - Anyone can select.
  - Users can insert/update only their own row (`auth.uid() = id`).
- `pools`
  - Publicly readable.
- `pool_members`
  - Publicly readable; inserts allowed when `auth.uid() = user_id`.
- `brackets`
  - Users can select their own brackets.
  - After the pool’s `locks_at` time and for `payment_status = 'paid'`, other users can view those brackets.
  - Insert/update/delete limited to the owning user and only while brackets are unpaid.
- `games`
  - Publicly readable.
- `picks`
  - Users can select picks for brackets they own.
  - After lock, users can view picks for paid brackets in locked pools.
  - Insert/update/delete limited to picks on unpaid brackets owned by `auth.uid()`.

When building new server or client logic, keep these policies in mind: many Supabase queries will silently return empty sets if the policy conditions are not satisfied.

### Seed data

From `002_seed_data.sql`:

- A default pool is inserted with ID `00000000-0000-0000-0000-000000000001`, invite code `HOMEFIELD2025`, entry fee 2000 (representing `$20.00`), and a fixed `locks_at` timestamp.
- Playoff game skeletons are seeded for the 2025 season across Wild Card, Divisional, Conference, and Super Bowl rounds. Several matchups use `TBD` placeholders to be filled once seeding is known.

The front-end currently hard-codes `entryFee = 20` and a `locksAt` date; these should eventually derive from this seeded pool instead of duplicating values.

## Notable Conventions & Considerations

- **Currency representation**: The database stores `entry_fee` as integer cents, while UI components currently treat entry fees as whole-dollar numbers. Be explicit about conversions when wiring up pool settings and payment amounts.
- **Hard-coded IDs and times**:
  - `app/pages/bracket/index.vue` uses a hard-coded `pool_id` corresponding to the seeded pool.
  - `app/pages/index.vue` hard-codes `locksAt` to a specific date. Both should be sourced from Supabase when pool management features are implemented.
- **Auth-dependent routing**:
  - Use the `auth` middleware for any page that assumes an authenticated user.
  - `auth/callback` is the central post-login router: profile completeness is enforced there before a user accesses brackets.
- **Feature roadmap alignment**:
  - `README.md` lists future features like a visual bracket editor, checkout, leaderboard, admin panel, and ESPN API integration. The current code implements only a subset (auth, profile setup, basic bracket list, countdown, schema). When adding these features, follow the existing patterns for Supabase access, RLS, and Nuxt UI components.