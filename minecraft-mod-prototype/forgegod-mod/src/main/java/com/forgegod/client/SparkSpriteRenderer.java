package com.forgegod.client;

import com.forgegod.entity.SparkSpriteEntity;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import org.joml.Matrix4f;

/** Minimal renderer; the entity's flame/crit trail remains visible even without a custom texture. */
public final class SparkSpriteRenderer extends EntityRenderer<SparkSpriteEntity> {
    private static final ResourceLocation TEXTURE = new ResourceLocation("minecraft", "textures/particle/flame.png");

    public SparkSpriteRenderer(EntityRendererProvider.Context context) {
        super(context);
        shadowRadius = 0.12F;
    }

    @Override
    public ResourceLocation getTextureLocation(SparkSpriteEntity entity) {
        return TEXTURE;
    }

    @Override
    public void render(SparkSpriteEntity entity, float entityYaw, float partialTick, PoseStack poseStack,
                       MultiBufferSource buffers, int packedLight) {
        poseStack.pushPose();
        poseStack.mulPose(entityRenderDispatcher.cameraOrientation());
        poseStack.scale(0.42F, 0.42F, 0.42F);
        Matrix4f matrix = poseStack.last().pose();
        VertexConsumer vertices = buffers.getBuffer(RenderType.entityTranslucent(TEXTURE));
        quad(vertices, matrix, packedLight);
        poseStack.popPose();
        super.render(entity, entityYaw, partialTick, poseStack, buffers, packedLight);
    }

    private static void quad(VertexConsumer v, Matrix4f m, int light) {
        v.vertex(m, -0.5F, -0.5F, 0).color(255, 220, 80, 255).uv(0, 1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(0, 0, 1).endVertex();
        v.vertex(m, 0.5F, -0.5F, 0).color(255, 170, 40, 255).uv(1, 1).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(0, 0, 1).endVertex();
        v.vertex(m, 0.5F, 0.5F, 0).color(255, 245, 130, 255).uv(1, 0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(0, 0, 1).endVertex();
        v.vertex(m, -0.5F, 0.5F, 0).color(255, 220, 80, 255).uv(0, 0).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(0, 0, 1).endVertex();
    }
}
