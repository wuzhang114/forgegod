package com.forgegod.blueprint;

import java.util.ArrayList;
import java.util.List;

public final class BlueprintValidator {
    public ValidationResult validate(EffectBlueprint blueprint) {
        List<String> errors = new ArrayList<>();
        if (blueprint == null) {
            errors.add("blueprint is null");
            return new ValidationResult(errors);
        }
        if (blueprint.name() == null || blueprint.name().isBlank() || blueprint.name().length() > 48) {
            errors.add("name must contain 1-48 characters");
        }
        if (blueprint.fantasy() == null || blueprint.fantasy().length() > 240) {
            errors.add("fantasy is missing or too long");
        }
        if (blueprint.citedFactIds() == null || blueprint.citedFactIds().isEmpty()) {
            errors.add("at least one cited fact is required");
        }
        if (blueprint.hitCount() < 1 || blueprint.hitCount() > 8) {
            errors.add("hitCount must be between 1 and 8");
        }
        if (blueprint.hitWindowTicks() < 20 || blueprint.hitWindowTicks() > 1200) {
            errors.add("hitWindowTicks is outside the prototype budget");
        }
        if (blueprint.familiarCount() < 1 || blueprint.familiarCount() > 4) {
            errors.add("familiarCount must be between 1 and 4");
        }
        if (blueprint.familiarLifetimeTicks() < 20 || blueprint.familiarLifetimeTicks() > 240) {
            errors.add("familiar lifetime is outside the prototype budget");
        }
        if (blueprint.cooldownTicks() < 40 || blueprint.cooldownTicks() > 2400) {
            errors.add("cooldown is outside the prototype budget");
        }
        if (blueprint.durabilityCost() < 1 || blueprint.durabilityCost() > 12) {
            errors.add("durability cost is outside the prototype budget");
        }
        return new ValidationResult(errors);
    }

    public record ValidationResult(List<String> errors) {
        public boolean valid() {
            return errors.isEmpty();
        }
    }
}
