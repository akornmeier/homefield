-- Homefield: NFL Playoff Bracket Pool Schema
-- Run this in your Supabase SQL Editor

-- gen_random_uuid() is built into PostgreSQL 13+ (used by Supabase)

-- Users table (extends auth.users)
create table public.users (
  id uuid references auth.users on delete cascade primary key,
  email text not null,
  first_name text,
  last_name text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Pools table
create table public.pools (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  invite_code text unique not null,
  owner_id uuid references public.users(id) on delete set null,
  entry_fee integer not null default 2000, -- cents
  locks_at timestamp with time zone not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Pool members
create table public.pool_members (
  pool_id uuid references public.pools(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  joined_at timestamp with time zone default timezone('utc'::text, now()) not null,
  primary key (pool_id, user_id)
);

-- Brackets
create table public.brackets (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.users(id) on delete cascade not null,
  pool_id uuid references public.pools(id) on delete cascade not null,
  name text,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'paid', 'refunded')),
  payment_id text,
  submitted_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Games
create table public.games (
  id uuid default gen_random_uuid() primary key,
  season_year integer not null,
  round text not null check (round in ('wild_card', 'divisional', 'conference', 'super_bowl')),
  home_team text not null,
  away_team text not null,
  home_seed integer,
  away_seed integer,
  conference text check (conference in ('AFC', 'NFC', null)),
  winner text,
  starts_at timestamp with time zone,
  espn_game_id text,
  actual_total_points integer,
  actual_total_yards integer,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Picks
create table public.picks (
  id uuid default gen_random_uuid() primary key,
  bracket_id uuid references public.brackets(id) on delete cascade not null,
  game_id uuid references public.games(id) on delete cascade not null,
  picked_team text not null,
  super_bowl_total_points integer,
  super_bowl_total_yards integer,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (bracket_id, game_id)
);

-- Indexes
create index idx_brackets_user_id on public.brackets(user_id);
create index idx_brackets_pool_id on public.brackets(pool_id);
create index idx_picks_bracket_id on public.picks(bracket_id);
create index idx_games_round on public.games(round);
create index idx_pool_members_user_id on public.pool_members(user_id);

-- Enable Row Level Security
alter table public.users enable row level security;
alter table public.pools enable row level security;
alter table public.pool_members enable row level security;
alter table public.brackets enable row level security;
alter table public.games enable row level security;
alter table public.picks enable row level security;

-- RLS Policies

-- Users: users can read all, update own
create policy "Users can view all users"
  on public.users for select
  using (true);

create policy "Users can update own profile"
  on public.users for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.users for insert
  with check (auth.uid() = id);

-- Pools: anyone can read
create policy "Pools are viewable by everyone"
  on public.pools for select
  using (true);

-- Pool members: members can read, users can join
create policy "Pool members can view members"
  on public.pool_members for select
  using (true);

create policy "Users can join pools"
  on public.pool_members for insert
  with check (auth.uid() = user_id);

-- Brackets: users can CRUD own, view others after lock
create policy "Users can view own brackets"
  on public.brackets for select
  using (auth.uid() = user_id);

create policy "Users can view paid brackets after lock"
  on public.brackets for select
  using (
    payment_status = 'paid' 
    and exists (
      select 1 from public.pools 
      where pools.id = brackets.pool_id 
      and pools.locks_at < now()
    )
  );

create policy "Users can create own brackets"
  on public.brackets for insert
  with check (auth.uid() = user_id);

create policy "Users can update own unpaid brackets"
  on public.brackets for update
  using (auth.uid() = user_id and payment_status = 'unpaid');

create policy "Users can delete own unpaid brackets"
  on public.brackets for delete
  using (auth.uid() = user_id and payment_status = 'unpaid');

-- Games: anyone can read
create policy "Games are viewable by everyone"
  on public.games for select
  using (true);

-- Picks: users can CRUD own, view others after lock
create policy "Users can view own picks"
  on public.picks for select
  using (
    exists (
      select 1 from public.brackets 
      where brackets.id = picks.bracket_id 
      and brackets.user_id = auth.uid()
    )
  );

create policy "Users can view picks after lock"
  on public.picks for select
  using (
    exists (
      select 1 from public.brackets b
      join public.pools p on p.id = b.pool_id
      where b.id = picks.bracket_id 
      and b.payment_status = 'paid'
      and p.locks_at < now()
    )
  );

create policy "Users can insert picks for own unpaid brackets"
  on public.picks for insert
  with check (
    exists (
      select 1 from public.brackets 
      where brackets.id = picks.bracket_id 
      and brackets.user_id = auth.uid()
      and brackets.payment_status = 'unpaid'
    )
  );

create policy "Users can update picks for own unpaid brackets"
  on public.picks for update
  using (
    exists (
      select 1 from public.brackets 
      where brackets.id = picks.bracket_id 
      and brackets.user_id = auth.uid()
      and brackets.payment_status = 'unpaid'
    )
  );

create policy "Users can delete picks for own unpaid brackets"
  on public.picks for delete
  using (
    exists (
      select 1 from public.brackets 
      where brackets.id = picks.bracket_id 
      and brackets.user_id = auth.uid()
      and brackets.payment_status = 'unpaid'
    )
  );

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;

-- Trigger for new user signup
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
