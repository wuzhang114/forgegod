package com.forgegod.trial;

import com.forgegod.blueprint.EffectBlueprint;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import net.minecraft.world.item.ItemStack;

/** Server-owned state for one weapon's divine application. */
public final class TrialSession {
    public enum Phase { CANDIDATE_READY, COMMITTED, ABANDONED }

    private final UUID owner;
    private final UUID weaponId;
    private final List<EffectBlueprint> candidates = new ArrayList<>();
    private int repairsRemaining;
    private Phase phase = Phase.CANDIDATE_READY;
    private boolean compiled;
    private String explanation = "";

    public TrialSession(UUID owner, UUID weaponId, EffectBlueprint first, int repairsRemaining) {
        this.owner = owner;
        this.weaponId = weaponId;
        this.candidates.add(first);
        this.repairsRemaining = repairsRemaining;
    }

    public UUID owner() { return owner; }
    public UUID weaponId() { return weaponId; }
    public EffectBlueprint current() { return candidates.get(candidates.size() - 1); }
    public List<EffectBlueprint> candidates() { return List.copyOf(candidates); }
    public int repairsRemaining() { return repairsRemaining; }
    public Phase phase() { return phase; }
    public boolean compiled() { return compiled; }
    public String explanation() { return explanation; }

    public boolean matchesWeapon(ItemStack stack) {
        return weaponId != null && weaponId.equals(com.forgegod.runtime.ContractRuntime.weaponId(stack));
    }

    public void setExplanation(String value) {
        explanation = value == null ? "" : value.length() > 1200 ? value.substring(0, 1200) : value;
    }

    public void markCompiled() { compiled = true; }

    public boolean canRepair() { return phase == Phase.CANDIDATE_READY && repairsRemaining > 0; }

    public void addRevision(EffectBlueprint blueprint) {
        if (!canRepair()) throw new IllegalStateException("No repair attempt available");
        repairsRemaining--;
        candidates.add(blueprint);
        compiled = false;
    }

    public void commit() { phase = Phase.COMMITTED; }
    public void abandon() { phase = Phase.ABANDONED; }
}
