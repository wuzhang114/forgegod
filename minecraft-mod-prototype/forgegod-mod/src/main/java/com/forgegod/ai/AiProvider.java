package com.forgegod.ai;

import com.forgegod.blueprint.EffectBlueprint;
import com.forgegod.weapon.WeaponFacts;

import java.util.concurrent.CompletableFuture;

/** Provider-neutral interface for the divine negotiation. */
public interface AiProvider {
    CompletableFuture<AiProposalSet> propose(WeaponFacts facts, String playerIntent);

    CompletableFuture<AiProposalSet> revise(WeaponFacts facts, EffectBlueprint previous,
                                               String feedback, String trace);

    String name();
}
