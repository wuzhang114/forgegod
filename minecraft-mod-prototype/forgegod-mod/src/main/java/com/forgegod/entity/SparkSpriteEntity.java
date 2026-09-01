package com.forgegod.entity;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.syncher.EntityDataAccessor;
import net.minecraft.network.syncher.EntityDataSerializers;
import net.minecraft.network.syncher.SynchedEntityData;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.MobCategory;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.core.particles.ParticleTypes;

import javax.annotation.Nullable;
import java.util.List;
import java.util.UUID;

/** A small server-authoritative familiar created by a committed weapon contract. */
public final class SparkSpriteEntity extends Mob {
    private static final EntityDataAccessor<Integer> LIFE = SynchedEntityData.defineId(SparkSpriteEntity.class, EntityDataSerializers.INT);
    private static final EntityDataAccessor<Integer> ORBIT_INDEX = SynchedEntityData.defineId(SparkSpriteEntity.class, EntityDataSerializers.INT);
    private UUID ownerId;
    private UUID targetId;
    private int attackCooldown;

    public SparkSpriteEntity(EntityType<? extends SparkSpriteEntity> type, Level level) {
        super(type, level);
        setNoGravity(true);
        setInvulnerable(false);
        setGlowingTag(true);
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes().add(Attributes.MAX_HEALTH, 6.0D).add(Attributes.MOVEMENT_SPEED, 0.35D);
    }

    public void bindTo(ServerPlayer owner, int orbitIndex, int lifetimeTicks) {
        ownerId = owner.getUUID();
        getEntityData().set(ORBIT_INDEX, Math.max(0, orbitIndex));
        getEntityData().set(LIFE, Math.max(20, lifetimeTicks));
        setPos(owner.getX(), owner.getY() + 1.2D, owner.getZ());
    }

    @Nullable
    public UUID ownerId() { return ownerId; }

    @Override
    protected void defineSynchedData() {
        super.defineSynchedData();
        entityData.define(LIFE, 160);
        entityData.define(ORBIT_INDEX, 0);
    }

    @Override
    public void tick() {
        super.tick();
        int life = getEntityData().get(LIFE) - 1;
        getEntityData().set(LIFE, life);
        if (life <= 0 || isInWaterOrBubble()) { discard(); return; }
        if (!(level() instanceof ServerLevel serverLevel) || ownerId == null) return;
        var owner = serverLevel.getEntity(ownerId);
        if (!(owner instanceof ServerPlayer player) || !player.isAlive() || player.distanceToSqr(this) > 900.0D) {
            discard();
            return;
        }
        double angle = (tickCount * 0.12D) + getEntityData().get(ORBIT_INDEX) * (Math.PI * 2.0D / 4.0D);
        double radius = 1.2D + 0.15D * Math.sin(tickCount * 0.08D + getEntityData().get(ORBIT_INDEX));
        setDeltaMovement((player.getX() + Math.cos(angle) * radius - getX()) * 0.35D,
                (player.getY() + 1.25D + Math.sin(tickCount * 0.1D) * 0.25D - getY()) * 0.35D,
                (player.getZ() + Math.sin(angle) * radius - getZ()) * 0.35D);
        move(net.minecraft.world.entity.MoverType.SELF, getDeltaMovement());
        if (tickCount % 4 == 0) serverLevel.sendParticles(ParticleTypes.FLAME, getX(), getY(), getZ(), 2, .08, .08, .08, .01);
        if (attackCooldown > 0) attackCooldown--;
        if (attackCooldown <= 0) {
            LivingEntity target = findTarget(serverLevel, player);
            if (target != null) {
                targetId = target.getUUID();
                target.hurt(serverLevel.damageSources().magic(), 1.5F);
                serverLevel.sendParticles(ParticleTypes.CRIT, target.getX(), target.getY(0.6D), target.getZ(), 4, .15, .15, .15, .04);
                attackCooldown = 24;
            }
        }
    }

    private LivingEntity findTarget(ServerLevel level, Player owner) {
        List<LivingEntity> candidates = level.getEntitiesOfClass(LivingEntity.class,
                getBoundingBox().inflate(16.0D), entity -> entity.isAlive() && entity != owner && !(entity instanceof SparkSpriteEntity));
        LivingEntity nearest = null;
        double distance = Double.MAX_VALUE;
        for (LivingEntity candidate : candidates) {
            if (candidate instanceof Player player && player.getTeam() == owner.getTeam()) continue;
            double current = distanceToSqr(candidate);
            if (current < distance) { nearest = candidate; distance = current; }
        }
        return nearest;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        return super.hurt(source, Math.min(amount, 4.0F));
    }

    @Override
    public void addAdditionalSaveData(CompoundTag tag) {
        super.addAdditionalSaveData(tag);
        if (ownerId != null) tag.putUUID("Owner", ownerId);
        tag.putInt("Life", getEntityData().get(LIFE));
        tag.putInt("OrbitIndex", getEntityData().get(ORBIT_INDEX));
    }

    @Override
    public void readAdditionalSaveData(CompoundTag tag) {
        super.readAdditionalSaveData(tag);
        if (tag.hasUUID("Owner")) ownerId = tag.getUUID("Owner");
        getEntityData().set(LIFE, tag.getInt("Life"));
        getEntityData().set(ORBIT_INDEX, tag.getInt("OrbitIndex"));
    }

    @Override
    protected void registerGoals() { }
}
