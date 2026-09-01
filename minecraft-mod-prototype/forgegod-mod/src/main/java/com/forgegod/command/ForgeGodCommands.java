package com.forgegod.command;

import com.forgegod.ForgeGodMod;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.commands.Commands;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.server.level.ServerPlayer;
import com.forgegod.weapon.TetraWeaponAdapter;

public final class ForgeGodCommands {
    private ForgeGodCommands() { }

    public static void register(com.mojang.brigadier.CommandDispatcher<CommandSourceStack> dispatcher) {
        dispatcher.register(Commands.literal("forgegod")
                .then(Commands.literal("help").executes(context -> {
                    context.getSource().sendSuccess(() -> net.minecraft.network.chat.Component.literal(
                            "/forgegod facts | /forgegod ask <申请> | /forgegod trial | /forgegod repair <反馈> | /forgegod accept | /forgegod abandon"), false);
                    return 1;
                }))
                .then(Commands.literal("trial").executes(context -> {
                    ServerPlayer player = context.getSource().getPlayerOrException();
                    ForgeGodMod.TRIALS.startTrial(player);
                    return 1;
                }))
                .then(Commands.literal("ask")
                        .then(Commands.argument("intent", StringArgumentType.greedyString()).executes(context -> {
                            ServerPlayer player = context.getSource().getPlayerOrException();
                            ForgeGodMod.TRIALS.requestFromAi(player, StringArgumentType.getString(context, "intent"));
                            return 1;
                        })))
                .then(Commands.literal("facts").executes(context -> {
                    ServerPlayer player = context.getSource().getPlayerOrException();
                    var facts = new TetraWeaponAdapter().inspect(player.getMainHandItem());
                    context.getSource().sendSuccess(() -> net.minecraft.network.chat.Component.literal(
                            "[ForgeGod] " + facts.itemId() + " | Tetra=" + facts.tetraModular()
                                    + " | slots=" + facts.majorModules().size() + " | facts=" + facts.factIds()), false);
                    return 1;
                }))
                .then(Commands.literal("repair")
                        .then(Commands.argument("feedback", StringArgumentType.greedyString()).executes(context -> {
                            ServerPlayer player = context.getSource().getPlayerOrException();
                            ForgeGodMod.TRIALS.repair(player, StringArgumentType.getString(context, "feedback"));
                            return 1;
                        })))
                .then(Commands.literal("accept").executes(context -> {
                    ForgeGodMod.TRIALS.accept(context.getSource().getPlayerOrException());
                    return 1;
                }))
                .then(Commands.literal("abandon").executes(context -> {
                    ForgeGodMod.TRIALS.clear(context.getSource().getPlayerOrException());
                    context.getSource().sendSuccess(() -> net.minecraft.network.chat.Component.literal(
                            "[ForgeGod] 当前神裁申请已放弃，未定稿候选不会扣除供物。"), false);
                    return 1;
                })));
    }
}
