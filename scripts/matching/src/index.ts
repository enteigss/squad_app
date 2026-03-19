import { program } from 'commander';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import path from 'path';
import { loadConfig } from './config.js';
import { initializeFirebase } from './firebase/client.js';
import { fetchEligibleUsers, usersForMatching, getBlockedPairs } from './firebase/users.js';
import { pushMatchesToFirestore } from './firebase/matches.js';
import { generateMatches } from './claude/matcher.js';
import type { MatchOutputFile } from './types.js';
import { log } from './utils/logger.js';

program
  .name('linkup-matcher')
  .description('Generate friend matches using Claude AI')
  .option('-d, --dry-run', 'Fetch users only, no API calls')
  .option('-p, --push', 'Push matches from JSON file to Firebase')
  .option('-i, --input <file>', 'Input JSON file for --push mode')
  .option('-b, --batch-size <n>', 'Max users per batch', '50')
  .option('-s, --source <collection>', 'Source collection for users', 'users')
  .allowUnknownOption(false)
  .parse(process.argv);

const opts = program.opts();

async function main() {
  try {
    const config = loadConfig();
    initializeFirebase(config);

    // ===== PUSH MODE: Upload reviewed matches =====
    if (opts.push) {
      if (!opts.input) {
        log.error('--push requires --input <file>');
        process.exit(1);
      }

      const inputPath = path.resolve(opts.input);
      if (!existsSync(inputPath)) {
        log.error(`File not found: ${inputPath}`);
        process.exit(1);
      }

      log.info(`Reading matches from: ${inputPath}`);
      const outputFile: MatchOutputFile = JSON.parse(
        readFileSync(inputPath, 'utf-8')
      );

      log.info(`Found ${outputFile.matches.length} matches to push`);
      await pushMatchesToFirestore(outputFile);

      log.success('Done! Matches pushed to Firestore.');
      return;
    }

    // ===== MATCH MODE: Generate new matches =====
    const sourceCollection = opts.source || 'users';
    log.info(`Using source collection: ${sourceCollection}`);
    const users = await fetchEligibleUsers(sourceCollection);
    const batchSize = parseInt(opts.batchSize, 10);

    if (users.length === 0) {
      log.warn('No eligible users found');
      return;
    }

    if (users.length > batchSize) {
      log.warn(`Found ${users.length} users, limiting to ${batchSize}`);
    }

    const usersToMatch = users.slice(0, batchSize);
    const usersForApi = usersForMatching(usersToMatch);
    const blockedPairs = getBlockedPairs(usersToMatch);

    // Dry run: just show users
    if (opts.dryRun) {
      log.info('DRY RUN - Users that would be matched:');
      for (const u of usersForApi) {
        log.info(`  ${u.id}:`);
        log.dim(`    Gender: ${u.gender || '?'} | Looking for: ${u.genderPreference || 'any'}`);
        log.dim(`    Year: ${u.graduationYear || '?'} | Location: ${u.location || '?'}`);
        log.dim(`    Fun: ${u.funActivities || '(not answered)'}`);
        log.dim(`    Talk about: ${u.talkAboutForever || '(not answered)'}`);
        log.dim(`    Ratings: deep=${u.activityRatings.deepConversations} outdoors=${u.activityRatings.outdoors} chill=${u.activityRatings.chilling} games=${u.activityRatings.competitiveGames} meals=${u.activityRatings.meals} nights=${u.activityRatings.nightsOut}`);
      }
      return;
    }

    // Call Claude API
    const result = await generateMatches(config, usersForApi, blockedPairs);

    // Build output file
    const outputFile: MatchOutputFile = {
      generatedAt: new Date().toISOString(),
      environment: config.firebaseProject,
      totalUsers: usersForApi.length,
      totalMatches: result.matches.length,
      promptFile: config.matchingPromptPath,
      users: usersForApi,
      matches: result.matches,
      unmatchedUserIds: result.unmatchedUserIds || [],
    };

    // Write to output directory
    const outputDir = path.resolve('output');
    if (!existsSync(outputDir)) {
      mkdirSync(outputDir, { recursive: true });
    }

    const timestamp = new Date().toISOString().split('T')[0];
    const outputPath = path.join(outputDir, `matches-${timestamp}.json`);

    writeFileSync(outputPath, JSON.stringify(outputFile, null, 2));
    log.success(`Matches written to: ${outputPath}`);

    // Show summary
    log.info('\n--- Match Summary ---');
    for (const match of result.matches) {
      log.info(`  ${match.memberIds.join(' + ')}`);
      log.dim(`    Why: ${match.reasoning}`);
    }

    if (outputFile.unmatchedUserIds.length > 0) {
      log.warn(`\n${outputFile.unmatchedUserIds.length} users could not be matched`);
    }

    log.info(`\nReview the file, then run:`);
    log.dim(`  npm run push -- --input ${outputPath}`);

  } catch (err) {
    log.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  }
}

main();
