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
