package com.forgegod.client;

import com.forgegod.menu.DivineAnvilMenu;
import com.forgegod.network.ForgeGodNetwork;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.inventory.AbstractContainerScreen;
import net.minecraft.network.chat.Component;
import net.minecraft.world.entity.player.Inventory;

/** Compact player-facing divine-anvil UI: one AI candidate and one real text field. */
public final class DivineAnvilScreen extends AbstractContainerScreen<DivineAnvilMenu> {
    private static final int PANEL = 0xE91A202B;
    private static final int PANEL_LIGHT = 0xFF273342;
    private static final int PROPOSAL = 0xFF334D5D;
    private static volatile String draftText = "";
    private static volatile ForgeGodNetwork.AiStatePacket latestState =
            new ForgeGodNetwork.AiStatePacket("把武器和供物放入砧上，写下申请。", 2, false, false, false,
                    "", "", "", "");

    private EditBox requestBox;
    private Button aiButton;
    private Button reviseButton;
    private Button compileButton;
    private Button acceptButton;

    public DivineAnvilScreen(DivineAnvilMenu menu, Inventory inventory, Component title) {
        super(menu, inventory, title);
        imageWidth = 430;
        imageHeight = 238;
    }

    public static void receiveState(ForgeGodNetwork.AiStatePacket state) {
        latestState = state;
        Minecraft.getInstance().execute(() -> {
            if (Minecraft.getInstance().screen instanceof DivineAnvilScreen screen) screen.applyState(state);
        });
    }

    @Override protected void init() {
        super.init();
        requestBox = new EditBox(font, leftPos + 170, topPos + 25, 252, 20,
                Component.literal("申请或返修意见"));
        requestBox.setMaxLength(1200);
        requestBox.setValue(draftText);
        requestBox.setResponder(value -> draftText = value);
        addRenderableWidget(requestBox);

        aiButton = addButton("请神", 170, 145, 76, 20, 0);
        reviseButton = addButton("返修", 250, 145, 76, 20, 1);
        compileButton = addButton("编译候选", 330, 145, 92, 20, 2);
        acceptButton = addButton("定稿绑定", 170, 171, 96, 20, 3);
        applyState(latestState);
    }

    private Button addButton(String text, int x, int y, int width, int height, int action) {
        return addRenderableWidget(Button.builder(Component.literal(text), button -> {
            String input = requestBox == null ? "" : requestBox.getValue().trim();
            ForgeGodNetwork.CHANNEL.sendToServer(new ForgeGodNetwork.GuiActionPacket(action, input));
        }).bounds(leftPos + x, topPos + y, width, height).build());
    }

    private void applyState(ForgeGodNetwork.AiStatePacket state) {
        if (aiButton == null) return;
        aiButton.active = !state.locked() && !state.hasProposal();
        reviseButton.active = state.hasProposal() && state.repairs() > 0 && !state.locked();
        compileButton.active = state.hasProposal() && !state.locked();
        acceptButton.active = state.hasProposal() && state.compiled() && !state.locked();
    }

    @Override protected void renderBg(GuiGraphics graphics, float partialTick, int mouseX, int mouseY) {
        int left = leftPos, top = topPos;
        graphics.fill(left, top, left + imageWidth, top + imageHeight, PANEL);
        graphics.fill(left + 8, top + 8, left + 162, top + 143, PANEL_LIGHT);
        graphics.fill(left + 170, top + 8, left + 422, top + 139, 0xFF202936);
        graphics.fill(left + 170, top + 8, left + 422, top + 11, 0xFFB78A48);
        graphics.fill(left + 170, top + 136, left + 422, top + 208, 0xFF131820);
        graphics.fill(left + 8, top + 146, left + 162, top + 234, 0xFF131820);
    }

    @Override protected void renderLabels(GuiGraphics graphics, int mouseX, int mouseY) {
        graphics.drawString(font, Component.literal("神裁砧"), 12, 12, 0xFFEAD7A2, false);
        graphics.drawString(font, Component.literal("武器"), 35, 22, 0xFFB8C4D6, false);
        graphics.drawString(font, Component.literal("供物"), 100, 22, 0xFFB8C4D6, false);
        graphics.drawString(font, Component.literal("事实卡片"), 16, 60, 0xFFEAD7A2, false);
        net.minecraft.world.item.ItemStack weapon = menu.weaponStack();
        net.minecraft.world.item.ItemStack offering = menu.offeringStack();
        graphics.drawString(font, Component.literal(weapon.isEmpty() ? "未放入武器" : trim(weapon.getHoverName().getString(), 17)), 16, 76, 0xFFE1E6ED, false);
        if (!weapon.isEmpty() && weapon.getMaxDamage() > 0) {
            graphics.drawString(font, Component.literal("耐久 " + (weapon.getMaxDamage() - weapon.getDamageValue()) + "/" + weapon.getMaxDamage()), 16, 91, 0xFFB8C4D6, false);
        }
        graphics.drawString(font, Component.literal(offering.isEmpty() ? "未放入供物" : trim(offering.getHoverName().getString(), 17)), 16, 112, 0xFFFFD98A, false);
        graphics.drawString(font, Component.literal("Tetra 事实由服务器读取"), 16, 133, 0xFF7F8B9A, false);

        graphics.drawString(font, Component.literal("锻造之神的建议"), 170, 13, 0xFFEAD7A2, false);
        graphics.drawString(font, Component.literal("返修：" + latestState.repairs()), 350, 13, 0xFFD6B56D, false);
        drawProposal(graphics, latestState);
        graphics.drawString(font, Component.literal(latestState.compiled() ? "候选已编译，可定稿或返修" : latestState.status()),
                170, 215, 0xFFB8C4D6, false);
    }

    private void drawProposal(GuiGraphics graphics, ForgeGodNetwork.AiStatePacket state) {
        int x = 170, y = 50, width = 252, height = 82;
        graphics.fill(x, y, x + width, y + height, PROPOSAL);
        if (!state.hasProposal() || state.name().isBlank()) {
            graphics.drawString(font, Component.literal("等待神谕..."), x + 8, y + 10, 0xFF9AA6B6, false);
            return;
        }
        graphics.drawString(font, Component.literal(trim(state.name(), 32)), x + 8, y + 7, 0xFFFFFFFF, false);
        drawWrapped(graphics, state.fantasy(), x + 8, y + 23, width - 16, 9, 2, 0xFFE1E6ED);
        drawWrapped(graphics, state.stats(), x + 8, y + 43, width - 16, 9, 2, 0xFFFFD98A);
        drawWrapped(graphics, state.reason(), x + 8, y + 63, width - 16, 9, 1, 0xFFB8C4D6);
    }

    private void drawWrapped(GuiGraphics graphics, String text, int x, int y, int width,
                             int lineHeight, int maxLines, int color) {
        if (text == null) return;
        String remaining = text;
        for (int line = 0; line < maxLines && !remaining.isBlank(); line++) {
            int length = remaining.length();
            while (length > 1 && font.width(remaining.substring(0, length)) > width) length--;
            graphics.drawString(font, Component.literal(remaining.substring(0, length)), x,
                    y + line * lineHeight, color, false);
            remaining = remaining.substring(length).trim();
        }
    }

    private static String trim(String text, int max) {
        return text.length() <= max ? text : text.substring(0, max - 1) + "…";
    }

    @Override public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        renderBackground(graphics);
        super.render(graphics, mouseX, mouseY, partialTick);
        renderTooltip(graphics, mouseX, mouseY);
    }
}
