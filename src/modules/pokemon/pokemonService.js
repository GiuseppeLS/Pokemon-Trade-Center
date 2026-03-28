import { query } from "../../db/pool.js";
import { validatePokemon } from "../validation/pokemonValidator.js";
import { recalculateTrustScore } from "../trust/trustService.js";

export async function uploadPokemon(userId, payload) {
  const validation = validatePokemon(payload);

  const { rows } = await query(
    `INSERT INTO pokemon (
      owner_id, species, level, moves, ability, ivs, evs, nature, trainer_info,
      origin_game, is_shiny, is_legendary, legality_status, suspicion_score, validation_notes, metadata
    )
    VALUES ($1, $2, $3, $4::jsonb, $5, $6::jsonb, $7::jsonb, $8, $9::jsonb, $10, $11, $12, $13::legality_status, $14, $15::jsonb, $16::jsonb)
    RETURNING *`,
    [
      userId, payload.species, payload.level,
      JSON.stringify(payload.moves), payload.ability,
      JSON.stringify(payload.ivs), JSON.stringify(payload.evs),
      payload.nature, JSON.stringify(payload.trainerInfo),
      payload.originGame, Boolean(payload.isShiny), Boolean(payload.isLegendary),
      validation.legalityStatus, validation.suspicionScore,
      JSON.stringify(validation.notes), JSON.stringify(payload.metadata || {})
    ]
  );

  await recalculateTrustScore(userId);
  return rows[0];
}

export async function getPokemonById(id) {
  const { rows } = await query("SELECT * FROM pokemon WHERE id = $1", [id]);
  return rows[0] ?? null;
}
