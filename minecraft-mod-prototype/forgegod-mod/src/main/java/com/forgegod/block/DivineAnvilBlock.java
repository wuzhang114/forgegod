package com.forgegod.block;

import com.forgegod.ForgeGodMod;
import com.forgegod.blueprint.EffectBlueprint;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.BlockHitResult;

public final class DivineAnvilBlock extends Block implements EntityBlock {
    public DivineAnvilBlock(Properties properties) {
        super(properties);
    }

    @Override
    public net.minecraft.world.level.block.RenderShape getRenderShape(BlockState state) {
        return net.minecraft.world.level.block.RenderShape.MODEL;
    }

    @Override
    public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
        return new DivineAnvilBlockEntity(pos, state);
    }

    @Override
    public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player,
                                 InteractionHand hand, BlockHitResult hit) {
        if (level.isClientSide) {
            return InteractionResult.SUCCESS;
        }
        if (!(player instanceof ServerPlayer serverPlayer)) {
            return InteractionResult.PASS;
        }

        if (hand == InteractionHand.MAIN_HAND) {
            net.minecraftforge.network.NetworkHooks.openScreen(serverPlayer,
                    new net.minecraft.world.MenuProvider() {
                        @Override public Component getDisplayName() { return Component.literal("神裁砧"); }
                        @Override public net.minecraft.world.inventory.AbstractContainerMenu createMenu(int id, net.minecraft.world.entity.player.Inventory inventory, Player p) {
                            DivineAnvilBlockEntity anvil = (DivineAnvilBlockEntity) level.getBlockEntity(pos);
                            return new com.forgegod.menu.DivineAnvilMenu(id, inventory, anvil, pos);
                        }
                    }, pos);
            ForgeGodMod.TRIALS.onGuiOpen(serverPlayer);
            serverPlayer.sendSystemMessage(Component.literal("[ForgeGod] 神裁砧已开启：放入武器和供物，写下申请或返修意见。"));
        }
        return InteractionResult.CONSUME;
    }
}
