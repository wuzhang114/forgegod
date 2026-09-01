package com.forgegod.blueprint;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import java.util.List;
import java.util.UUID;

/** Immutable, provider-neutral representation of an AI proposal. */
public record EffectBlueprint(
        UUID contractId,
        int revision,
        String name,
        String fantasy,
        List<String> citedFactIds,
        int hitCount,
        int hitWindowTicks,
        int familiarCount,
        int familiarLifetimeTicks,
        int cooldownTicks,
        int durabilityCost) {

    public static EffectBlueprint starter() {
        return new EffectBlueprint(
                UUID.randomUUID(), 1, "银木火花之约",
                "连续命中后召来火花小精灵追击被标记的目标",
                List.of("prototype.handcrafted.spirit_affinity"),
                3, 200, 2, 160, 600, 3);
    }

    public EffectBlueprint revised(String feedback) {
        String normalized = feedback == null ? "" : feedback.toLowerCase(java.util.Locale.ROOT);
        int nextCount = familiarCount;
        int nextLifetime = familiarLifetimeTicks;
        int nextCooldown = cooldownTicks;
        int nextCost = durabilityCost;
        if (normalized.contains("少") || normalized.contains("数量")) {
            nextCount = Math.max(1, familiarCount - 1);
        }
        if (normalized.contains("久") || normalized.contains("持续")) {
            nextLifetime = Math.min(240, familiarLifetimeTicks + 40);
        }
        if (normalized.contains("代价") || normalized.contains("耐久")) {
            nextCost = Math.max(1, durabilityCost - 1);
            nextCooldown = Math.min(1200, cooldownTicks + 100);
        }
        return new EffectBlueprint(contractId, revision + 1,
                name + "（返修" + (revision) + "）", fantasy, citedFactIds,
                hitCount, hitWindowTicks, nextCount, nextLifetime, nextCooldown, nextCost);
    }

    public EffectBlueprint withContract(UUID id, int nextRevision) {
        return new EffectBlueprint(id, nextRevision, name, fantasy, citedFactIds,
                hitCount, hitWindowTicks, familiarCount, familiarLifetimeTicks,
                cooldownTicks, durabilityCost);
    }

    /** Parses the provider's strict JSON shape while applying conservative defaults. */
    public static EffectBlueprint fromJson(JsonObject json, int defaultRevision, String defaultFact) {
        UUID id;
        try {
            id = UUID.fromString(string(json, "contract_id", UUID.randomUUID().toString()));
        } catch (IllegalArgumentException ignored) {
            id = UUID.randomUUID();
        }
        int revision = integer(json, "revision", integer(json, "candidate_revision", defaultRevision));
        String name = string(json, "name", "未命名神裁");
        String fantasy = string(json, "fantasy", "火花小精灵回应持有者的意志");
        java.util.ArrayList<String> facts = new java.util.ArrayList<>();
        if (json.has("cited_fact_ids") && json.get("cited_fact_ids").isJsonArray()) {
            for (JsonElement element : json.getAsJsonArray("cited_fact_ids")) {
                if (element.isJsonPrimitive() && element.getAsJsonPrimitive().isString()) facts.add(element.getAsString());
            }
        }
        if (facts.isEmpty()) facts.add(defaultFact);
        return new EffectBlueprint(id, Math.max(1, revision), name, fantasy, List.copyOf(facts),
                integer(json, "hit_count", 3), integer(json, "hit_window_ticks", 200),
                integer(json, "familiar_count", 2), integer(json, "familiar_lifetime_ticks", 160),
                integer(json, "cooldown_ticks", 600), integer(json, "durability_cost", 3));
    }

    private static String string(JsonObject object, String key, String fallback) {
        JsonElement value = object.get(key);
        return value != null && value.isJsonPrimitive() ? value.getAsString() : fallback;
    }

    private static int integer(JsonObject object, String key, int fallback) {
        JsonElement value = object.get(key);
        if (value == null || !value.isJsonPrimitive()) return fallback;
        try { return value.getAsInt(); } catch (RuntimeException ignored) { return fallback; }
    }

    public JsonObject toJson() {
        JsonObject root = new JsonObject();
        root.addProperty("blueprint_version", 1);
        root.addProperty("contract_id", contractId.toString());
        root.addProperty("candidate", "candidate_v" + revision);
        root.addProperty("name", name);
        root.addProperty("fantasy", fantasy);
        JsonArray facts = new JsonArray();
        citedFactIds.forEach(facts::add);
        root.add("cited_fact_ids", facts);
        JsonObject limits = new JsonObject();
        limits.addProperty("cooldown_ticks", cooldownTicks);
        limits.addProperty("max_spawned_entities", familiarCount);
        limits.addProperty("max_lifetime_ticks", familiarLifetimeTicks);
        limits.addProperty("max_steps_per_trigger", 24);
        root.add("limits", limits);
        return root;
    }
}
