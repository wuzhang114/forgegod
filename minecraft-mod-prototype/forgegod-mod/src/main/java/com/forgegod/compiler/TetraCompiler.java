package com.forgegod.compiler;

import com.forgegod.blueprint.EffectBlueprint;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import java.util.LinkedHashMap;
import java.util.Map;

/** Compiles the provider-neutral blueprint into a small, deterministic data pack. */
public final class TetraCompiler {
    public CompiledCandidate compile(EffectBlueprint blueprint) {
        String id = blueprint.contractId().toString().replace('-', '_');
        String effectId = "forgegod/" + id + "/spark_sprites";

        JsonObject effect = new JsonObject();
        effect.addProperty("trigger", "tetra:on_use");
        effect.addProperty("effect", effectId);
        JsonObject outcome = new JsonObject();
        outcome.addProperty("type", "tetra:multiple");
        JsonArray outcomes = new JsonArray();
        JsonObject particles = new JsonObject();
        particles.addProperty("type", "tetra:particle");
        JsonObject particle = new JsonObject();
        particle.addProperty("type", "minecraft:enchanted_hit");
        particles.add("particle", particle);
        particles.addProperty("count", blueprint.familiarCount() * 4);
        particles.addProperty("speed", 0.04);
        JsonArray spread = new JsonArray();
        spread.add(0.35);
        spread.add(0.35);
        spread.add(0.35);
        particles.add("spread", spread);
        outcomes.add(particles);
        JsonObject sound = new JsonObject();
        sound.addProperty("type", "tetra:sound");
        sound.addProperty("sound", "minecraft:block.amethyst_block.chime");
        sound.addProperty("volume", 0.7);
        sound.addProperty("pitch", 1.2);
        outcomes.add(sound);
        outcome.add("outcomes", outcomes);
        effect.add("outcome", outcome);

        JsonArray improvement = new JsonArray();
        JsonObject entry = new JsonObject();
        entry.addProperty("key", effectId);
        entry.addProperty("level", 1);
        entry.addProperty("integrity", -1);
        JsonObject effects = new JsonObject();
        effects.addProperty(effectId, 1);
        entry.add("effects", effects);
        improvement.add(entry);

        Map<String, JsonElement> files = new LinkedHashMap<>();
        files.put("data/tetra/item_effects/forgegod/" + id + "/spark_sprites.json", effect);
        files.put("data/tetra/improvements/shared/forgegod/" + id + ".json", improvement);
        return new CompiledCandidate(blueprint, files);
    }

    public record CompiledCandidate(EffectBlueprint blueprint, Map<String, JsonElement> files) {
    }
}
