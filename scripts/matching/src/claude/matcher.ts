import Anthropic from '@anthropic-ai/sdk';
import { readFileSync } from 'fs';
import { ClaudeMatchResponseSchema, MatchResultSchema, type ClaudeMatchResponse, type UserForMatching } from '../types.js';
import type { AppConfig } from '../config.js';
import { log } from '../utils/logger.js';

export async function generateMatches(
  config: AppConfig,
  users: UserForMatching[],
  blockedPairs: string[][]
): Promise<ClaudeMatchResponse> {
  const client = new Anthropic({ apiKey: config.anthropicApiKey });

  // Load the user-provided prompt
  const systemPrompt = readFileSync(config.matchingPromptPath, 'utf-8');

  log.info(`Sending ${users.length} users to Claude API...`);
  log.info(`Using model: ${config.claudeModel}`);
  if (config.enableExtendedThinking) {
    log.info(`Extended thinking enabled (budget: ${config.thinkingBudget} tokens)`);
  }

  // Build the user message with context
  const userMessage = JSON.stringify({
    users,
    blockedPairs, // Pairs that cannot be matched together
    instructions: 'Return JSON only. Match users into pairs or small groups.',
  }, null, 2);

  // Build request options
  const requestOptions: Anthropic.MessageCreateParams = {
    model: config.claudeModel,
    max_tokens: config.enableExtendedThinking ? config.thinkingBudget + 8192 : 8192,
    messages: [{ role: 'user', content: userMessage }],
  };

  // Add thinking parameter for extended thinking, otherwise use system prompt
  if (config.enableExtendedThinking) {
    requestOptions.thinking = {
      type: 'enabled',
      budget_tokens: config.thinkingBudget,
    };
    // With extended thinking, system must be a string (not array)
    requestOptions.system = systemPrompt;
  } else {
    requestOptions.system = systemPrompt;
  }

  const response = await client.messages.create(requestOptions);

  // Log thinking summary if extended thinking was used
  const thinkingBlock = response.content.find((c) => c.type === 'thinking');
  if (thinkingBlock && thinkingBlock.type === 'thinking') {
    const thinkingLength = thinkingBlock.thinking.length;
    log.info(`Extended thinking used: ~${Math.round(thinkingLength / 4)} tokens`);
  }

  // Extract text content from response
  const textContent = response.content.find((c) => c.type === 'text');
  if (!textContent || textContent.type !== 'text') {
    throw new Error('No text response from Claude');
  }

  // Parse JSON from response (handle markdown code blocks)
  let jsonStr = textContent.text.trim();
  if (jsonStr.startsWith('```json')) {
    jsonStr = jsonStr.slice(7);
  }
  if (jsonStr.startsWith('```')) {
    jsonStr = jsonStr.slice(3);
  }
  if (jsonStr.endsWith('```')) {
    jsonStr = jsonStr.slice(0, -3);
  }

  const parsed = JSON.parse(jsonStr.trim());

  // Validate with detailed error reporting
  const result = ClaudeMatchResponseSchema.safeParse(parsed);

  if (!result.success) {
    log.warn('Claude returned some invalid data, attempting to filter...');
    log.dim(JSON.stringify(parsed, null, 2));

    // Try to salvage valid matches
    if (parsed.matches && Array.isArray(parsed.matches)) {
      const validMatches = parsed.matches.filter((m: unknown) => {
        const matchResult = MatchResultSchema.safeParse(m);
        if (!matchResult.success) {
          log.warn(`Skipping invalid match: ${JSON.stringify(m)}`);
        }
        return matchResult.success;
      });

      if (validMatches.length > 0) {
        log.success(`Salvaged ${validMatches.length} valid matches`);
        return {
          matches: validMatches.map((m: unknown) => MatchResultSchema.parse(m)),
          unmatchedUserIds: parsed.unmatchedUserIds || [],
        };
      }
    }

    log.error('Could not salvage any valid matches');
    throw new Error(JSON.stringify(result.error.issues, null, 2));
  }

  log.success(`Claude generated ${result.data.matches.length} matches`);

  return result.data;
}
