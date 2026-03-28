import { query } from "../../db/pool.js";

export async function createTrade(userId, offeredPokemonId, desiredCriteria) {
  const { rows } = await query(
    `INSERT INTO trades (user_id, offered_pokemon_id, desired_criteria)
     VALUES ($1, $2, $3::jsonb)
     RETURNING *`,
    [userId, offeredPokemonId, JSON.stringify(desiredCriteria)]
  );

  return rows[0];
}

export async function listTrades() {
  const { rows } = await query(
    `SELECT t.*, p.species AS offered_species, p.level AS offered_level
     FROM trades t
     JOIN pokemon p ON p.id = t.offered_pokemon_id
     ORDER BY t.created_at DESC`
  );
  return rows;
}
