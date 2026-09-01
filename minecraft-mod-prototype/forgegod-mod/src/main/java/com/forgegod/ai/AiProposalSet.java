package com.forgegod.ai;

import com.forgegod.blueprint.EffectBlueprint;

import java.util.List;

/** One candidate returned by a divine turn; the list shape keeps provider parsing extensible. */
public record AiProposalSet(List<EffectBlueprint> proposals, List<String> explanations) {
    public AiProposalSet {
        proposals = List.copyOf(proposals);
        explanations = List.copyOf(explanations);
    }

    public EffectBlueprint first() { return proposals.get(0); }
    public EffectBlueprint second() { return first(); }
    public String explanation(int index) {
        return index >= 0 && index < explanations.size() ? explanations.get(index) : "锻造之神没有留下说明。";
    }
}
