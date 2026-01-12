-- Seed data for Homefield
-- Run this after the schema migration

-- Create a default pool
insert into public.pools (id, name, invite_code, entry_fee, locks_at)
values (
  '00000000-0000-0000-0000-000000000001',
  'Homefield 2025',
  'HOMEFIELD2025',
  2000, -- $20.00
  '2026-01-11 13:00:00+00' -- Wild Card Saturday kickoff
);

-- Seed 2025-2026 NFL Playoff Games
-- Note: Update teams based on actual playoff seeding

-- Wild Card Round (6 games)
-- AFC Wild Card
insert into public.games (season_year, round, conference, home_team, away_team, home_seed, away_seed, starts_at)
values
  (2025, 'wild_card', 'AFC', 'Bills', 'Broncos', 2, 7, '2026-01-11 13:00:00+00'),
  (2025, 'wild_card', 'AFC', 'Ravens', 'Steelers', 3, 6, '2026-01-11 16:30:00+00'),
  (2025, 'wild_card', 'AFC', 'Texans', 'Chargers', 4, 5, '2026-01-11 20:00:00+00');

-- NFC Wild Card
insert into public.games (season_year, round, conference, home_team, away_team, home_seed, away_seed, starts_at)
values
  (2025, 'wild_card', 'NFC', 'Eagles', 'Packers', 2, 7, '2026-01-12 13:00:00+00'),
  (2025, 'wild_card', 'NFC', 'Buccaneers', 'Commanders', 3, 6, '2026-01-12 16:30:00+00'),
  (2025, 'wild_card', 'NFC', 'Rams', 'Vikings', 4, 5, '2026-01-13 20:00:00+00');

-- Divisional Round (4 games)
-- These matchups TBD based on Wild Card results, but we seed the structure
insert into public.games (season_year, round, conference, home_team, away_team, starts_at)
values
  (2025, 'divisional', 'AFC', 'Chiefs', 'TBD', '2026-01-18 16:30:00+00'),
  (2025, 'divisional', 'AFC', 'TBD', 'TBD', '2026-01-18 20:00:00+00'),
  (2025, 'divisional', 'NFC', 'Lions', 'TBD', '2026-01-19 15:00:00+00'),
  (2025, 'divisional', 'NFC', 'TBD', 'TBD', '2026-01-19 18:30:00+00');

-- Conference Championships (2 games)
insert into public.games (season_year, round, conference, home_team, away_team, starts_at)
values
  (2025, 'conference', 'AFC', 'TBD', 'TBD', '2026-01-26 15:00:00+00'),
  (2025, 'conference', 'NFC', 'TBD', 'TBD', '2026-01-26 18:30:00+00');

-- Super Bowl
insert into public.games (season_year, round, conference, home_team, away_team, starts_at)
values
  (2025, 'super_bowl', null, 'TBD', 'TBD', '2026-02-09 18:30:00+00');
