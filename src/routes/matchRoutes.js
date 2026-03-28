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
