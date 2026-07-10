/**
 * One-off script: generate bundled Future Self narrator voice preview clips.
 *
 * Usage (from functions/):
 *   npx ts-node scripts/generate_narration_previews.ts
 *
 * Requires application-default credentials:
 *   gcloud auth application-default login
 */

import { TextToSpeechClient } from '@google-cloud/text-to-speech';
import * as fs from 'fs';
import * as path from 'path';

const PROJECT_ID = 'mindsetforge-ai';

const PREVIEW_TEXT =
  'I am here. The moment is real and already familiar. I breathe slowly, and ease settles in.';

const NARRATION_SPEAKING_RATE = 0.8;

const VOICES = [
  { id: 'en-US-Chirp3-HD-Aoede', file: 'future_self_voice_aoede.mp3' },
  { id: 'en-US-Chirp3-HD-Despina', file: 'future_self_voice_despina.mp3' },
  { id: 'en-US-Chirp3-HD-Charon', file: 'future_self_voice_charon.mp3' },
  { id: 'en-US-Chirp3-HD-Enceladus', file: 'future_self_voice_enceladus.mp3' },
] as const;

async function main(): Promise<void> {
  const client = new TextToSpeechClient({
    projectId: PROJECT_ID,
    quotaProjectId: PROJECT_ID,
  });
  const outDir = path.resolve(__dirname, '../../assets/audio');
  fs.mkdirSync(outDir, { recursive: true });

  for (const voice of VOICES) {
    const [response] = await client.synthesizeSpeech({
      input: { text: PREVIEW_TEXT },
      voice: { languageCode: 'en-US', name: voice.id },
      audioConfig: {
        audioEncoding: 'MP3',
        speakingRate: NARRATION_SPEAKING_RATE,
      },
    });

    const audio = response.audioContent;
    if (!audio) {
      throw new Error(`TTS returned no audio for ${voice.id}`);
    }

    const outPath = path.join(outDir, voice.file);
    fs.writeFileSync(outPath, Buffer.from(audio as Uint8Array));
    console.log(`Wrote ${outPath}`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
