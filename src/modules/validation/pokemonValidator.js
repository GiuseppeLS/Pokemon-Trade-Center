import { NATURES, POKEMON_RULES } from "./data.js";

const STATS = ["hp", "attack", "defense", "sp_attack", "sp_defense", "speed"];

function hasPerfectIvs(ivs) {
  return STATS.every((key) => ivs[key] === 31);
}

function isRareCombination(pokemon) {
  return pokemon.is_shiny && pokemon.level <= 5;
}

export function validatePokemon(input) {
  const notes = [];
  const speciesRules = POKEMON_RULES[input.species];

  if (!speciesRules) return { legalityStatus: "illegal", suspicionScore: 100, notes: ["Unsupported species for MVP ruleset"] };
  if (!Array.isArray(input.moves) || input.moves.length !== 4) return { legalityStatus: "illegal", suspicionScore: 100, notes: ["Moves must include exactly 4 entries"] };
  if (!speciesRules.abilities.includes(input.ability)) return { legalityStatus: "illegal", suspicionScore: 100, notes: ["Invalid ability for species"] };
  if (input.level < speciesRules.minLevel || input.level > speciesRules.maxLevel) return { legalityStatus: "illegal", suspicionScore: 100, notes: ["Impossible level for species/evolution stage"] };

  for (const move of input.moves) {
    if (!speciesRules.legalMoves.includes(move)) return { legalityStatus: "illegal", suspicionScore: 100, notes: [`Illegal move detected: ${move}`] };
  }

  if (!NATURES.includes(input.nature)) return { legalityStatus: "illegal", suspicionScore: 100, notes: ["Unknown nature"] };

  let suspicionScore = 0;
  if (hasPerfectIvs(input.ivs)) { suspicionScore += 35; notes.push("Perfect IV spread detected"); }
  if (isRareCombination(input)) { suspicionScore += 30; notes.push("Rare shiny low-level combination"); }
  if (input.is_shiny && input.is_legendary) { suspicionScore += 35; notes.push("Shiny + legendary combination flagged"); }

  return {
    legalityStatus: suspicionScore >= 50 ? "suspicious" : "valid",
    suspicionScore: Math.min(100, suspicionScore),
    notes
  };
}
