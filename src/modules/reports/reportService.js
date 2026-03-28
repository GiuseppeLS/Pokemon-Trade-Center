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
