import { z } from 'zod';

export class AssistantModelUnavailable extends Error {}

const responseSchema = z.object({
  choices: z.array(z.object({
    message: z.object({ content: z.string() }),
  })).min(1),
});

export interface AssistantModelProvider {
  complete(input: { systemPrompt: string; userText: string }): Promise<string>;
}

/**
 * Calls DeepSeek or any OpenAI-compatible relay from the server only. The
 * secret is read from the server process environment and never enters the
 * database or client.
 */
export class DeepSeekCompatibleProvider implements AssistantModelProvider {
  constructor(
    private readonly apiKey = process.env.DEEPSEEK_API_KEY,
    private readonly baseUrl = process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com',
    private readonly model = process.env.DEEPSEEK_MODEL ?? 'deepseek-chat',
  ) {}

  async complete(input: { systemPrompt: string; userText: string }): Promise<string> {
    if (!this.apiKey) throw new AssistantModelUnavailable('DeepSeek API key is not configured');
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 30_000);
    try {
      const response = await fetch(`${this.baseUrl.replace(/\/$/, '')}/chat/completions`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: this.model,
          messages: [
            { role: 'system', content: input.systemPrompt },
            { role: 'user', content: input.userText },
          ],
          temperature: 0.2,
          max_tokens: 512,
          stream: false,
        }),
        signal: controller.signal,
      });
      if (!response.ok) throw new AssistantModelUnavailable(`Model provider returned HTTP ${response.status}`);
      const payload = responseSchema.safeParse(await response.json());
      if (!payload.success) throw new AssistantModelUnavailable('Model provider returned an invalid response');
      const choice = payload.data.choices.at(0);
      if (!choice) throw new AssistantModelUnavailable('Model provider returned an empty response');
      const content = choice.message.content.trim();
      if (!content) throw new AssistantModelUnavailable('Model provider returned an empty response');
      return content.slice(0, 4000);
    } catch (error) {
      if (error instanceof AssistantModelUnavailable) throw error;
      throw new AssistantModelUnavailable('Model provider request failed');
    } finally {
      clearTimeout(timeout);
    }
  }
}
