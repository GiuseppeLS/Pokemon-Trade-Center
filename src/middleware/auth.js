import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
export function requireAuth(req, res, next) {
  const h = req.headers.authorization;
  if (!h?.startsWith("Bearer ")) return res.status(401).json({ error: "Unauthorized" });
  try { req.user = jwt.verify(h.slice(7), env.jwtSecret); return next(); }
  catch { return res.status(401).json({ error: "Invalid token" }); }
}
