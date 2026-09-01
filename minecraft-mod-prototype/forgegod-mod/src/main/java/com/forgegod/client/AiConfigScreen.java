package com.forgegod.client;

import com.forgegod.ai.ApiKeyStore;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.network.chat.Component;

/** Main-menu settings screen for the optional DeepSeek provider. */
public final class AiConfigScreen extends Screen {
    private final Screen parent;
    private EditBox keyBox;
    private Component status = Component.literal("");

    public AiConfigScreen(Screen parent) {
        super(Component.literal("锻造之神 AI 设置"));
        this.parent = parent;
    }

    @Override protected void init() {
        int center = width / 2;
        keyBox = new EditBox(font, center - 150, height / 2 - 38, 300, 20,
                Component.literal("DeepSeek API Key"));
        keyBox.setMaxLength(512);
        keyBox.setValue(ApiKeyStore.readStoredKey());
        addRenderableWidget(keyBox);
        addRenderableWidget(Button.builder(Component.literal("保存"), button -> save())
                .bounds(center - 150, height / 2 - 8, 92, 20).build());
        addRenderableWidget(Button.builder(Component.literal("清除本机密钥"), button -> clear())
                .bounds(center - 52, height / 2 - 8, 112, 20).build());
        addRenderableWidget(Button.builder(Component.literal("返回"), button -> onClose())
                .bounds(center + 66, height / 2 - 8, 84, 20).build());
    }

    private void save() {
        status = ApiKeyStore.saveStoredKey(keyBox.getValue())
                ? Component.literal("已保存。当前来源：" + ApiKeyStore.sourceLabel())
                : Component.literal("保存失败，请检查配置目录权限。");
    }

    private void clear() {
        ApiKeyStore.clearStoredKey();
        keyBox.setValue("");
        status = Component.literal(ApiKeyStore.hasEnvironmentKey()
                ? "本机密钥已清除，但环境变量仍会优先使用。"
                : "本机密钥已清除。");
    }

    @Override public void onClose() {
        minecraft.setScreen(parent);
    }

    @Override public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
        renderBackground(graphics);
        int center = width / 2;
        int top = height / 2 - 92;
        graphics.fill(center - 178, top, center + 178, top + 154, 0xE91A202B);
        graphics.fill(center - 178, top, center + 178, top + 3, 0xFFB78A48);
        graphics.drawCenteredString(font, title, center, top + 14, 0xFFEAD7A2);
        graphics.drawString(font, Component.literal("DeepSeek API Key"), center - 150, top + 39, 0xFFE1E6ED, false);
        graphics.drawString(font, Component.literal("当前来源：" + ApiKeyStore.sourceLabel()), center - 150, top + 78, 0xFFB8C4D6, false);
        graphics.drawString(font, Component.literal("密钥只保存在本机配置，不会发送到聊天。"), center - 150, top + 96, 0xFF7F8B9A, false);
        if (!status.getString().isBlank()) graphics.drawString(font, status, center - 150, top + 122, 0xFFFFD98A, false);
        super.render(graphics, mouseX, mouseY, partialTick);
    }
}
