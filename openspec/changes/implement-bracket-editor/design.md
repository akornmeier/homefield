# Design: Bracket Editor

## Overview

The bracket editor displays the NFL playoff bracket structure and allows users to select winners for each game. Selections cascade forward - picking a Wild Card winner advances that team to the Divisional round slot, and so on through the Super Bowl.

## Architecture

### Component Structure

```
/app/pages/bracket/[id].vue        # Page wrapper, data fetching
/app/components/
  BracketEditor.vue                # Main bracket layout component
  BracketGame.vue                  # Individual game matchup component
  BracketTeam.vue                  # Clickable team selection
  TiebreakerInputs.vue             # Super Bowl prediction inputs
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      Page: /bracket/[id]                     │
│  - Fetches bracket, games, existing picks from Supabase     │
│  - Provides data to BracketEditor via props                  │
│  - Handles save operations                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     BracketEditor.vue                        │
│  - Manages local pick state (reactive Map<game_id, team>)   │
│  - Computes matchups for each round based on picks          │
│  - Emits pick changes to parent for saving                   │
└─────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
      BracketGame       BracketGame       TiebreakerInputs
      (Wild Card)       (Divisional)      (Super Bowl)
```

### Cascading Logic

When a user picks a winner:

1. **Record the pick** for that game_id
2. **Propagate forward**: If winner plays in next round, update that matchup's team slot
3. **Clear downstream**: If changing a pick, remove any downstream picks involving the old winner

Example cascade:
```
User picks Chiefs over Texans in Wild Card
  → Chiefs appear in Divisional matchup vs #1 seed
User later changes to Texans
  → Chiefs removed from Divisional slot
  → Any Conference/Super Bowl picks involving Chiefs are cleared
```

### State Management

Use a composable `useBracketPicks` to manage:

```typescript
interface BracketPicksState {
  picks: Map<string, string>           // game_id → picked_team
  tiebreakers: {
    totalPoints: number | null
    totalYards: number | null
  }
  isDirty: boolean
  isSubmitting: boolean
}
```

### Database Operations

**Load picks:**
```sql
SELECT game_id, picked_team, super_bowl_total_points, super_bowl_total_yards
FROM picks
WHERE bracket_id = $1
```

**Save picks (upsert):**
```sql
INSERT INTO picks (bracket_id, game_id, picked_team, super_bowl_total_points, super_bowl_total_yards)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (bracket_id, game_id)
DO UPDATE SET picked_team = EXCLUDED.picked_team,
              super_bowl_total_points = EXCLUDED.super_bowl_total_points,
              super_bowl_total_yards = EXCLUDED.super_bowl_total_yards
```

## Visual Layout

The bracket displays in tournament bracket format:

```
AFC Side                                    NFC Side
─────────────────────────────────────────────────────────
Wild Card    Divisional   Conf Champ   Super Bowl   Conf Champ   Divisional    Wild Card

[2v7] ─┐                                                                    ┌─ [2v7]
       ├─ [1 vs WC] ─┐                                          ┌─ [WC vs 1] ─┤
[3v6] ─┘             │                                          │             └─ [3v6]
                     ├─ [AFC Champ] ─┐          ┌─ [NFC Champ] ─┤
[4v5] ───── [WC vs WC] ─┘            │          │            └─ [WC vs WC] ───── [4v5]
                                     │          │
                                     └─ [SB] ───┘
```

On mobile: Vertical stack with clear round labels, scrollable.

## Edge Cases

1. **Paid bracket**: Read-only mode, no pick interactions
2. **Locked pool**: After `locks_at`, redirect to read-only view
3. **Game started**: Individual game locks when `starts_at` passes
4. **Incomplete picks**: Allow saving partial brackets, warn on checkout
5. **Network errors**: Optimistic UI with retry on save failure

## Trade-offs

### Option A: Client-side cascade logic (Chosen)
- Pros: Responsive UI, works offline, simpler server
- Cons: Logic duplicated if needed server-side

### Option B: Server-side cascade
- Pros: Single source of truth
- Cons: Latency on every pick, complex API

**Decision**: Client-side for responsiveness. Server validates on payment.

### Option C: Real-time sync with Supabase Realtime
- Deferred: Not needed for MVP. Single-user editing.
