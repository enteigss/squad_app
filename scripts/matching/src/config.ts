import { config } from 'dotenv';
import { existsSync } from 'fs';
import path from 'path';

config(); // Load .env file

export interface AppConfig {
  anthropicApiKey: string;
  firebaseServiceAccountPath: string;
  firebaseProject: string;
  matchingPromptPath: string;
  claudeModel: string;
  enableExtendedThinking: boolean;
  thinkingBudget: number;
}

export function loadConfig(): AppConfig {
  const anthropicApiKey = process.env.ANTHROPIC_API_KEY;
  if (!anthropicApiKey) {
    throw new Error('ANTHROPIC_API_KEY is required in .env');
  }

  const firebaseServiceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH || './service-account.json';
  if (!existsSync(firebaseServiceAccountPath)) {
    throw new Error(
      `Firebase service account not found at: ${firebaseServiceAccountPath}`
    );
  }

  const firebaseProject =
    process.env.FIREBASE_PROJECT || 'linkup-bu-test-environment';

  const matchingPromptPath =
    process.env.MATCHING_PROMPT_PATH || './prompts/matching-prompt.txt';
  if (!existsSync(matchingPromptPath)) {
    throw new Error(`Matching prompt file not found at: ${matchingPromptPath}`);
  }

  const claudeModel = process.env.CLAUDE_MODEL || 'claude-sonnet-4-20250514';

  const enableExtendedThinking = process.env.ENABLE_EXTENDED_THINKING === 'true';
  const thinkingBudget = parseInt(process.env.THINKING_BUDGET || '10000', 10);

  return {
    anthropicApiKey,
    firebaseServiceAccountPath: path.resolve(firebaseServiceAccountPath),
    firebaseProject,
    matchingPromptPath: path.resolve(matchingPromptPath),
    claudeModel,
    enableExtendedThinking,
    thinkingBudget,
  };
}
