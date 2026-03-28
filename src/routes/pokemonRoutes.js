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
