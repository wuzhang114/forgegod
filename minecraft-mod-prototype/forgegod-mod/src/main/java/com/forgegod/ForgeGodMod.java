package com.forgegod;

import com.forgegod.block.DivineAnvilBlock;
import com.forgegod.command.ForgeGodCommands;
import com.forgegod.trial.DivineTrialService;
import com.forgegod.entity.SparkSpriteEntity;
import com.forgegod.runtime.ContractRuntime;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.Item;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.inventory.MenuType;
import net.minecraftforge.common.extensions.IForgeMenuType;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDamageEvent;
import net.minecraftforge.event.entity.player.ItemTooltipEvent;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.client.event.ScreenEvent;
import net.minecraftforge.fml.event.lifecycle.FMLClientSetupEvent;
import net.minecraft.client.gui.screens.MenuScreens;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;
import com.forgegod.network.ForgeGodNetwork;

@Mod(ForgeGodMod.MOD_ID)
public final class ForgeGodMod {
    public static final String MOD_ID = "forgegod";

    public static final DeferredRegister<Block> BLOCKS =
            DeferredRegister.create(ForgeRegistries.BLOCKS, MOD_ID);
    public static final DeferredRegister<Item> ITEMS =
            DeferredRegister.create(ForgeRegistries.ITEMS, MOD_ID);
    public static final DeferredRegister<EntityType<?>> ENTITY_TYPES =
            DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, MOD_ID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES =
            DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MOD_ID);
    public static final DeferredRegister<MenuType<?>> MENUS =
            DeferredRegister.create(ForgeRegistries.MENU_TYPES, MOD_ID);

    public static final RegistryObject<Block> DIVINE_ANVIL = BLOCKS.register(
            "divine_anvil",
            () -> new DivineAnvilBlock(Block.Properties.copy(Blocks.ANVIL).strength(5.0F)));
    public static final RegistryObject<Item> DIVINE_ANVIL_ITEM = ITEMS.register(
            "divine_anvil",
            () -> new BlockItem(DIVINE_ANVIL.get(), new Item.Properties()));
    public static final RegistryObject<EntityType<SparkSpriteEntity>> SPARK_SPRITE = ENTITY_TYPES.register(
            "spark_sprite", () -> EntityType.Builder.of(SparkSpriteEntity::new, MobCategory.CREATURE)
                    .sized(0.32F, 0.32F).clientTrackingRange(8).updateInterval(2).build(MOD_ID + ":spark_sprite"));
    public static final RegistryObject<BlockEntityType<com.forgegod.block.DivineAnvilBlockEntity>> DIVINE_ANVIL_ENTITY = BLOCK_ENTITIES.register(
            "divine_anvil", () -> BlockEntityType.Builder.of(com.forgegod.block.DivineAnvilBlockEntity::new, DIVINE_ANVIL.get()).build(null));
    public static final RegistryObject<MenuType<com.forgegod.menu.DivineAnvilMenu>> DIVINE_ANVIL_MENU = MENUS.register(
            "divine_anvil", () -> IForgeMenuType.create(com.forgegod.menu.DivineAnvilMenu::new));

    public static final DivineTrialService TRIALS = new DivineTrialService();

    public ForgeGodMod() {
        IEventBus modBus = FMLJavaModLoadingContext.get().getModEventBus();
        BLOCKS.register(modBus);
        ITEMS.register(modBus);
        ENTITY_TYPES.register(modBus);
        BLOCK_ENTITIES.register(modBus);
        MENUS.register(modBus);
        ForgeGodNetwork.register();
        modBus.addListener(this::onEntityAttributes);
        MinecraftForge.EVENT_BUS.register(this);
    }

    private void onEntityAttributes(EntityAttributeCreationEvent event) {
        event.put(SPARK_SPRITE.get(), SparkSpriteEntity.createAttributes().build());
    }

    @Mod.EventBusSubscriber(modid = MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
    public static final class ClientRegistration {
        @SubscribeEvent
        public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
            event.registerEntityRenderer(SPARK_SPRITE.get(), com.forgegod.client.SparkSpriteRenderer::new);
        }

        @SubscribeEvent
        public static void clientSetup(FMLClientSetupEvent event) {
            event.enqueueWork(() -> MenuScreens.register(DIVINE_ANVIL_MENU.get(), com.forgegod.client.DivineAnvilScreen::new));
        }

        @SubscribeEvent
        public static void registerKeyMappings(RegisterKeyMappingsEvent event) {
            event.register(com.forgegod.client.ForgeGodKeyMappings.SHOW_DIVINE_ATTRIBUTES);
        }
    }

    @Mod.EventBusSubscriber(modid = MOD_ID, bus = Mod.EventBusSubscriber.Bus.FORGE, value = Dist.CLIENT)
    public static final class ClientForgeEvents {
        @SubscribeEvent
        public static void onTitleScreenInit(ScreenEvent.Init.Post event) {
            if (!(event.getScreen() instanceof TitleScreen title)) return;
            event.addListener(net.minecraft.client.gui.components.Button.builder(
                            net.minecraft.network.chat.Component.literal("锻造之神 AI 设置"),
                            button -> net.minecraft.client.Minecraft.getInstance().setScreen(
                                    new com.forgegod.client.AiConfigScreen(title)))
                    .bounds(title.width / 2 - 100, title.height - 48, 200, 20).build());
        }

        @SubscribeEvent
        public static void onTooltip(ItemTooltipEvent event) {
            if (!ContractRuntime.isBound(event.getItemStack())) return;
            var contract = event.getItemStack().getTag().getCompound(ContractRuntime.CONTRACT_TAG);
            event.getToolTip().add(net.minecraft.network.chat.Component.literal(
                    "§d神赐契约：§f" + contract.getString("name")));
            if (!com.forgegod.client.ForgeGodKeyMappings.SHOW_DIVINE_ATTRIBUTES.isDown()) return;
            event.getToolTip().add(net.minecraft.network.chat.Component.literal(
                    "§7修订 " + contract.getInt("revision") + " | 连续命中 " + contract.getInt("hit_count")
                            + " 次（窗口 " + contract.getInt("hit_window") + " tick）"));
            event.getToolTip().add(net.minecraft.network.chat.Component.literal(
                    "§7火花小精灵 " + contract.getInt("familiar_count") + " 只 | 持续 "
                            + contract.getInt("familiar_lifetime") + " tick"));
            event.getToolTip().add(net.minecraft.network.chat.Component.literal(
                    "§7冷却 " + contract.getInt("cooldown") + " tick | 耐久代价 "
                            + contract.getInt("durability_cost")));
        }
    }

    @SubscribeEvent
    public void onRegisterCommands(RegisterCommandsEvent event) {
        ForgeGodCommands.register(event.getDispatcher());
    }

    @SubscribeEvent
    public void onLivingDamage(LivingDamageEvent event) {
        ContractRuntime.onLivingDamage(event);
    }

    @SubscribeEvent
    public void onPlayerTick(TickEvent.PlayerTickEvent event) {
        if (event.phase == TickEvent.Phase.END && !event.player.level().isClientSide) {
            ContractRuntime.tick(event.player);
        }
    }

}
