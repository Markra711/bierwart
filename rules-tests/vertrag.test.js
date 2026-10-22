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
import { Bytes, collection, doc, getDoc, getDocs, increment, serverTimestamp, setDoc, writeBatch } from 'firebase/firestore';

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

describe('Verwaltung aus der App (ADM-01 bis ADM-04)', () => {
  const kette = ['kasse-erstellen.json', 'beitreten.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), pfad));
      daten = snap.exists() ? snap.data() : undefined;
    });
    return daten;
  }
  const ALT = 'K7Q2MXA93DWFT2HC8RNP';
  const NEU = 'N3W7C0DE4X5Y6Z8A9B1C';

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Link erneuern: neuer gilt, alter ersetzt', async () => {
    await assertSucceeds(abspielen(fixture('link-erneuern.json')));
    expect((await lesen('kassen/k2')).einladungCode).toBe(NEU);
    expect((await lesen(`einladungen/${ALT}`)).ersetzt).toBe(true);
    expect((await lesen(`einladungen/${NEU}`)).anzahlBierwarte).toBe(2);
  });

  test('Bierwart entfernen: bleibt Mitglied, Portemonnaie ehemalig, neuer Link', async () => {
    await assertSucceeds(abspielen(fixture('bierwart-entfernen.json')));
    expect(await lesen('kassen/k2/bierwarte/neu')).toBeUndefined();
    expect((await lesen('kassen/k2/mitglieder/m2')).entfernt).toBe(false);
    expect((await lesen('kassen/k2/orte/neu')).ehemalig).toBe(true);
    expect((await lesen('kassen/k2')).anzahlBierwarte).toBe(1);
    expect((await lesen(`einladungen/${NEU}`)).anzahlBierwarte).toBe(1);
  });

  test('Kassenwart bestimmen und Admin übergeben', async () => {
    await assertSucceeds(abspielen(fixture('rolle-kassenwart.json')));
    await assertSucceeds(abspielen(fixture('rolle-admin.json')));
    const kasse = await lesen('kassen/k2');
    expect([kasse.adminUid, kasse.kassenwartUid]).toEqual(['neu', 'neu']);
  });

  test('nach der Übergabe ist Lena nicht mehr Admin', async () => {
    await assertSucceeds(abspielen(fixture('rolle-admin.json')));
    await assertFails(abspielen(fixture('link-erneuern.json')));
  });

  test('Kasse umbenennen: Name in Kasse und Einladung', async () => {
    await assertSucceeds(abspielen(fixture('kasse-umbenennen.json')));
    expect((await lesen('kassen/k2')).name).toBe('SV Umbenannt');
    expect((await lesen(`einladungen/${ALT}`)).kassenName).toBe('SV Umbenannt');
  });

  // Derselbe Batch mit Jonas im Stempel: abgelehnt wegen der Rolle, nicht
  // wegen eines fremden Stempels.
  const alsJonas = ({ schreibvorgaenge }) => ({
    uid: 'neu',
    schreibvorgaenge: schreibvorgaenge.map((s) =>
      s.pfad.includes('/buchungen/')
        ? { ...s, daten: { ...s.daten, stempel: { ...s.daten.stempel, uid: 'neu', name: 'Jonas Weber' } } }
        : s),
  });

  test('nur der Admin verwaltet', async () => {
    for (const name of ['link-erneuern.json', 'kasse-umbenennen.json', 'rolle-kassenwart.json']) {
      await assertFails(abspielen(alsJonas(fixture(name))));
    }
  });

  test('als Admin mit Jonas im Stempel geht es (Gegenstück)', async () => {
    await assertSucceeds(abspielen(fixture('rolle-admin.json')));
    await assertSucceeds(abspielen(alsJonas(fixture('kasse-umbenennen.json'))));
  });
});

describe('Austreten und Auflösen aus der App (UC-05, AUTH-09, ADM-05)', () => {
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), pfad));
      daten = snap.exists() ? snap.data() : undefined;
    });
    return daten;
  }
  const setzen = (pfad, daten) => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), pfad), daten, { merge: true }));
  const ALT = 'K7Q2MXA93DWFT2HC8RNP';

  beforeEach(async () => {
    await assertSucceeds(abspielen(fixture('kasse-erstellen.json')));
  });

  test('Jonas tritt aus: Zugang weg, bleibt Mitglied, Anzahl sinkt', async () => {
    await assertSucceeds(abspielen(fixture('beitreten.json')));
    await assertSucceeds(abspielen(fixture('austreten.json')));
    expect(await lesen('kassen/k2/bierwarte/neu')).toBeUndefined();
    expect(await lesen('users/neu')).toBeUndefined();
    expect((await lesen('kassen/k2/mitglieder/m2')).entfernt).toBe(false);
    expect((await lesen('kassen/k2')).anzahlBierwarte).toBe(1);
    expect((await lesen(`einladungen/${ALT}`)).anzahlBierwarte).toBe(1);
  });

  test('nicht mit Geld im Portemonnaie (AUTH-09)', async () => {
    await assertSucceeds(abspielen(fixture('beitreten.json')));
    await setzen('kassen/k2/orte/neu', { standCents: 100 });
    await assertFails(abspielen(fixture('austreten.json')));
  });

  test('die Letzte geht mit ihren Rollen, die Kasse ist leer', async () => {
    await assertSucceeds(abspielen(fixture('austreten-letzter.json')));
    const kasse = await lesen('kassen/k2');
    expect(kasse.anzahlBierwarte).toBe(0);
    expect(kasse.leerSeit).toBeTruthy();
  });

  test('Auflösen, eine volle Portion löschen, dann der Schluss', async () => {
    await assertSucceeds(abspielen(fixture('beitreten.json')));
    await assertSucceeds(abspielen(fixture('aufloesen.json')));
    // In einem Batch, einzeln dauert es auf der CI zu lange.
    await env.withSecurityRulesDisabled(async (ctx) => {
      const b = writeBatch(ctx.firestore());
      for (let i = 0; i < 200; i++) {
        b.set(doc(ctx.firestore(), `kassen/k2/buchungen/x${String(i).padStart(3, '0')}`), { typ: 'test' });
      }
      await b.commit();
    });
    await assertSucceeds(abspielen(fixture('loeschen-portion.json')));
    expect(await lesen('kassen/k2/buchungen/x199')).toBeUndefined();

    // Den Rest löscht die App genauso portionsweise; hier in einem Batch.
    const rest = [];
    await env.withSecurityRulesDisabled(async (ctx) => {
      for (const s of ['buchungen', 'mitglieder', 'namen', 'sorten', 'orte', 'uebernahmen', 'bierwarte']) {
        const q = await getDocs(collection(ctx.firestore(), `kassen/k2/${s}`));
        for (const d of q.docs) if (d.ref.path !== 'kassen/k2/bierwarte/gruender') rest.push(d.ref.path);
      }
    });
    await assertSucceeds(abspielen({
      uid: 'gruender',
      schreibvorgaenge: rest.map((pfad) => ({ art: 'delete', pfad, daten: {} })),
    }));

    await assertSucceeds(abspielen(fixture('aufloesen-schluss.json')));
    expect(await lesen('kassen/k2')).toBeUndefined();
    expect(await lesen(`einladungen/${ALT}`)).toBeUndefined();
    expect(await lesen('users/gruender')).toBeUndefined();
  }, 30000);

  test('ohne Auflösen löscht niemand etwas', async () => {
    await assertFails(abspielen(fixture('loeschen-portion.json')));
    await assertFails(abspielen(fixture('aufloesen-schluss.json')));
  });
});

describe('Wiederherstellungscode aus der App (ADM-06, ADM-08)', () => {
  const kette = ['kasse-erstellen.json', 'beitreten.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), pfad));
      daten = snap.exists() ? snap.data() : undefined;
    });
    return daten;
  }
  const ALT = 'be105af532593b07b857dbbb0012fc12a939efb515656aa111fc0120993c0609';

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('Admin erneuert den Code, der alte ist weg', async () => {
    await assertSucceeds(abspielen(fixture('code-erneuern.json')));
    expect(await lesen(`wiederherstellung/${ALT}`)).toBeUndefined();
  });

  test('Jonas wird mit dem Code Admin, Lena bleibt Kassenwart', async () => {
    await assertSucceeds(abspielen(fixture('admin-wiederherstellen.json')));
    const kasse = await lesen('kassen/k2');
    expect([kasse.adminUid, kasse.kassenwartUid]).toEqual(['neu', 'gruender']);
    expect(await lesen('kassen/k2/bierwarte/gruender')).toBeDefined();
  });

  test('nach dem Erneuern gilt der alte Code nicht mehr', async () => {
    await assertSucceeds(abspielen(fixture('code-erneuern.json')));
    await assertFails(abspielen(fixture('admin-wiederherstellen.json')));
  });

  test('Code erneuern nur als Admin', async () => {
    const { schreibvorgaenge } = fixture('code-erneuern.json');
    await assertFails(abspielen({
      uid: 'neu',
      schreibvorgaenge: schreibvorgaenge.map((s) =>
        s.pfad.includes('/buchungen/')
          ? { ...s, daten: { ...s.daten, stempel: { ...s.daten.stempel, uid: 'neu', name: 'Jonas Weber' } } }
          : s),
    }));
  });
});

describe('Wiederherstellung aus dem Onboarding (ADM-06, UC-03, UC-04, ADR-0010)', () => {
  const kette = ['kasse-erstellen.json', 'beitreten.json'].map(fixture);
  async function lesen(pfad) {
    let daten;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(doc(ctx.firestore(), pfad));
      daten = snap.exists() ? snap.data() : undefined;
    });
    return daten;
  }
  const fs = () => env.authenticatedContext('zurueck').firestore();

  beforeEach(async () => {
    for (const batch of kette) await assertSucceeds(abspielen(batch));
  });

  test('ohne Nachweis sieht das neue Gerät nichts, mit Nachweis alles Nötige', async () => {
    await assertFails(getDoc(doc(fs(), 'kassen/k2')));
    await assertSucceeds(abspielen(fixture('nachweis.json')));
    await assertSucceeds(getDoc(doc(fs(), 'kassen/k2')));
    for (const s of ['mitglieder', 'bierwarte', 'orte', 'namen']) {
      await assertSucceeds(getDocs(collection(fs(), `kassen/k2/${s}`)));
    }
  });

  test('als Lena zurück: Admin und Kassenwart, alter Zugang weg', async () => {
    await assertSucceeds(abspielen(fixture('nachweis.json')));
    await assertSucceeds(abspielen(fixture('wiederherstellen-mitglied.json')));
    const kasse = await lesen('kassen/k2');
    expect([kasse.adminUid, kasse.kassenwartUid, kasse.anzahlBierwarte]).toEqual(['zurueck', 'zurueck', 2]);
    expect(await lesen('kassen/k2/bierwarte/gruender')).toBeUndefined();
    expect((await lesen('kassen/k2/orte/gruender')).ehemalig).toBe(true);
    expect((await lesen('users/zurueck')).kasseId).toBe('k2');
    expect(await lesen('kassen/k2/wiederherstellungen/zurueck')).toBeUndefined();
  });

  test('als neues Mitglied: Admin, Lena bleibt Kassenwart', async () => {
    await assertSucceeds(abspielen(fixture('nachweis.json')));
    await assertSucceeds(abspielen(fixture('wiederherstellen-neu.json')));
    const kasse = await lesen('kassen/k2');
    expect([kasse.adminUid, kasse.kassenwartUid, kasse.anzahlBierwarte]).toEqual(['zurueck', 'gruender', 3]);
    expect((await lesen('einladungen/K7Q2MXA93DWFT2HC8RNP')).anzahlBierwarte).toBe(3);
  });

  test('danach gilt der alte Code nicht mehr, auch nicht als Nachweis', async () => {
    await assertSucceeds(abspielen(fixture('nachweis.json')));
    await assertSucceeds(abspielen(fixture('wiederherstellen-neu.json')));
    const fremd = env.authenticatedContext('fremd').firestore();
    await assertFails(setDoc(doc(fremd, 'kassen/k2/wiederherstellungen/fremd'), {
      nachweis: 'ABCD1234EFGH5678', angelegtAm: serverTimestamp(),
    }));
  });
});
