package com.forgegod.client;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import org.lwjgl.glfw.GLFW;

public final class ForgeGodKeyMappings {
    public static final KeyMapping SHOW_DIVINE_ATTRIBUTES = new KeyMapping(
            "key.forgegod.show_divine_attributes", InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_R, "key.categories.forgegod");

    private ForgeGodKeyMappings() { }
}
