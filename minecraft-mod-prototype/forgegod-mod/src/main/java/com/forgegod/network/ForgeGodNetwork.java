package com.forgegod.network;

import com.forgegod.ForgeGodMod;
import com.forgegod.blueprint.EffectBlueprint;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkEvent;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.simple.SimpleChannel;

import java.util.function.Supplier;

/** Authenticated channel for the compact divine-anvil UI. */
public final class ForgeGodNetwork {
    private static final String PROTOCOL = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel(
            new ResourceLocation(ForgeGodMod.MOD_ID, "main"), () -> PROTOCOL, PROTOCOL::equals, PROTOCOL::equals);
    private static int id;

    private ForgeGodNetwork() { }

    public static void register() {
        CHANNEL.registerMessage(id++, GuiActionPacket.class, GuiActionPacket::encode, GuiActionPacket::decode, GuiActionPacket::handle);
        CHANNEL.registerMessage(id++, AiStatePacket.class, AiStatePacket::encode, AiStatePacket::decode, AiStatePacket::handle);
    }

    public static void sendCandidate(ServerPlayer player, EffectBlueprint candidate, String explanation,
                                     String status, int repairs, boolean compiled) {
        sendCandidate(player, candidate, explanation, status, repairs, compiled, false);
    }

    public static void sendCandidate(ServerPlayer player, EffectBlueprint candidate, String explanation,
                                     String status, int repairs, boolean compiled, boolean locked) {
        AiStatePacket packet = AiStatePacket.from(candidate, explanation, status, repairs, compiled, locked);
        CHANNEL.sendTo(packet, player.connection.connection, net.minecraftforge.network.NetworkDirection.PLAY_TO_CLIENT);
    }

    public static void sendStatus(ServerPlayer player, String status, int repairs, boolean compiled) {
        sendStatus(player, status, repairs, compiled, false);
    }

    public static void sendStatus(ServerPlayer player, String status, int repairs, boolean compiled, boolean locked) {
        CHANNEL.sendTo(new AiStatePacket(status, repairs, false, compiled, locked,
                        "", "", "", ""), player.connection.connection,
                net.minecraftforge.network.NetworkDirection.PLAY_TO_CLIENT);
    }

    public record GuiActionPacket(int action, String text) {
        public static void encode(GuiActionPacket packet, FriendlyByteBuf buffer) {
            buffer.writeVarInt(packet.action);
            buffer.writeUtf(packet.text == null ? "" : packet.text, 1200);
        }

        public static GuiActionPacket decode(FriendlyByteBuf buffer) {
            return new GuiActionPacket(buffer.readVarInt(), buffer.readUtf(1200));
        }

        public static void handle(GuiActionPacket packet, Supplier<NetworkEvent.Context> supplier) {
            NetworkEvent.Context context = supplier.get();
            context.enqueueWork(() -> {
                ServerPlayer player = context.getSender();
                if (!(player != null && player.containerMenu instanceof com.forgegod.menu.DivineAnvilMenu)) return;
                switch (packet.action) {
                    case 0 -> ForgeGodMod.TRIALS.requestFromAi(player, packet.text);
                    case 1 -> ForgeGodMod.TRIALS.repair(player, packet.text);
                    case 2 -> ForgeGodMod.TRIALS.startTrial(player);
                    case 3 -> ForgeGodMod.TRIALS.accept(player);
                    default -> { }
                }
            });
            context.setPacketHandled(true);
        }
    }

    public record AiStatePacket(String status, int repairs, boolean hasProposal, boolean compiled, boolean locked,
                                String name, String fantasy, String stats, String reason) {
        static AiStatePacket from(EffectBlueprint candidate, String explanation, String status,
                                  int repairs, boolean compiled, boolean locked) {
            return new AiStatePacket(status, repairs, true, compiled, locked, candidate.name(), candidate.fantasy(),
                    stats(candidate), explanation == null ? "" : explanation);
        }

        private static String stats(EffectBlueprint blueprint) {
            return "命中 " + blueprint.hitCount() + " 次 | 小精灵 " + blueprint.familiarCount()
                    + " 只 / " + blueprint.familiarLifetimeTicks() + " tick | 冷却 " + blueprint.cooldownTicks()
                    + " tick | 耐久 -" + blueprint.durabilityCost();
        }

        public void encode(FriendlyByteBuf buffer) {
            buffer.writeUtf(status, 512);
            buffer.writeVarInt(repairs);
            buffer.writeBoolean(hasProposal);
            buffer.writeBoolean(compiled);
            buffer.writeBoolean(locked);
            buffer.writeUtf(name, 1200);
            buffer.writeUtf(fantasy, 1200);
            buffer.writeUtf(stats, 1200);
            buffer.writeUtf(reason, 1200);
        }

        public static AiStatePacket decode(FriendlyByteBuf buffer) {
            String status = buffer.readUtf(512);
            int repairs = buffer.readVarInt();
            boolean hasProposal = buffer.readBoolean();
            boolean compiled = buffer.readBoolean();
            boolean locked = buffer.readBoolean();
            return new AiStatePacket(status, repairs, hasProposal, compiled, locked,
                    buffer.readUtf(1200), buffer.readUtf(1200), buffer.readUtf(1200), buffer.readUtf(1200));
        }

        public static void handle(AiStatePacket packet, Supplier<NetworkEvent.Context> supplier) {
            NetworkEvent.Context context = supplier.get();
            context.enqueueWork(() -> net.minecraftforge.fml.DistExecutor.unsafeRunWhenOn(
                    net.minecraftforge.api.distmarker.Dist.CLIENT,
                    () -> () -> com.forgegod.client.DivineAnvilScreen.receiveState(packet)));
            context.setPacketHandled(true);
        }
    }
}
