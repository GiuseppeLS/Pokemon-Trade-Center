import { query } from "../../db/pool.js";

function desiredMatchesPokemon(desiredCriteria, pokemon) {
  if (desiredCriteria.species && desiredCriteria.species !== pokemon.species) return false;
  if (desiredCriteria.minLevel && pokemon.level < desiredCriteria.minLevel) return false;
  if (desiredCriteria.ability && desiredCriteria.ability !== pokemon.ability) return false;
  if (desiredCriteria.legalityStatus && desiredCriteria.legalityStatus !== pokemon.legality_status) return false;
  return true;
}

export async function findAndCreateMatch() {
  const { rows: openTrades } = await query(`
    SELECT t.id, t.user_id, t.offered_pokemon_id, t.desired_criteria,
           p.species, p.level, p.ability, p.legality_status
    FROM trades t
    JOIN pokemon p ON p.id = t.offered_pokemon_id
    WHERE t.status = 'open'
    ORDER BY t.created_at ASC
  `);

  for (let i = 0; i < openTrades.length; i += 1) {
    const tradeA = openTrades[i];
    for (let j = i + 1; j < openTrades.length; j += 1) {
      const tradeB = openTrades[j];
      if (tradeA.user_id === tradeB.user_id) continue;

      const aWantsB = desiredMatchesPokemon(tradeA.desired_criteria, tradeB);
      const bWantsA = desiredMatchesPokemon(tradeB.desired_criteria, tradeA);
      if (!aWantsB || !bWantsA) continue;

      await query("BEGIN");
      try {
        await query("UPDATE trades SET status = 'matched', updated_at = NOW() WHERE id = ANY($1::uuid[])", [[tradeA.id, tradeB.id]]);
        const coordinationMessage = "Match found. Go online and trade with this user via WFC.";
        const { rows } = await query(
          `INSERT INTO trade_matches (trade_a_id, trade_b_id, user_a_id, user_b_id, status, coordination_message)
           VALUES ($1, $2, $3, $4, 'matched', $5)
           RETURNING *`,
          [tradeA.id, tradeB.id, tradeA.user_id, tradeB.user_id, coordinationMessage]
        );
        await query("COMMIT");
        return rows[0];
      } catch (error) {
        await query("ROLLBACK");
        throw error;
      }
    }
  }

  return null;
}
