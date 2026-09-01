package com.forgegod.trial;

import com.forgegod.ai.AiProvider;
import com.forgegod.ai.DeepSeekProvider;
import com.forgegod.blueprint.BlueprintValidator;
import com.forgegod.blueprint.EffectBlueprint;
import com.forgegod.compiler.TetraCompiler;
import com.forgegod.compiler.TetraCompiler.CompiledCandidate;
import com.forgegod.compat.TetraBridge;
import com.forgegod.datapack.GeneratedPackService;
import com.forgegod.menu.DivineAnvilMenu;
import com.forgegod.network.ForgeGodNetwork;
import com.forgegod.runtime.ContractRuntime;
import com.forgegod.weapon.TetraWeaponAdapter;
import com.forgegod.weapon.WeaponFacts;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.fml.ModList;

import java.io.IOException;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/** Coordinates one persistent, no-cutscene divine application per player and weapon. */
public final class DivineTrialService {
    private final BlueprintValidator validator = new BlueprintValidator();
    private final TetraCompiler compiler = new TetraCompiler();
    private final GeneratedPackService packs = new GeneratedPackService();
    private final Map<UUID, TrialSession> sessions = new ConcurrentHashMap<>();
    private final java.util.Set<UUID> pendingRequests = ConcurrentHashMap.newKeySet();
    private final java.util.Set<UUID> pendingRepairs = ConcurrentHashMap.newKeySet();
    private final AiProvider ai = new DeepSeekProvider();

    public void prepare(ServerPlayer player, EffectBlueprint blueprint) {
        ItemStack weapon = currentWeapon(player);
        if (weapon.isEmpty()) {
            player.sendSystemMessage(Component.literal("[ForgeGod] 请先把武器放入神裁砧的武器槽。"));
            return;
        }
        if (ContractRuntime.isBound(weapon)) {
            player.sendSystemMessage(Component.literal("[ForgeGod] 这把武器已经定稿，不能再次请神。"));
            return;
        }
        UUID weaponId = ContractRuntime.ensureWeaponId(weapon);
        TrialSession session = new TrialSession(player.getUUID(), weaponId, blueprint, 2);
        sessions.put(player.getUUID(), session);
    }

    public void onGuiOpen(ServerPlayer player) {
        TrialSession session = sessions.get(player.getUUID());
        ItemStack weapon = currentWeapon(player);
        if (session != null && !session.matchesWeapon(weapon)) {
            ForgeGodNetwork.sendStatus(player, "当前武器已更换，请为这把武器重新申请。", 2, false, false);
        } else if (session != null && session.phase() == TrialSession.Phase.COMMITTED) {
            ForgeGodNetwork.sendStatus(player, "这把武器已经定稿，不能再次请神。", 0, session.compiled(), true);
        } else if (session != null) {
            String status = session.explanation().isBlank() ? "已有候选，可返修、编译或定稿。" : "神谕已保留，可返修、编译或定稿。";
            ForgeGodNetwork.sendCandidate(player, session.current(), session.explanation(), status,
                    session.repairsRemaining(), session.compiled());
        } else if (ContractRuntime.isBound(weapon)) {
            ForgeGodNetwork.sendStatus(player, "这把武器已经定稿，不能再次请神。", 0, false, true);
        } else {
            ForgeGodNetwork.sendStatus(player, "把武器和供物放入砧上，写下申请。", 2, false, false);
        }
    }

    public void requestFromAi(ServerPlayer player, String intent) {
        ItemStack weapon = currentWeapon(player);
        if (weapon.isEmpty()) {
            sendError(player, "请先把武器放入神裁砧的武器槽。", 2, false, false);
            return;
        }
        if (ContractRuntime.isBound(weapon)) {
            sendError(player, "这把武器已经定稿，不能再次请神。", 0, false, true);
            return;
        }
        if (!pendingRequests.add(player.getUUID())) {
            sendError(player, "锻造之神正在处理上一条申请，请稍候。", 2, false, false);
            return;
        }
        UUID weaponId = ContractRuntime.ensureWeaponId(weapon);
        TrialSession existing = sessions.get(player.getUUID());
        if (existing != null && existing.matchesWeapon(weapon) && existing.phase() != TrialSession.Phase.ABANDONED) {
            ForgeGodNetwork.sendCandidate(player, existing.current(), existing.explanation(),
                    "这把武器已有神谕；请使用返修或定稿。", existing.repairsRemaining(), existing.compiled());
            player.sendSystemMessage(Component.literal("[ForgeGod] 同一把武器不能重复请神，请返修现有候选或直接定稿。"));
            return;
        }
        WeaponFacts facts = new TetraWeaponAdapter().inspect(weapon);
        String boundedIntent = intent == null ? "" : intent.trim();
        if (boundedIntent.isBlank()) boundedIntent = "围绕武器持有者飞行的火花小精灵，协同攻击同一目标";
        player.sendSystemMessage(Component.literal("[ForgeGod] 锻造之神正在审阅事实卡片（" + ai.name() + "）..."));
        ForgeGodNetwork.sendStatus(player, "锻造之神正在审阅事实卡片...", 2, false, false);
        String finalIntent = boundedIntent;
        ai.propose(facts, finalIntent).whenComplete((proposals, failure) -> player.server.execute(() -> {
            if (!pendingRequests.remove(player.getUUID())) return;
            if (failure != null) {
                sendError(player, "神明暂时沉默：" + rootMessage(failure), 2, false, false);
                player.sendSystemMessage(Component.literal("[ForgeGod] 神谕暂时不可达，未消耗资源。"));
                return;
            }
            if (!sameWeapon(player, weaponId)) {
                sendError(player, "武器槽在神谕返回前发生变化，本次结果已丢弃。", 2, false, false);
                return;
            }
            EffectBlueprint candidate = proposals.first();
            BlueprintValidator.ValidationResult result = validator.validate(candidate);
            if (!result.valid()) {
                sendError(player, "神谕违反锻造规则，未消耗返修次数。", 2, false, false);
                player.sendSystemMessage(Component.literal("[ForgeGod] " + String.join(", ", result.errors())));
                return;
            }
            TrialSession session = new TrialSession(player.getUUID(), weaponId, candidate, 2);
            session.setExplanation(proposals.explanation(0));
            sessions.put(player.getUUID(), session);
            ForgeGodNetwork.sendCandidate(player, candidate, session.explanation(),
                    "神谕完成：这套候选已保留。", session.repairsRemaining(), false);
            player.sendSystemMessage(Component.literal("[ForgeGod] 神谕已保留。你可以返修、编译候选或定稿绑定。"));
        }));
    }

    /** Compiles the current candidate and reloads the generated datapack; no camera scene is created. */
    public void startTrial(ServerPlayer player) {
        ItemStack weapon = currentWeapon(player);
        TrialSession session = sessions.get(player.getUUID());
        if (session == null) {
            if (weapon.isEmpty()) {
                sendError(player, "请先把武器放入神裁砧的武器槽。", 2, false, false);
                return;
            }
            prepare(player, EffectBlueprint.starter());
            session = sessions.get(player.getUUID());
        }
        if (session == null || !session.matchesWeapon(weapon)) {
            sendError(player, "当前武器与待处理的神谕不一致。", session == null ? 2 : session.repairsRemaining(), false, false);
            return;
        }
        if (session.phase() == TrialSession.Phase.COMMITTED || ContractRuntime.isBound(weapon)) {
            sendError(player, "这把武器已经定稿，不能再次编译或请神。", 0, session.compiled(), true);
            return;
        }
        try {
            CompiledCandidate candidate = compiler.compile(session.current());
            packs.write(player.server, candidate);
            TrialSession activeSession = session;
            packs.enableAndReload(player.server).whenComplete((ignored, failure) -> player.server.execute(() -> {
                if (failure != null) {
                    sendError(player, "候选 reload 失败，仍保留当前候选。", activeSession.repairsRemaining(), false, false);
                    return;
                }
                ItemStack current = currentWeapon(player);
                if (!activeSession.matchesWeapon(current)) {
                    sendError(player, "武器槽在编译期间发生变化，候选未挂载。", activeSession.repairsRemaining(), false, false);
                    return;
                }
                boolean attached = ModList.get().isLoaded("tetra")
                        && TetraBridge.attachCandidate(current, activeSession.current());
                activeSession.markCompiled();
                ForgeGodNetwork.sendCandidate(player, activeSession.current(), activeSession.explanation(),
                        "候选已编译，可定稿或返修。Tetra 挂载=" + attached,
                        activeSession.repairsRemaining(), true);
                player.sendSystemMessage(Component.literal("[ForgeGod] 候选已编译并 reload，可以定稿绑定。"));
            }));
        } catch (IOException | RuntimeException failure) {
            sendError(player, "候选编译失败，仍保留当前候选。", session.repairsRemaining(), false, false);
            player.sendSystemMessage(Component.literal("[ForgeGod] " + rootMessage(failure)));
        }
    }

    public void repair(ServerPlayer player, String feedback) {
        ItemStack weapon = currentWeapon(player);
        TrialSession session = sessions.get(player.getUUID());
        if (session == null || !session.matchesWeapon(weapon)) {
            sendError(player, "当前武器没有可返修的神谕。", session == null ? 2 : session.repairsRemaining(), false, false);
            return;
        }
        if (ContractRuntime.isBound(weapon) || !session.canRepair()) {
            sendError(player, "这把武器不能再返修。", session.repairsRemaining(), session.compiled(), ContractRuntime.isBound(weapon));
            return;
        }
        if (!pendingRepairs.add(player.getUUID())) {
            sendError(player, "锻造之神正在处理上一条返修意见，请稍候。", session.repairsRemaining(), session.compiled(), false);
            return;
        }
        EffectBlueprint previous = session.current();
        WeaponFacts facts = new TetraWeaponAdapter().inspect(weapon);
        String boundedFeedback = feedback == null ? "" : feedback.trim();
        if (boundedFeedback.isBlank()) boundedFeedback = "保留核心效果，降低触发代价并提高与当前材料的契合度";
        player.sendSystemMessage(Component.literal("[ForgeGod] 锻造之神正在根据你的返修意见重铸..."));
        ForgeGodNetwork.sendStatus(player, "锻造之神正在处理返修意见...", session.repairsRemaining(), session.compiled(), false);
        UUID weaponId = session.weaponId();
        String finalFeedback = boundedFeedback;
        ai.revise(facts, previous, finalFeedback, "").whenComplete((proposals, failure) -> player.server.execute(() -> {
            if (!pendingRepairs.remove(player.getUUID())) return;
            if (failure != null) {
                sendError(player, "返修神谕失败：" + rootMessage(failure), session.repairsRemaining(), session.compiled(), false);
                return;
            }
            if (!sameWeapon(player, weaponId)) {
                sendError(player, "武器槽在返修返回前发生变化，本次结果已丢弃。", session.repairsRemaining(), session.compiled(), false);
                return;
            }
            EffectBlueprint candidate = proposals.first().withContract(previous.contractId(), previous.revision() + 1);
            BlueprintValidator.ValidationResult result = validator.validate(candidate);
            if (!result.valid()) {
                sendError(player, "返修方案违反锻造规则，次数未扣除。", session.repairsRemaining(), session.compiled(), false);
                return;
            }
            session.addRevision(candidate);
            session.setExplanation(proposals.explanation(0));
            ForgeGodNetwork.sendCandidate(player, candidate, session.explanation(),
                    "返修完成：新候选已替换旧候选。", session.repairsRemaining(), false);
            player.sendSystemMessage(Component.literal("[ForgeGod] 返修完成，剩余返修次数 " + session.repairsRemaining() + "。"));
        }));
    }

    public void accept(ServerPlayer player) {
        ItemStack weapon = currentWeapon(player);
        TrialSession session = sessions.get(player.getUUID());
        if (session == null || !session.matchesWeapon(weapon)) {
            sendError(player, "当前武器没有可定稿的神谕。", session == null ? 2 : session.repairsRemaining(), false, false);
            return;
        }
        if (session.phase() == TrialSession.Phase.COMMITTED || ContractRuntime.isBound(weapon)) {
            sendError(player, "这把武器已经定稿，不能再次请神。", 0, session.compiled(), true);
            return;
        }
        if (!session.compiled()) {
            sendError(player, "请先点击“编译候选”完成规则写入，再定稿绑定。", session.repairsRemaining(), false, false);
            return;
        }
        session.commit();
        ContractRuntime.bind(weapon, session.current());
        player.sendSystemMessage(Component.literal("[ForgeGod] 已定稿 " + session.current().name()
                + "，契约已绑定到神裁砧中的武器。按住 R 查看神裁属性。"));
        ForgeGodNetwork.sendStatus(player, "契约已绑定；这把武器不能再次请神。", 0, session.compiled(), true);
    }

    public void clear(ServerPlayer player) {
        TrialSession session = sessions.remove(player.getUUID());
        pendingRequests.remove(player.getUUID());
        pendingRepairs.remove(player.getUUID());
        if (session != null) session.abandon();
        player.sendSystemMessage(Component.literal("[ForgeGod] 当前未定稿神谕已清除。"));
        ForgeGodNetwork.sendStatus(player, "当前申请已清除。", 2, false, false);
    }

    private ItemStack currentWeapon(ServerPlayer player) {
        if (player.containerMenu instanceof DivineAnvilMenu menu) return menu.weaponStack();
        return player.getMainHandItem();
    }

    private boolean sameWeapon(ServerPlayer player, UUID weaponId) {
        return weaponId != null && weaponId.equals(ContractRuntime.weaponId(currentWeapon(player)));
    }

    private void sendError(ServerPlayer player, String status, int repairs, boolean compiled, boolean locked) {
        ForgeGodNetwork.sendStatus(player, status, Math.max(0, repairs), compiled, locked);
        player.sendSystemMessage(Component.literal("[ForgeGod] " + status));
    }

    private static String rootMessage(Throwable failure) {
        Throwable current = failure;
        while (current.getCause() != null) current = current.getCause();
        return current.getMessage() == null ? current.getClass().getSimpleName() : current.getMessage();
    }
}
