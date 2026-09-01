package com.forgegod.weapon;

import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ItemStack;
import se.mickelus.tetra.items.modular.IModularItem;

import java.util.ArrayList;
import java.util.List;

/** Reads only server-owned, stable facts; no raw Tetra internals are sent to an AI provider. */
public final class TetraWeaponAdapter {
    public boolean supports(ItemStack stack) {
        return stack.getItem() instanceof IModularItem;
    }

    public WeaponFacts inspect(ItemStack stack) {
        boolean modular = supports(stack);
        List<WeaponFacts.ModuleFact> modules = new ArrayList<>();
        if (modular) {
            IModularItem item = (IModularItem) stack.getItem();
            var tag = stack.getTag();
            for (String slot : item.getMajorModuleKeys(stack)) {
                String moduleId = tag == null ? "" : tag.getString(slot);
                modules.add(new WeaponFacts.ModuleFact(slot, moduleId));
            }
        }
        String itemId = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString();
        List<String> facts = new ArrayList<>();
        facts.add("item." + itemId);
        if (modular) {
            facts.add("weapon.tetra_modular");
        }
        return new WeaponFacts(itemId, displayName(stack), modular, modules,
                stack.getMaxDamage() - stack.getDamageValue(), stack.getMaxDamage(), facts);
    }

    private static String displayName(ItemStack stack) {
        Component name = stack.getHoverName();
        return name.getString().length() > 64 ? name.getString().substring(0, 64) : name.getString();
    }
}
