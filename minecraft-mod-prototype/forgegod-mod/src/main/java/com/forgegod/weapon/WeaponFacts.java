package com.forgegod.weapon;

import java.util.List;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;

public record WeaponFacts(
        String itemId,
        String displayName,
        boolean tetraModular,
        List<ModuleFact> majorModules,
        int currentDamage,
        int maxDamage,
        List<String> factIds) {
    public record ModuleFact(String slot, String moduleId) { }

    public JsonObject toJson() {
        JsonObject json = new JsonObject();
        json.addProperty("item_id", itemId);
        json.addProperty("display_name", displayName);
        json.addProperty("tetra_modular", tetraModular);
        json.addProperty("current_durability", currentDamage);
        json.addProperty("max_durability", maxDamage);
        JsonArray modules = new JsonArray();
        for (ModuleFact module : majorModules) {
            JsonObject entry = new JsonObject();
            entry.addProperty("slot", module.slot());
            entry.addProperty("module_id", module.moduleId());
            modules.add(entry);
        }
        json.add("major_modules", modules);
        JsonArray ids = new JsonArray();
        factIds.forEach(ids::add);
        json.add("fact_ids", ids);
        return json;
    }
}
