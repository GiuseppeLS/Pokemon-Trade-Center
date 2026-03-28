$ErrorActionPreference = "Stop"
Set-Location "D:\PokemonTradeCenter\PokemonTradeCenter"

New-Item -ItemType Directory -Force -Path `
  "src\modules\auth", `
  "src\modules\matching", `
  "src\modules\pokemon", `
  "src\modules\reports", `
  "src\modules\trades", `
  "src\modules\trust", `
  "src\modules\validation", `
  "src\routes" | Out-Null

@'
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { env } from "../../config/env.js";
import { query } from "../../db/pool.js";

export async function register({ username, email, password }) {
  const passwordHash = await bcrypt.hash(password, 10);
  const { rows } = await query(
    `INSERT INTO users (username, email, password_hash)
     VALUES ($1, $2, $3)
     RETURNING id, username, email, trust_score, created_at`,
    [username, email, passwordHash]
  );
  return rows[0];
}

export async function login({ email, password }) {
  const { rows } = await query(
    "SELECT id, username, email, password_hash, trust_score FROM users WHERE email = $1",
    [email]
  );
  const user = rows[0];
  if (!user) return null;

  const validPassword = await bcrypt.compare(password, user.password_hash);
  if (!validPassword) return null;

  const token = jwt.sign({ sub: user.id, username: user.username }, env.jwtSecret, { expiresIn: "7d" });

  return {
    token,
    user: { id: user.id, username: user.username, email: user.email, trustScore: user.trust_score }
  };
}
'@ | Set-Content -Encoding UTF8 "src\modules\auth\authService.js"

@'
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
'@ | Set-Content -Encoding UTF8 "src\modules\matching\matchingService.js"

@'
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
'@ | Set-Content -Encoding UTF8 "src\modules\pokemon\pokemonService.js"

@'
import { query } from "../../db/pool.js";
import { recalculateTrustScore } from "../trust/trustService.js";

export async function createReport(reporterUserId, { reportedUserId, tradeMatchId, reason, details }) {
  const { rows } = await query(
    `INSERT INTO reports (reporter_user_id, reported_user_id, trade_match_id, reason, details)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [reporterUserId, reportedUserId, tradeMatchId ?? null, reason, details ?? null]
  );

  await query("UPDATE users SET reports_count = reports_count + 1, updated_at = NOW() WHERE id = $1", [reportedUserId]);
  await recalculateTrustScore(reportedUserId);

  return rows[0];
}
'@ | Set-Content -Encoding UTF8 "src\modules\reports\reportService.js"

@'
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
'@ | Set-Content -Encoding UTF8 "src\modules\trades\tradeService.js"

@'
import { query } from "../../db/pool.js";

export async function recalculateTrustScore(userId) {
  const result = await query(
    `SELECT
      COALESCE(AVG(CASE WHEN legality_status = 'valid' THEN 100 WHEN legality_status = 'suspicious' THEN 50 ELSE 0 END), 50) AS validity_score,
      COALESCE(MAX(u.completed_trades_count), 0) AS completed_trades,
      COALESCE(MAX(u.reports_count), 0) AS reports_count
     FROM users u
     LEFT JOIN pokemon p ON p.owner_id = u.id
     WHERE u.id = $1
     GROUP BY u.id`,
    [userId]
  );

  if (!result.rows[0]) return null;

  const validityScore = Number(result.rows[0].validity_score);
  const completedTrades = Number(result.rows[0].completed_trades);
  const reportsCount = Number(result.rows[0].reports_count);

  const rawScore =
    validityScore * 0.6 +
    Math.min(100, completedTrades * 5) * 0.3 -
    Math.min(50, reportsCount * 10) * 0.1;

  const trustScore = Math.max(0, Math.min(100, Math.round(rawScore)));

  await query("UPDATE users SET trust_score = $2, updated_at = NOW() WHERE id = $1", [userId, trustScore]);
  return trustScore;
}
'@ | Set-Content -Encoding UTF8 "src\modules\trust\trustService.js"

@'
export const POKEMON_RULES = {
  Pikachu: { abilities: ["Static", "Lightning Rod"], minLevel: 1, maxLevel: 100, legalMoves: ["Thunderbolt", "Quick Attack", "Volt Tackle", "Iron Tail"] },
  Charmander: { abilities: ["Blaze", "Solar Power"], minLevel: 1, maxLevel: 100, legalMoves: ["Flamethrower", "Scratch", "Dragon Claw", "Fire Blast"] },
  Garchomp: { abilities: ["Sand Veil", "Rough Skin"], minLevel: 48, maxLevel: 100, legalMoves: ["Earthquake", "Dragon Claw", "Stone Edge", "Crunch"] },
  Reshiram: { abilities: ["Turboblaze"], minLevel: 50, maxLevel: 100, legalMoves: ["Blue Flare", "Dragon Breath", "Fusion Flare", "Extrasensory"] }
};

export const NATURES = [
  "Hardy","Lonely","Brave","Adamant","Naughty","Bold","Docile","Relaxed","Impish","Lax",
  "Timid","Hasty","Serious","Jolly","Naive","Modest","Mild","Quiet","Bashful","Rash",
  "Calm","Gentle","Sassy","Careful","Quirky"
];
'@ | Set-Content -Encoding UTF8 "src\modules\validation\data.js"

@'
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
'@ | Set-Content -Encoding UTF8 "src\modules\validation\pokemonValidator.js"

@'
import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { env } from "../config/env.js";
import { login, register } from "../modules/auth/authService.js";

export const authRouter = Router();

function internalErrorPayload(message, error) {
  if (env.nodeEnv === "development") {
    return { error: message, code: error?.code, detail: error?.message };
  }
  return { error: message };
}

authRouter.post("/register", async (req, res) => {
  try {
    const { username, email, password } = req.body ?? {};
    if (!username || !email || !password) return res.status(400).json({ error: "username, email, and password are required" });
    const user = await register({ username, email, password });
    return res.status(201).json(user);
  } catch (error) {
    if (error?.code === "23505") return res.status(409).json({ error: "Username or email already exists" });
    console.error("Register error:", error);
    return res.status(500).json(internalErrorPayload("Failed to register user", error));
  }
});

authRouter.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) return res.status(400).json({ error: "email and password are required" });
    const result = await login({ email, password });
    if (!result) return res.status(401).json({ error: "Invalid credentials" });
    return res.json(result);
  } catch (error) {
    console.error("Login error:", error);
    return res.status(500).json(internalErrorPayload("Failed to login", error));
  }
});

authRouter.get("/me", requireAuth, async (req, res) => {
  return res.json({ id: req.user.sub, username: req.user.username });
});
'@ | Set-Content -Encoding UTF8 "src\routes\authRoutes.js"

@'
import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { findAndCreateMatch } from "../modules/matching/matchingService.js";

export const matchRouter = Router();

matchRouter.post("/", requireAuth, async (_req, res) => {
  try {
    const match = await findAndCreateMatch();
    if (!match) return res.status(200).json({ message: "No compatible open trades found" });
    return res.status(201).json(match);
  } catch {
    return res.status(500).json({ error: "Failed to run matching engine" });
  }
});
'@ | Set-Content -Encoding UTF8 "src\routes\matchRoutes.js"

@'
import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { getPokemonById, uploadPokemon } from "../modules/pokemon/pokemonService.js";

export const pokemonRouter = Router();

pokemonRouter.post("/upload", requireAuth, async (req, res) => {
  try {
    const pokemon = await uploadPokemon(req.user.sub, req.body);
    return res.status(201).json(pokemon);
  } catch {
    return res.status(500).json({ error: "Failed to upload pokemon" });
  }
});

pokemonRouter.get("/:id", async (req, res) => {
  const pokemon = await getPokemonById(req.params.id);
  if (!pokemon) return res.status(404).json({ error: "Pokemon not found" });
  return res.json(pokemon);
});
'@ | Set-Content -Encoding UTF8 "src\routes\pokemonRoutes.js"

@'
import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { createReport } from "../modules/reports/reportService.js";

export const reportRouter = Router();

reportRouter.post("/", requireAuth, async (req, res) => {
  const { reportedUserId, tradeMatchId, reason, details } = req.body;
  if (!reportedUserId || !reason) return res.status(400).json({ error: "reportedUserId and reason are required" });

  try {
    const report = await createReport(req.user.sub, { reportedUserId, tradeMatchId, reason, details });
    return res.status(201).json(report);
  } catch {
    return res.status(500).json({ error: "Failed to create report" });
  }
});
'@ | Set-Content -Encoding UTF8 "src\routes\reportRoutes.js"

@'
import { Router } from "express";
import { requireAuth } from "../middleware/auth.js";
import { createTrade, listTrades } from "../modules/trades/tradeService.js";

export const tradeRouter = Router();

tradeRouter.post("/", requireAuth, async (req, res) => {
  const { offeredPokemonId, desiredCriteria } = req.body;
  if (!offeredPokemonId || !desiredCriteria) return res.status(400).json({ error: "offeredPokemonId and desiredCriteria are required" });

  try {
    const trade = await createTrade(req.user.sub, offeredPokemonId, desiredCriteria);
    return res.status(201).json(trade);
  } catch {
    return res.status(500).json({ error: "Failed to create trade" });
  }
});

tradeRouter.get("/", async (_req, res) => {
  const trades = await listTrades();
  return res.json(trades);
});
'@ | Set-Content -Encoding UTF8 "src\routes\tradeRoutes.js"

@'
import express from "express";
import { env } from "./config/env.js";
import { authRouter } from "./routes/authRoutes.js";
import { matchRouter } from "./routes/matchRoutes.js";
import { pokemonRouter } from "./routes/pokemonRoutes.js";
import { reportRouter } from "./routes/reportRoutes.js";
import { tradeRouter } from "./routes/tradeRoutes.js";

const app = express();
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/auth", authRouter);
app.use("/pokemon", pokemonRouter);
app.use("/trades", tradeRouter);
app.use("/match", matchRouter);
app.use("/report", reportRouter);

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

app.listen(env.port, () => {
  console.log("Pokemon Trade Center API listening on port " + env.port);
});
'@ | Set-Content -Encoding UTF8 "src\server.js"

Write-Host "DONE: files recreated."