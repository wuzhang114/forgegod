package com.forgegod.block;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.Container;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/** Two-slot inventory for the divine anvil: weapon and offering. */
public final class DivineAnvilBlockEntity extends BlockEntity implements Container {
    private final net.minecraft.world.SimpleContainer inventory = new net.minecraft.world.SimpleContainer(2) {
        @Override public void setChanged() { DivineAnvilBlockEntity.this.setChanged(); }
    };

    public DivineAnvilBlockEntity(BlockPos pos, BlockState state) {
        super(com.forgegod.ForgeGodMod.DIVINE_ANVIL_ENTITY.get(), pos, state);
    }

    @Override protected void saveAdditional(CompoundTag tag) {
        super.saveAdditional(tag);
        CompoundTag items = new CompoundTag();
        for (int i = 0; i < 2; i++) if (!getItem(i).isEmpty()) items.put(String.valueOf(i), getItem(i).save(new CompoundTag()));
        tag.put("Items", items);
    }

    @Override public void load(CompoundTag tag) {
        super.load(tag);
        CompoundTag items = tag.getCompound("Items");
        for (int i = 0; i < 2; i++) if (items.contains(String.valueOf(i))) setItem(i, ItemStack.of(items.getCompound(String.valueOf(i))));
    }

    @Override public int getContainerSize() { return 2; }
    @Override public boolean isEmpty() { return inventory.isEmpty(); }
    @Override public ItemStack getItem(int slot) { return inventory.getItem(slot); }
    @Override public ItemStack removeItem(int slot, int amount) { return inventory.removeItem(slot, amount); }
    @Override public ItemStack removeItemNoUpdate(int slot) { return inventory.removeItemNoUpdate(slot); }
    @Override public void setItem(int slot, ItemStack stack) { inventory.setItem(slot, stack); setChanged(); }
    @Override public int getMaxStackSize() { return 64; }
    @Override public void setChanged() { super.setChanged(); }
    @Override public boolean stillValid(Player player) { return player.distanceToSqr(worldPosition.getX() + .5, worldPosition.getY() + .5, worldPosition.getZ() + .5) < 64; }
    @Override public void clearContent() { inventory.clearContent(); }
}
