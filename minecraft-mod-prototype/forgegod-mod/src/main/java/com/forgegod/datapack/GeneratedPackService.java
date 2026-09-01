package com.forgegod.datapack;

import com.forgegod.compiler.TetraCompiler.CompiledCandidate;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.storage.LevelResource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.concurrent.CompletableFuture;

/** Writes only generated resources under the current world's datapacks directory. */
public final class GeneratedPackService {
    private static final String PACK_ID = "forgegod-generated";
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    public Path write(MinecraftServer server, CompiledCandidate candidate) throws IOException {
        Path datapacks = server.getWorldPath(LevelResource.ROOT).resolve("datapacks");
        Path pack = datapacks.resolve(PACK_ID);
        Path staging = datapacks.resolve("." + PACK_ID + ".staging-" + candidate.blueprint().contractId());
        Files.createDirectories(staging);
        try {
            JsonObject metadata = new JsonObject();
            JsonObject packData = new JsonObject();
            packData.addProperty("pack_format", 15);
            packData.addProperty("description", "ForgeGod candidate " + candidate.blueprint().revision());
            metadata.add("pack", packData);
            writeJson(staging.resolve("pack.mcmeta"), metadata);
            for (var entry : candidate.files().entrySet()) {
                writeJson(staging.resolve(entry.getKey()), entry.getValue());
            }
            JsonObject manifest = candidate.blueprint().toJson();
            writeJson(staging.resolve("data/forgegod/manifest/candidate_" + candidate.blueprint().revision() + ".json"), manifest);

            Files.createDirectories(datapacks);
            if (Files.exists(pack)) {
                Path backup = datapacks.resolve("." + PACK_ID + ".previous");
                deleteTree(backup);
                Files.move(pack, backup, StandardCopyOption.REPLACE_EXISTING);
            }
            Files.move(staging, pack, StandardCopyOption.REPLACE_EXISTING);
            return pack;
        } catch (IOException failure) {
            deleteTree(staging);
            throw failure;
        }
    }

    public CompletableFuture<Void> enableAndReload(MinecraftServer server) {
        String packKey = "file/" + PACK_ID;
        var repository = server.getPackRepository();
        repository.reload();
        repository.addPack(packKey);
        var selected = new ArrayList<>(repository.getSelectedIds());
        if (!selected.contains(packKey)) {
            selected.add(packKey);
        }
        repository.setSelected(selected);
        return server.reloadResources(selected);
    }

    private static void writeJson(Path path, JsonElement object) throws IOException {
        Files.createDirectories(path.getParent());
        Files.writeString(path, GSON.toJson(object), StandardCharsets.UTF_8);
    }

    private static void deleteTree(Path root) throws IOException {
        if (!Files.exists(root)) {
            return;
        }
        try (var paths = Files.walk(root)) {
            paths.sorted(java.util.Comparator.reverseOrder()).forEach(path -> {
                try {
                    Files.deleteIfExists(path);
                } catch (IOException e) {
                    throw new java.io.UncheckedIOException(e);
                }
            });
        } catch (java.io.UncheckedIOException e) {
            throw e.getCause();
        }
    }
}
