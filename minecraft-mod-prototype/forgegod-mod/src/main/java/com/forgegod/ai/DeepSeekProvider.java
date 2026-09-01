package com.forgegod.ai;

import com.forgegod.blueprint.EffectBlueprint;
import com.forgegod.weapon.WeaponFacts;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;

/** DeepSeek-compatible OpenAI chat-completions client. The key is resolved from environment or local client config. */
public final class DeepSeekProvider implements AiProvider {
    private static final String DEFAULT_ENDPOINT = "https://api.deepseek.com/chat/completions";
    private final HttpClient client;
    private final String endpoint;
    private final String model;

    public DeepSeekProvider() {
        this(envOr("DEEPSEEK_API_ENDPOINT", DEFAULT_ENDPOINT),
                envOr("DEEPSEEK_MODEL", "deepseek-chat"));
    }

    DeepSeekProvider(String endpoint, String model) {
        this.endpoint = endpoint;
        this.model = model;
        this.client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    @Override
    public String name() {
        return "DeepSeek (cloud)";
    }

    @Override
    public CompletableFuture<AiProposalSet> propose(WeaponFacts facts, String playerIntent) {
        String prompt = basePrompt(facts)
                + "\n玩家的锻造申请：\n" + bounded(playerIntent, 1000)
                + "\n请只提出一套最适合当前武器的可执行候选。contract_id 必须使用 UUID 字符串。";
        return request(prompt, facts, null);
    }

    @Override
    public CompletableFuture<AiProposalSet> revise(WeaponFacts facts, EffectBlueprint previous,
                                                      String feedback, String trace) {
        String prompt = basePrompt(facts)
                + "\n上一版候选：\n" + previous.toJson()
                + "\n演示追踪：\n" + bounded(trace, 1800)
                + "\n玩家反馈：\n" + bounded(feedback, 1000)
                + "\n请只给出一套针对反馈的修改方案，优先保持稳定并保留材料事实一致性。";
        return request(prompt, facts, previous);
    }

    private CompletableFuture<AiProposalSet> request(String prompt, WeaponFacts facts,
                                                         EffectBlueprint previous) {
        String apiKey = ApiKeyStore.resolve();
        if (apiKey.isBlank()) {
            return CompletableFuture.failedFuture(new IllegalStateException(
                    "DEEPSEEK_API_KEY is not configured"));
        }
        JsonObject body = new JsonObject();
        body.addProperty("model", model);
        body.addProperty("temperature", 0.85);
        body.addProperty("max_tokens", 1200);
        JsonArray messages = new JsonArray();
        JsonObject system = new JsonObject();
        system.addProperty("role", "system");
        system.addProperty("content", systemPrompt());
        messages.add(system);
        JsonObject user = new JsonObject();
        user.addProperty("role", "user");
        user.addProperty("content", prompt);
        messages.add(user);
        body.add("messages", messages);

        HttpRequest request = HttpRequest.newBuilder(URI.create(endpoint))
                .timeout(Duration.ofSeconds(45))
                .header("Authorization", "Bearer " + apiKey)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body.toString()))
                .build();
        return client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                .thenApply(response -> {
                    if (response.statusCode() < 200 || response.statusCode() >= 300) {
                        throw new CompletionException(new IOException("DeepSeek HTTP " + response.statusCode()));
                    }
                    return parseCandidate(response.body(), facts, previous);
                });
    }

    private static AiProposalSet parseCandidate(String body, WeaponFacts facts, EffectBlueprint previous) {
        JsonObject response = JsonParser.parseString(body).getAsJsonObject();
        JsonArray choices = response.getAsJsonArray("choices");
        if (choices == null || choices.isEmpty()) {
            throw new CompletionException(new IOException("DeepSeek returned no choices"));
        }
        String content = choices.get(0).getAsJsonObject().getAsJsonObject("message")
                .get("content").getAsString();
        content = stripMarkdown(content);
        JsonObject json = JsonParser.parseString(content).getAsJsonObject();
        java.util.ArrayList<EffectBlueprint> proposals = new java.util.ArrayList<>();
        java.util.ArrayList<String> explanations = new java.util.ArrayList<>();
        JsonArray proposalArray = json.has("proposals") && json.get("proposals").isJsonArray()
                ? json.getAsJsonArray("proposals") : null;
        if (proposalArray != null) {
            for (JsonElement element : proposalArray) {
                if (element.isJsonObject()) proposals.add(EffectBlueprint.fromJson(element.getAsJsonObject(),
                        previous == null ? proposals.size() + 1 : previous.revision() + proposals.size() + 1,
                        facts.factIds().stream().findFirst().orElse("item.unknown")));
            }
        } else {
            proposals.add(EffectBlueprint.fromJson(json,
                    previous == null ? 1 : previous.revision() + 1,
                    facts.factIds().stream().findFirst().orElse("item.unknown")));
        }
        if (proposals.isEmpty()) throw new CompletionException(new IOException("DeepSeek returned no proposals"));
        EffectBlueprint base = previous == null ? proposals.get(0) : previous;
        for (int i = 0; i < proposals.size(); i++) {
            EffectBlueprint proposal = proposals.get(i);
            proposals.set(i, proposal.withContract(base.contractId(), previous == null ? i + 1 : previous.revision() + i + 1));
        }
        if (json.has("explanations") && json.get("explanations").isJsonArray()) {
            for (JsonElement element : json.getAsJsonArray("explanations")) if (element.isJsonPrimitive()) explanations.add(element.getAsString());
        }
        if (explanations.isEmpty()) explanations.add("以材料亲和性为基础换取可控的火花小精灵效果。");
        return new AiProposalSet(java.util.List.of(proposals.get(0)), java.util.List.of(explanations.get(0)));
    }

    private static String stripMarkdown(String value) {
        String text = value == null ? "" : value.trim();
        if (text.startsWith("```")) {
            int first = text.indexOf('\n');
            int last = text.lastIndexOf("```");
            if (first >= 0 && last > first) text = text.substring(first + 1, last).trim();
        }
        return text;
    }

    private static String systemPrompt() {
        return "你是西幻世界的锻造之神。只返回一个 JSON 对象，不要 Markdown，不要解释。顶层字段必须是 proposals（只包含一个对象）和 explanations（只包含一个字符串）；方案对象字段必须是 "
                + "blueprint_version,name,fantasy,cited_fact_ids,hit_count,hit_window_ticks,familiar_count,"
                + "familiar_lifetime_ticks,cooldown_ticks,durability_cost。所有数值必须在预算内：hit_count 1-8，"
                + "hit_window_ticks 20-1200，familiar_count 1-4，familiar_lifetime_ticks 20-240，"
                + "cooldown_ticks 40-2400，durability_cost 1-12。不得生成命令、函数、任意 NBT、方块破坏、"
                + "永久实体或现实世界科技名词。效果必须能由火花小精灵、标记、有限冷却和武器耐久解释。";
    }

    private static String basePrompt(WeaponFacts facts) {
        return "武器事实卡片：" + facts.toJson() + "\n";
    }

    private static String bounded(String value, int max) {
        if (value == null) return "";
        return value.length() <= max ? value : value.substring(0, max);
    }

    private static String envOr(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }
}
