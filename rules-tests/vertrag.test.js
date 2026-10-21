// Batches, wie die App sie schreibt, gegen die Rules. Die Dateien in
// fixtures/ erzeugen Dart-Tests aus dem App-Code (siehe dort), so prüfen
// beide Seiten denselben Batch.
//   npm --prefix rules-tests run test:emulator
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Bytes, doc, getDoc, serverTimestamp, writeBatch } from 'firebase/firestore';

let env;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-bierwart',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

afterAll(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const fixture = (name) => JSON.parse(readFileSync(new URL(`fixtures/${name}`, import.meta.url), 'utf8'));

// Platzhalter aus den Dart-Tests in Firestore-Werte.
function wert(v) {
  if (v === null || typeof v !== 'object') return v;
  if (v.$serverzeit) return serverTimestamp();
  if (v.$geraetzeit) return new Date();
  if (v.$bytes) return Bytes.fromUint8Array(Uint8Array.from(Buffer.from(v.$bytes, 'hex')));
  return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, wert(x)]));
}

function abspielen({ uid, schreibvorgaenge }, { als = uid, ohne = [] } = {}) {
  const fs = env.authenticatedContext(als).firestore();
  const b = writeBatch(fs);
  for (const { pfad, daten } of schreibvorgaenge) {
    if (!ohne.includes(pfad)) b.set(doc(fs, pfad), wert(daten));
  }
  return b.commit();
}

describe('Kasse erstellen aus der App (UC-01)', () => {
  const batch = fixture('kasse-erstellen.json');

  test('wird angenommen', async () => {
    await assertSucceeds(abspielen(batch));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const kasse = await getDoc(doc(ctx.firestore(), 'kassen/k2'));
      expect(kasse.data().adminUid).toBe(batch.uid);
    });
  });

  test('von einer anderen UID abgelehnt', async () => {
    await assertFails(abspielen(batch, { als: 'jemand' }));
  });

  test('unvollständig abgelehnt', async () => {
    await assertFails(abspielen(batch, { ohne: ['kassen/k2/mitglieder/gaeste'] }));
  });
});
