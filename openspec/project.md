# Homefield

NFL Playoff Bracket Pool - A web application for friends to fill out NFL playoff brackets, pay entry fees, and compete for the best score.

## Tech Stack

- **Framework**: Nuxt 4.2
- **UI**: NuxtUI v4 + Tailwind CSS v4
- **Database**: Supabase (PostgreSQL + Auth)
- **Payments**: PayPal JS SDK (PayPal + Venmo)
- **Deployment**: Vercel
- **Data Source**: ESPN unofficial API (manual fallback)

## Current State

The project has foundational infrastructure complete:

- Nuxt 4.2 project initialized with NuxtUI and Supabase
- Database schema fully defined with RLS policies
- Magic link authentication working
- Profile setup flow complete
- Landing page with pool info and countdown
- Bracket list page (view/create brackets)
- 2025-2026 playoff game data seeded

## Remaining Work

Priority features not yet implemented:

1. **Bracket Editor** - Visual bracket interface with cascading picks
2. **Checkout Flow** - PayPal payment integration
3. **Leaderboard** - Scoring calculation and standings
4. **Pool Join** - Invite code entry flow
5. **Admin Panel** - Pool management and game results entry

## Scoring System

- Wild Card correct pick: 1 point
- Divisional correct pick: 2 points
- Conference Championship correct pick: 4 points
- Super Bowl correct pick: 8 points
- Tiebreaker 1: Super Bowl total points prediction (closest wins)
- Tiebreaker 2: Super Bowl total yards prediction (closest wins)

## Database Tables

- `users` - User profiles (extends auth.users)
- `pools` - Pool configuration
- `pool_members` - Pool membership
- `brackets` - User brackets with payment status
- `games` - Playoff games with results
- `picks` - Individual game picks per bracket
