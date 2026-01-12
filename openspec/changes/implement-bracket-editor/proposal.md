# Implement Bracket Editor

## Summary

Build the visual bracket editor interface that allows users to make playoff picks with cascading advancement logic, tiebreaker inputs, and draft saving.

## Motivation

The bracket editor is the core user experience of Homefield. Users currently cannot:
- View their bracket picks in a visual format
- Select winners for each playoff game
- Have winners automatically advance to the next round
- Enter Super Bowl tiebreaker predictions
- Save their picks as drafts

Without this feature, the application cannot fulfill its primary purpose.

## Scope

This change implements:
1. `/bracket/[id]` page with visual bracket interface
2. Cascading pick logic (winners advance to next round slots)
3. Pick clearing when earlier-round selections change
4. Tiebreaker inputs for Super Bowl total points and yards
5. Auto-save/manual save of picks to database
6. Read-only mode for paid brackets

## Out of Scope

- Payment integration (separate change)
- Leaderboard scoring display (separate change)
- Viewing other users' brackets (depends on leaderboard)
- Admin game results entry (separate change)

## User Stories Addressed

- US-007: Build bracket editor UI
- US-008: Add tiebreaker inputs to bracket
- US-009: Save bracket picks as draft

## Dependencies

- Existing database schema (picks, games, brackets tables)
- Existing authentication middleware
- Existing bracket list page (navigation source)
