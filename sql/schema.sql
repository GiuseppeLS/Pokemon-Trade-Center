CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'trade_status') THEN
    CREATE TYPE trade_status AS ENUM ('open', 'matched', 'completed', 'cancelled');
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'legality_status') THEN
    CREATE TYPE legality_status AS ENUM ('valid', 'suspicious', 'illegal');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username VARCHAR(32) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  trust_score SMALLINT NOT NULL DEFAULT 50 CHECK (trust_score BETWEEN 0 AND 100),
  completed_trades_count INTEGER NOT NULL DEFAULT 0,
  reports_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pokemon (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  species VARCHAR(64) NOT NULL,
  level SMALLINT NOT NULL CHECK (level BETWEEN 1 AND 100),
  moves JSONB NOT NULL,
  ability VARCHAR(64) NOT NULL,
  ivs JSONB NOT NULL,
  evs JSONB NOT NULL,
  nature VARCHAR(32) NOT NULL,
  trainer_info JSONB NOT NULL,
  origin_game VARCHAR(32) NOT NULL,
  is_shiny BOOLEAN NOT NULL DEFAULT FALSE,
  is_legendary BOOLEAN NOT NULL DEFAULT FALSE,
  legality_status legality_status NOT NULL,
  suspicion_score SMALLINT NOT NULL DEFAULT 0 CHECK (suspicion_score BETWEEN 0 AND 100),
  validation_notes JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  offered_pokemon_id UUID NOT NULL REFERENCES pokemon(id) ON DELETE CASCADE,
  desired_criteria JSONB NOT NULL,
  status trade_status NOT NULL DEFAULT 'open',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS trade_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trade_a_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  trade_b_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  user_a_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status trade_status NOT NULL DEFAULT 'matched',
  coordination_message TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  trade_match_id UUID REFERENCES trade_matches(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  details TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
