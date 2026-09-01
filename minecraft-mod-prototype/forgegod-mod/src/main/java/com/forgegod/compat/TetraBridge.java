package com.forgegod.compat;

import com.forgegod.blueprint.EffectBlueprint;
import net.minecraft.nbt.Tag;
import net.minecraft.world.item.ItemStack;
import se.mickelus.tetra.items.modular.IModularItem;
import se.mickelus.tetra.module.ItemModuleMajor;

/** Optional Tetra integration. The MOD still loads when Tetra is absent. */
public final class TetraBridge {
    private TetraBridge() { }

    public static boolean attachCandidate(ItemStack stack, EffectBlueprint blueprint) {
        if (!(stack.getItem() instanceof IModularItem modular)) {
            return false;
        }
        String id = blueprint.contractId().toString().replace('-', '_');
        String improvementKey = "forgegod/" + id + "/spark_sprites";
        for (String slot : modular.getMajorModuleKeys(stack)) {
            ItemModuleMajor.addImprovement(stack, slot, improvementKey, 1);
            if (stack.hasTag() && stack.getTag().contains(slot + ":" + improvementKey, Tag.TAG_INT)) {
                IModularItem.updateIdentifier(stack);
                return true;
            }
        }
        return false;
    }
}
