package com.forgegod.runtime;

import com.forgegod.ForgeGodMod;
import com.forgegod.blueprint.EffectBlueprint;
import com.forgegod.entity.SparkSpriteEntity;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraftforge.event.entity.living.LivingDamageEvent;

import java.util.UUID;

/** Server-side execution of a committed DivineContract stored on an ItemStack. */
public final class ContractRuntime {
    public static final String CONTRACT_TAG = "forgegod_contract";
    public static final String WEAPON_ID_TAG = "forgegod_weapon_id";
    private ContractRuntime() { }

    /** Gives each stack a stable identity so a pending divine session cannot be applied to another item. */
    public static UUID ensureWeaponId(ItemStack stack) {
        if (stack.isEmpty()) return null;
        var tag = stack.getOrCreateTag();
        if (!tag.hasUUID(WEAPON_ID_TAG)) tag.putUUID(WEAPON_ID_TAG, UUID.randomUUID());
        return tag.getUUID(WEAPON_ID_TAG);
    }

    public static UUID weaponId(ItemStack stack) {
        if (stack.isEmpty() || !stack.hasTag() || !stack.getTag().hasUUID(WEAPON_ID_TAG)) return null;
        return stack.getTag().getUUID(WEAPON_ID_TAG);
    }

    public static void bind(ItemStack stack, EffectBlueprint blueprint) {
        var tag = stack.getOrCreateTag().getCompound(CONTRACT_TAG);
        tag.putUUID("contract_id", blueprint.contractId());
        tag.putString("bound_item", BuiltInRegistries.ITEM.getKey(stack.getItem()).toString());
        tag.putString("bound_name", stack.getHoverName().getString());
        tag.putInt("revision", blueprint.revision());
        tag.putString("name", blueprint.name());
        tag.putInt("hit_count", blueprint.hitCount());
        tag.putInt("hit_window", blueprint.hitWindowTicks());
        tag.putInt("familiar_count", blueprint.familiarCount());
        tag.putInt("familiar_lifetime", blueprint.familiarLifetimeTicks());
        tag.putInt("cooldown", blueprint.cooldownTicks());
        tag.putInt("durability_cost", blueprint.durabilityCost());
        tag.putInt("hits", 0);
        tag.putLong("last_hit", 0L);
        tag.putLong("cooldown_until", 0L);
        stack.getOrCreateTag().put(CONTRACT_TAG, tag);
    }

    public static boolean isBound(ItemStack stack) {
        return stack.hasTag() && stack.getTag().contains(CONTRACT_TAG);
    }

    public static boolean matchesBoundItem(ItemStack stack) {
        if (!isBound(stack)) return false;
        String expected = stack.getTag().getCompound(CONTRACT_TAG).getString("bound_item");
        return expected.isBlank() || expected.equals(BuiltInRegistries.ITEM.getKey(stack.getItem()).toString());
    }

    public static void onLivingDamage(LivingDamageEvent event) {
        if (!(event.getEntity().level() instanceof ServerLevel level)) return;
        DamageSource source = event.getSource();
        if (!(source.getEntity() instanceof ServerPlayer player)) return;
        ItemStack weapon = player.getMainHandItem();
        if (!matchesBoundItem(weapon)) return;
        var tag = weapon.getOrCreateTag().getCompound(CONTRACT_TAG);
        long now = level.getGameTime();
        int hits = tag.getInt("hits");
        if (now - tag.getLong("last_hit") > tag.getInt("hit_window")) hits = 0;
        hits++;
        tag.putInt("hits", hits);
        tag.putLong("last_hit", now);
        if (hits < tag.getInt("hit_count") || now < tag.getLong("cooldown_until")) return;
        tag.putLong("cooldown_until", now + tag.getInt("cooldown"));
        tag.putInt("hits", 0);
        int count = Math.min(4, Math.max(1, tag.getInt("familiar_count")));
        for (int i = 0; i < count; i++) {
            SparkSpriteEntity sprite = ForgeGodMod.SPARK_SPRITE.get().create(level);
            if (sprite != null) {
                sprite.bindTo(player, i, tag.getInt("familiar_lifetime"));
                level.addFreshEntity(sprite);
            }
        }
        int durabilityCost = Math.max(1, tag.getInt("durability_cost"));
        weapon.hurtAndBreak(durabilityCost, player, broken -> player.broadcastBreakEvent(EquipmentSlot.MAINHAND));
        player.sendSystemMessage(Component.literal("[ForgeGod] " + tag.getString("name") + " 召来了 " + count + " 只火花小精灵。"));
    }

    public static void tick(Player player) {
        ItemStack stack = player.getMainHandItem();
        if (!matchesBoundItem(stack)) return;
        var tag = stack.getTag().getCompound(CONTRACT_TAG);
        long now = player.level().getGameTime();
        if (tag.getInt("hits") > 0 && now - tag.getLong("last_hit") > tag.getInt("hit_window")) tag.putInt("hits", 0);
    }
}
