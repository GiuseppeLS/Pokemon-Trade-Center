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
