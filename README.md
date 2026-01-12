# 🏈 Homefield

NFL Playoff Bracket Pool for friends. Fill out your bracket, pay your entry, compete for glory.

## Tech Stack

- **Framework**: Nuxt 4.2
- **UI**: NuxtUI v4 + Tailwind CSS v4
- **Database**: Supabase (Postgres + Auth)
- **Payments**: PayPal JS SDK (PayPal + Venmo)
- **Deployment**: Vercel

## Getting Started

### Prerequisites

- Node.js 18+
- npm
- Supabase account
- PayPal Developer account (for payments)

### Setup

1. **Clone and install dependencies**

```bash
cd homefield
npm install
```

2. **Set up Supabase**

- Create a new Supabase project
- Run the migrations in `supabase/migrations/` in order
- Copy your project URL and anon key

3. **Configure environment variables**

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
PAYPAL_CLIENT_ID=your-paypal-client-id
PAYPAL_CLIENT_SECRET=your-paypal-client-secret
```

4. **Run the development server**

```bash
npm run dev
```

Visit `http://localhost:3000`

## Project Structure

```
homefield/
├── app/
│   ├── pages/           # Route pages
│   ├── components/      # Vue components
│   ├── layouts/         # Page layouts
│   ├── composables/     # Shared composables
│   └── middleware/      # Route middleware
├── server/
│   ├── api/             # API routes
│   └── utils/           # Server utilities
├── supabase/
│   └── migrations/      # SQL migrations
├── public/              # Static assets
└── assets/
    └── css/             # Global styles
```

## Scoring

| Round | Points |
|-------|--------|
| Wild Card | 1 pt |
| Divisional | 2 pts |
| Conference | 4 pts |
| Super Bowl | 8 pts |

**Maximum possible score: 30 points**

### Tiebreakers

1. Closest to actual Super Bowl total points
2. Closest to actual Super Bowl total yards

## Features

- [x] Magic link authentication
- [x] Profile setup
- [x] Bracket list view
- [ ] Visual bracket editor
- [ ] Cascading pick logic
- [ ] Tiebreaker inputs
- [ ] PayPal/Venmo checkout
- [ ] Leaderboard with scoring
- [ ] Admin panel
- [ ] ESPN API integration

## License

MIT
