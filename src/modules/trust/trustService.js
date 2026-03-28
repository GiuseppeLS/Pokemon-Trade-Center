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
