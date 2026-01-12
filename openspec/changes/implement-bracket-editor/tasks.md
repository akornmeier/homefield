# Tasks: Implement Bracket Editor

## Phase 1: Core Components (Foundation)

### 1.1 Create useBracketPicks composable
- [ ] Create `/app/composables/useBracketPicks.ts`
- [ ] Implement reactive state for picks Map<game_id, team>
- [ ] Implement tiebreaker state (totalPoints, totalYards)
- [ ] Add computed properties for validation (isComplete, isDirty)
- [ ] Export pick/unpick methods

**Verify**: Unit test composable with mock data

### 1.2 Create BracketTeam component
- [ ] Create `/app/components/BracketTeam.vue`
- [ ] Props: teamName, isSelected, isDisabled, isWinner (for results)
- [ ] Emit click event for selection
- [ ] Style: highlight selected, dim disabled, green/red for correct/incorrect

**Verify**: Storybook story or visual test showing all states

### 1.3 Create BracketGame component
- [ ] Create `/app/components/BracketGame.vue`
- [ ] Props: game (id, homeTeam, awayTeam, round), selectedTeam, disabled
- [ ] Render two BracketTeam components
- [ ] Emit `pick` event with (gameId, team)
- [ ] Show round label and game status

**Verify**: Component renders matchup, emits pick on team click

---

## Phase 2: Bracket Layout

### 2.1 Create BracketEditor component
- [ ] Create `/app/components/BracketEditor.vue`
- [ ] Props: games (all 13), picks, readonly
- [ ] Organize games into columns by round (WC → DIV → CC → SB → CC → DIV → WC)
- [ ] Implement bracket connector lines with CSS/SVG
- [ ] Responsive layout: horizontal on desktop, vertical stack on mobile

**Verify**: Visual layout matches expected bracket structure

### 2.2 Implement cascading matchup computation
- [ ] Add `computeMatchups` function in composable
- [ ] Wild Card: Use seeded games directly
- [ ] Divisional: Slot #1 seed + highest remaining WC winner vs lower WC winners
- [ ] Conference: Winners of Divisional games
- [ ] Super Bowl: AFC champ vs NFC champ
- [ ] Handle empty slots (show "TBD" or placeholder)

**Verify**: Picking through rounds populates correct matchups

### 2.3 Implement cascade clearing
- [ ] Add `clearDownstreamPicks` function
- [ ] When pick changes, find all games where old winner would play
- [ ] Remove picks for those games recursively
- [ ] Trigger UI update

**Verify**: Changing WC pick clears related DIV, CC, SB picks

---

## Phase 3: Tiebreakers & Saving

### 3.1 Create TiebreakerInputs component
- [ ] Create `/app/components/TiebreakerInputs.vue`
- [ ] Two numeric inputs: Total Points, Total Yards
- [ ] Props: values, disabled, errors
- [ ] Emit update events on change
- [ ] Validate positive integers

**Verify**: Inputs accept numbers, show validation errors

### 3.2 Implement pick persistence
- [ ] Add `savePicks` function to composable
- [ ] Upsert picks to Supabase (batch operation)
- [ ] Handle optimistic UI updates
- [ ] Add error handling with retry

**Verify**: Picks persist after page reload

### 3.3 Implement auto-save with debounce
- [ ] Add 2-second debounce on pick changes
- [ ] Show "Saving..." indicator during save
- [ ] Show "Saved" confirmation after success
- [ ] Queue changes during save operation

**Verify**: Changes auto-save after 2s idle, indicator shows status

---

## Phase 4: Page Integration

### 4.1 Create bracket editor page
- [ ] Create `/app/pages/bracket/[id].vue`
- [ ] Fetch bracket by ID (verify ownership)
- [ ] Fetch all games for current season
- [ ] Fetch existing picks for bracket
- [ ] Handle 404 for invalid bracket ID

**Verify**: Page loads bracket data correctly

### 4.2 Integrate components on page
- [ ] Wire BracketEditor with fetched data
- [ ] Wire TiebreakerInputs with tiebreaker state
- [ ] Add Save button with loading state
- [ ] Add "Back to Brackets" navigation

**Verify**: Full editing flow works end-to-end

### 4.3 Implement read-only mode
- [ ] Check `payment_status` on load
- [ ] Check pool `locks_at` timestamp
- [ ] Pass `readonly` prop when locked
- [ ] Show appropriate status badges/messages

**Verify**: Paid bracket shows as locked, no interactions work

---

## Phase 5: Edge Cases & Polish

### 5.1 Add bracket deletion
- [ ] Add "Delete Bracket" button (unpaid only)
- [ ] Confirmation modal before delete
- [ ] Delete bracket and cascade to picks
- [ ] Redirect to `/bracket` after delete

**Verify**: Unpaid bracket can be deleted, paid cannot

### 5.2 Handle individual game locks
- [ ] Compare `starts_at` to current time per game
- [ ] Disable pick for games that have started
- [ ] Show "Game Started" indicator

**Verify**: Cannot pick games after their start time

### 5.3 Add loading and error states
- [ ] Skeleton loader while fetching
- [ ] Error boundary for failed loads
- [ ] Toast notifications for save errors
- [ ] Offline detection with warning

**Verify**: Graceful handling of all error scenarios

### 5.4 Mobile responsiveness
- [ ] Test on 375px viewport
- [ ] Ensure all teams are tappable
- [ ] Scrollable bracket area
- [ ] Sticky save button on mobile

**Verify**: Full flow completable on mobile device

---

## Dependencies

- Phase 2 depends on Phase 1 (components use composable)
- Phase 3 depends on Phase 1 (saving uses composable)
- Phase 4 depends on Phases 1-3 (page integrates all)
- Phase 5 can start after Phase 4.1

## Parallelizable Work

- Tasks 1.2 and 1.3 can run in parallel
- Tasks 3.1 and 3.2 can run in parallel
- Tasks 5.1, 5.2, 5.3 can run in parallel after Phase 4
