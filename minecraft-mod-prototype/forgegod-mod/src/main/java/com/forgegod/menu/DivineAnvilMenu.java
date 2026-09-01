package com.forgegod.menu;

import com.forgegod.ForgeGodMod;
import com.forgegod.block.DivineAnvilBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.world.Container;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.AbstractContainerMenu;
import net.minecraft.world.inventory.ContainerLevelAccess;
import net.minecraft.world.inventory.MenuType;
import net.minecraft.world.inventory.Slot;
import net.minecraft.world.item.ItemStack;

/** Server/client menu for the divine anvil. Button ids are intentionally stable for the client screen. */
public final class DivineAnvilMenu extends AbstractContainerMenu {
    public static final int BUTTON_AI = 0;
    public static final int BUTTON_REPAIR = 1;
    public static final int BUTTON_COMPILE = 2;
    public static final int BUTTON_ACCEPT = 3;
    private final Container inventory;
    private final ContainerLevelAccess access;
    private final BlockPos pos;

    public DivineAnvilMenu(int id, Inventory playerInventory, FriendlyByteBuf data) {
        this(id, playerInventory, data.readBlockPos());
    }

    private DivineAnvilMenu(int id, Inventory playerInventory, BlockPos pos) {
        this(id, playerInventory, getContainer(playerInventory, pos), pos);
    }

    public DivineAnvilMenu(int id, Inventory playerInventory, Container inventory, BlockPos pos) {
        super(ForgeGodMod.DIVINE_ANVIL_MENU.get(), id);
        this.inventory = inventory;
        this.pos = pos;
        this.access = ContainerLevelAccess.create(playerInventory.player.level(), pos);
        addSlot(new Slot(inventory, 0, 44, 35) {
            @Override public boolean mayPlace(ItemStack stack) { return !stack.isEmpty(); }
            @Override public int getMaxStackSize() { return 1; }
        });
        addSlot(new Slot(inventory, 1, 116, 35) {
            @Override public int getMaxStackSize() { return 64; }
        });
        addPlayerSlots(playerInventory);
    }

    private static Container getContainer(Inventory inv, BlockPos pos) {
        if (inv.player.level().getBlockEntity(pos) instanceof DivineAnvilBlockEntity anvil) return anvil;
        return new net.minecraft.world.SimpleContainer(2);
    }

    private void addPlayerSlots(Inventory inventory) {
        for (int row = 0; row < 3; row++) for (int col = 0; col < 9; col++)
            addSlot(new Slot(inventory, col + row * 9 + 9, 8 + col * 18, 153 + row * 18));
        for (int col = 0; col < 9; col++) addSlot(new Slot(inventory, col, 8 + col * 18, 207));
    }

    @Override public boolean stillValid(Player player) {
        return stillValid(access, player, ForgeGodMod.DIVINE_ANVIL.get());
    }

    public ItemStack weaponStack() { return inventory.getItem(0); }
    public ItemStack offeringStack() { return inventory.getItem(1); }

    @Override public ItemStack quickMoveStack(Player player, int index) {
        ItemStack result = ItemStack.EMPTY;
        Slot slot = slots.get(index);
        if (slot != null && slot.hasItem()) {
            ItemStack source = slot.getItem();
            result = source.copy();
            if (index < 2) {
                if (!moveItemStackTo(source, 2, slots.size(), true)) return ItemStack.EMPTY;
            } else if (!moveItemStackTo(source, 0, 1, false)) {
                return ItemStack.EMPTY;
            }
            if (source.isEmpty()) slot.set(ItemStack.EMPTY); else slot.setChanged();
        }
        return result;
    }

    @Override public boolean clickMenuButton(Player player, int id) {
        if (!(player instanceof net.minecraft.server.level.ServerPlayer serverPlayer)) return false;
        if (id == BUTTON_AI) ForgeGodMod.TRIALS.requestFromAi(serverPlayer, "围绕武器持有者飞行的火花小精灵，协同攻击同一目标");
        if (id == BUTTON_REPAIR) ForgeGodMod.TRIALS.repair(serverPlayer, "保留核心效果，降低触发代价并提高与当前材料的契合度");
        if (id == BUTTON_COMPILE) ForgeGodMod.TRIALS.startTrial(serverPlayer);
        if (id == BUTTON_ACCEPT) ForgeGodMod.TRIALS.accept(serverPlayer);
        return true;
    }

    public BlockPos blockPosition() { return pos; }
}
