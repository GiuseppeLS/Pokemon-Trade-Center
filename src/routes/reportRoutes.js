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
