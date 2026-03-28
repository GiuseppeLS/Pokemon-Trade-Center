# Pokémon Trade Center (MVP Backend)

Coordination platform for Pokémon trades between players.

## Scope
This project supports matchmaking, validation, reporting, and trust scoring.
It does **not** implement Nintendo DS networking protocols or replace WFC servers.

## Setup
1. Copy `.env.example` to `.env`
2. `npm install`
3. `psql "$DATABASE_URL" -f sql/schema.sql`
4. `npm run dev`
