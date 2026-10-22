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
import { Bytes, doc, getDoc, increment, serverTimestamp, writeBatch } from 'firebase/firestore';

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
  if (v.$erhoehen !== undefined) return increment(v.$erhoehen);
  if (v.$geraetzeit) return new Date();
  if (v.$bytes) return Bytes.fromUint8Array(Uint8Array.from(Buffer.from(v.$bytes, 'hex')));
  return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, wert(x)]));
}

function abspielen({ uid, schreibvorgaenge }, { als = uid, ohne = [] } = {}) {
  const fs = env.authenticatedContext(als).firestore();
  const b = writeBatch(fs);
  for (const { art, pfad, daten } of schreibvorgaenge) {
    if (ohne.includes(pfad)) continue;
    if (art === 'update') b.update(doc(fs, pfad), wert(daten));
    else if (art === 'delete') b.delete(doc(fs, pfad));
    else b.set(doc(fs, pfad), wert(daten));
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

describe('Beitreten aus der App (UC-02)', () => {
  const kasse = fixture('kasse-erstellen.json');
  const batch = fixture('beitreten.json');
  // withSecurityRulesDisabled gibt den Wert des Callbacks nicht zurück.
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      daten = (await getDoc(doc(ctx.firestore(), pfad))).data();
    });
    return daten;
  }

  beforeEach(() => abspielen(kasse));

  test('wird angenommen, Anzahl in Kasse und Einladung zählt mit', async () => {
    await assertSucceeds(abspielen(batch));
    expect((await lesen('kassen/k2')).anzahlBierwarte).toBe(2);
    expect((await lesen('einladungen/K7Q2MXA93DWFT2HC8RNP')).anzahlBierwarte).toBe(2);
    expect((await lesen('kassen/k2/mitglieder/m2')).bierwartUid).toBe('neu');
  });

  test('ohne Portemonnaie abgelehnt', async () => {
    await assertFails(abspielen(batch, { ohne: ['kassen/k2/orte/neu'] }));
  });

  test('der Gründer tritt nicht noch einmal bei', async () => {
    await assertFails(abspielen(batch, { als: kasse.uid }));
  });
});

describe('Strichliste aus der App (STR-02 bis STR-06, BES-01, KAD-01)', () => {
  const kette = ['kasse-erstellen.json', 'sorte-anlegen.json', 'mitglied-anlegen.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      daten = (await getDoc(doc(ctx.firestore(), pfad))).data();
    });
    return daten;
  }

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Sorte und Mitglied sind angelegt', async () => {
    expect((await lesen('kassen/k2/sorten/s1')).bestand).toBe(0);
    expect((await lesen('kassen/k2/namen/tim richter')).mitgliedId).toBe('m3');
  });

  test('Strich offen und Storno: Saldo und Bestand wieder wie vorher', async () => {
    await assertSucceeds(abspielen(fixture('strich.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).saldoCents).toBe(150);
    expect((await lesen('kassen/k2/sorten/s1')).bestand).toBe(-1);

    await assertSucceeds(abspielen(fixture('storno-strich.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).saldoCents).toBe(0);
    expect((await lesen('kassen/k2/sorten/s1')).bestand).toBe(0);
  });

  test('ein Strich lässt sich nur einmal stornieren (STR-06)', async () => {
    await assertSucceeds(abspielen(fixture('strich.json')));
    await assertSucceeds(abspielen(fixture('storno-strich.json')));
    await assertFails(abspielen(fixture('storno-strich.json')));
  });

  test('Bar-Strich auf „Gäste“ und Storno: Portemonnaie wie vorher', async () => {
    await assertSucceeds(abspielen(fixture('strich-bar.json')));
    expect((await lesen('kassen/k2/orte/gruender')).standCents).toBe(150);

    await assertSucceeds(abspielen(fixture('storno-bar.json')));
    expect((await lesen('kassen/k2/orte/gruender')).standCents).toBe(0);
  });

  test('ein Fremder kann nicht buchen', async () => {
    await assertFails(abspielen(fixture('strich.json'), { als: 'fremd' }));
  });
});

describe('Kader aus der App (KAD-01, KAD-04, KAD-08, GEL-02, GEL-03, UI-09)', () => {
  const kette = ['kasse-erstellen.json', 'sorte-anlegen.json', 'mitglied-anlegen.json', 'strich.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      daten = (await getDoc(doc(ctx.firestore(), pfad))).data();
    });
    return daten;
  }

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Zahlung ins eigene Portemonnaie gleicht den Saldo aus', async () => {
    await assertSucceeds(abspielen(fixture('zahlung.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).saldoCents).toBe(0);
    expect((await lesen('kassen/k2/orte/gruender')).standCents).toBe(150);
  });

  test('Zahlung in die Kasse als Kassenwart', async () => {
    await assertSucceeds(abspielen(fixture('zahlung-kasse.json')));
    expect((await lesen('kassen/k2/orte/kasse')).standCents).toBe(5150);
  });

  test('Entfernen erst bei Saldo 0, dann wieder aufnehmen (KAD-04, KAD-08)', async () => {
    await assertFails(abspielen(fixture('mitglied-entfernen.json')));
    await assertSucceeds(abspielen(fixture('zahlung.json')));
    await assertSucceeds(abspielen(fixture('mitglied-entfernen.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).entfernt).toBe(true);
    await assertSucceeds(abspielen(fixture('mitglied-wiederaufnehmen.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).entfernt).toBe(false);
  });

  test('Mitglied ohne App umbenennen, alter Name wird frei', async () => {
    await assertSucceeds(abspielen(fixture('mitglied-umbenennen.json')));
    expect((await lesen('kassen/k2/mitglieder/m3')).name).toBe('Tim Richter-Berg');
    expect(await lesen('kassen/k2/namen/tim richter')).toBeUndefined();
  });

  test('Bierwart umbenennen, Stempel-Name zieht mit', async () => {
    await assertSucceeds(abspielen(fixture('bierwart-umbenennen.json')));
    expect((await lesen('kassen/k2/bierwarte/gruender')).name).toBe('Lena Koch-Meier');
  });
});

describe('Lager aus der App (BES-01 bis BES-06)', () => {
  const kette = ['kasse-erstellen.json', 'sorte-anlegen.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      daten = (await getDoc(doc(ctx.firestore(), pfad))).data();
    });
    return daten;
  }

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Einkauf aus dem Portemonnaie: Bestand hoch, Portemonnaie runter', async () => {
    await assertSucceeds(abspielen(fixture('einkauf.json')));
    expect((await lesen('kassen/k2/sorten/s1')).bestand).toBe(24);
    expect((await lesen('kassen/k2/orte/gruender')).standCents).toBe(-1890);
  });

  test('Einkauf aus der Kasse als Kassenwart', async () => {
    await assertSucceeds(abspielen(fixture('einkauf-kasse.json')));
    expect((await lesen('kassen/k2/orte/kasse')).standCents).toBe(5000 - 1890);
  });

  test('Preis ändern behält den alten als vorherigen (BES-02)', async () => {
    await assertSucceeds(abspielen(fixture('sorte-aendern.json')));
    const sorte = await lesen('kassen/k2/sorten/s1');
    expect([sorte.preisCents, sorte.vorherigerPreisCents]).toEqual([170, 150]);
  });

  test('Sorte ausblenden', async () => {
    await assertSucceeds(abspielen(fixture('sorte-ausblenden.json')));
    expect((await lesen('kassen/k2/sorten/s1')).aktiv).toBe(false);
  });

  test('Korrektur auf den gezählten Wert (BES-06)', async () => {
    await assertSucceeds(abspielen(fixture('bestand-korrektur.json')));
    expect((await lesen('kassen/k2/sorten/s1')).bestand).toBe(24);
  });

  test('Korrektur mit veralteter Differenz abgelehnt', async () => {
    await assertSucceeds(abspielen(fixture('einkauf.json')));
    await assertFails(abspielen(fixture('bestand-korrektur.json')));
  });
});


describe('Geld aus der App (GEL-04 bis GEL-06)', () => {
  const kette = ['kasse-erstellen.json', 'beitreten.json'].map(fixture);
  async function stand(ortId) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      daten = (await getDoc(doc(ctx.firestore(), `kassen/k2/orte/${ortId}`))).data();
    });
    return daten.standCents;
  }

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Übergabe in die Kasse und zurück', async () => {
    await assertSucceeds(abspielen(fixture('uebergabe.json')));
    expect([await stand('neu'), await stand('kasse')]).toEqual([-1200, 6200]);
    await assertSucceeds(abspielen(fixture('uebergabe-aus-kasse.json')));
    expect([await stand('neu'), await stand('kasse')]).toEqual([0, 5000]);
  });

  test('Auszahlung aus der Kasse, Einzahlung ins Portemonnaie', async () => {
    await assertSucceeds(abspielen(fixture('auszahlung-kasse.json')));
    expect(await stand('kasse')).toBe(2500);
    await assertSucceeds(abspielen(fixture('einzahlung.json')));
    expect(await stand('gruender')).toBe(2500);
  });

  test('Kassensturz setzt die Kasse auf den gezählten Betrag', async () => {
    await assertSucceeds(abspielen(fixture('kassensturz.json')));
    expect(await stand('kasse')).toBe(4950);
  });

  test('Kassensturz mit veralteter Differenz abgelehnt', async () => {
    await assertSucceeds(abspielen(fixture('auszahlung-kasse.json')));
    await assertFails(abspielen(fixture('kassensturz.json')));
  });

  test('Übergabe nur vom Kassenwart', async () => {
    const batch = fixture('uebergabe.json');
    const alsJonas = {
      uid: 'neu',
      schreibvorgaenge: batch.schreibvorgaenge.map((s) =>
        s.pfad.includes('/buchungen/')
          ? { ...s, daten: { ...s.daten, stempel: { ...s.daten.stempel, uid: 'neu', name: 'Jonas Weber' } } }
          : s),
    };
    await assertFails(abspielen(alsJonas));
  });
});
