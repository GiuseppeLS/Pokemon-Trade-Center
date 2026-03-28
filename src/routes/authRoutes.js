import { Router } from "express";

export const authRouter = Router();

authRouter.post("/register", (req, res) => {
  const { username, email, password } = req.body || {};
  if (!username || !email || !password) {
    return res.status(400).json({ error: "username, email, password required" });
  }
  return res.status(201).json({ ok: true, username, email });
});

authRouter.post("/login", (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: "email, password required" });
  }
  return res.json({ ok: true, token: "temp-token" });
});
