# Bracket Editor

The bracket editor allows users to view and edit their NFL playoff bracket picks through a visual interface.

## ADDED Requirements

### Requirement: Display bracket structure

The bracket editor displays the complete NFL playoff bracket with all 13 games organized by round.

#### Scenario: User views bracket with seeded games

**Given** a user navigates to `/bracket/[id]` for their bracket
**When** the page loads
**Then** the bracket displays:
  - 6 Wild Card games (3 AFC, 3 NFC) with seeded matchups
  - 4 Divisional round slots showing #1 seeds and Wild Card winner placeholders
  - 2 Conference Championship slots
  - 1 Super Bowl slot
**And** each game shows home team and away team with team names

#### Scenario: User views bracket with existing picks

**Given** a user has previously made picks for their bracket
**When** they navigate to the bracket editor
**Then** their existing picks are loaded and displayed
**And** advanced teams appear in their correct next-round slots

---

### Requirement: Select game winners

Users can click on a team to select them as the winner of a game.

#### Scenario: User picks Wild Card winner

**Given** a user is viewing the bracket editor
**And** a Wild Card game shows "Texans vs Chargers"
**When** the user clicks on "Chargers"
**Then** the Chargers are highlighted as the selected winner
**And** the Chargers appear in the corresponding Divisional round slot

#### Scenario: User picks through to Super Bowl

**Given** a user has made all Wild Card picks
**And** all Divisional picks
**And** both Conference Championship picks
**When** the user selects an AFC Conference Champion and NFC Conference Champion
**Then** both teams appear in the Super Bowl matchup
**And** the user can select the Super Bowl winner

---

### Requirement: Cascade pick changes

When a user changes an earlier-round pick, downstream picks involving the original winner are cleared.

#### Scenario: Changing Wild Card pick clears Divisional advancement

**Given** a user picked "Chiefs" to beat "Texans" in Wild Card
**And** the Chiefs advanced to Divisional and were picked to win
**When** the user changes their Wild Card pick to "Texans"
**Then** "Chiefs" is removed from the Divisional slot
**And** the Divisional pick involving Chiefs is cleared
**And** "Texans" now appears in the Divisional slot

#### Scenario: Changing Divisional pick clears Conference and Super Bowl

**Given** a user picked "Bills" to win their Divisional game
**And** Bills were picked in Conference Championship
**And** Bills were picked to win Super Bowl
**When** the user changes the Divisional pick to another team
**Then** the Conference Championship pick is cleared
**And** the Super Bowl picks involving Bills are cleared

---

### Requirement: Enter tiebreaker predictions

Users must enter Super Bowl total points and total yards predictions.

#### Scenario: User enters tiebreaker values

**Given** a user is viewing the bracket editor
**When** they scroll to the tiebreaker section
**Then** they see numeric inputs for:
  - "Super Bowl Total Points"
  - "Super Bowl Total Yards"
**And** both inputs accept positive integers

#### Scenario: Tiebreaker validation

**Given** a user has filled out all bracket picks
**When** they attempt to save with empty tiebreaker fields
**Then** validation messages appear on both tiebreaker inputs
**And** the bracket is still saved as draft (picks only)

---

### Requirement: Save bracket picks

Picks are saved to the database, allowing users to return and continue editing.

#### Scenario: Auto-save on pick change

**Given** a user makes a pick in the bracket editor
**When** 2 seconds pass without additional changes
**Then** the picks are automatically saved to the database
**And** a subtle "Saved" indicator appears

#### Scenario: Manual save via button

**Given** a user has unsaved changes
**When** they click the "Save" button
**Then** all picks and tiebreaker values are saved immediately
**And** the save button shows a loading state during save

#### Scenario: Load existing picks on return

**Given** a user previously saved picks for a bracket
**When** they navigate back to that bracket's editor
**Then** all their saved picks are loaded
**And** the bracket displays in the same state they left it

---

### Requirement: Read-only mode for paid brackets

Paid brackets cannot be edited.

#### Scenario: Viewing paid bracket

**Given** a user navigates to a bracket with `payment_status = 'paid'`
**When** the page loads
**Then** all picks are displayed but not interactive
**And** team selection is disabled
**And** tiebreaker inputs are disabled
**And** a "Paid - Locked" badge is displayed

#### Scenario: Attempting to edit paid bracket

**Given** a user is viewing their paid bracket
**When** they click on any team
**Then** nothing happens (no pick change)
**And** optionally a toast indicates the bracket is locked

---

### Requirement: Handle pool lock time

After the pool's `locks_at` time, unpaid brackets become read-only.

#### Scenario: Bracket locked after deadline

**Given** the current time is after the pool's `locks_at` timestamp
**And** a user has an unpaid bracket
**When** they navigate to the bracket editor
**Then** the bracket displays in read-only mode
**And** a message indicates "Picks are locked - deadline passed"

---

### Requirement: Delete unpaid bracket

Users can delete brackets they haven't paid for.

#### Scenario: Delete bracket from editor

**Given** a user is viewing their unpaid bracket
**When** they click "Delete Bracket"
**Then** a confirmation dialog appears
**And** confirming deletes the bracket and all associated picks
**And** the user is redirected to `/bracket`

#### Scenario: Cannot delete paid bracket

**Given** a user is viewing their paid bracket
**Then** no delete option is available
