// Tests der Security Rules für Stammdaten: Mitglieder, Namen, Sorten.
//   npm --prefix rules-tests run test:emulator
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

const K = 'kassen/k1';
const NAMEN = { anna: 'Anna Schulz', kw: 'Karl Wagner' };
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

const key = (name) => name.toLowerCase().trim().replace(/\s+/g, ' ');

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const set = (pfad, daten) => setDoc(doc(db, `${K}/${pfad}`), daten);
    await setDoc(doc(db, K), { name: 'FC Test', adminUid: 'kw', kassenwartUid: 'kw' });
    for (const [uid, name] of Object.entries(NAMEN)) {
      await set(`bierwarte/${uid}`, { mitgliedId: uid, name });
      await set(`mitglieder/${uid}`, { name, nameKey: key(name), istGast: false, bierwartUid: uid, entfernt: false, saldoCents: 0, letzteBuchungId: null });
      await set(`namen/${key(name)}`, { mitgliedId: uid });
    }
    const mitglied = (id, name, extra = {}) => Promise.all([
      set(`mitglieder/${id}`, { name, nameKey: key(name), istGast: false, bierwartUid: null, entfernt: false, saldoCents: 0, letzteBuchungId: null, ...extra }),
      set(`namen/${key(name)}`, { mitgliedId: id }),
    ]);
    await mitglied('jonas', 'Jonas Weber');
    await mitglied('schuldner', 'Tim Offen', { saldoCents: 450 });
    await mitglied('gaeste', 'Gäste', { istGast: true });
    await mitglied('weg', 'Paul Alt', { entfernt: true });
    await set('sorten/s0', { name: 'Bier 0,5', preisCents: 150, vorherigerPreisCents: null, aktiv: true, bestand: 10, letzteBuchungId: null, reihenfolge: 0 });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const stempel = (uid) => ({ uid, name: NAMEN[uid] ?? uid, am: serverTimestamp() });

// Ein Batch: Log-Buchung + Änderungen. aenderungen: [[art, pfad, daten], …], art = set | update | delete
function batch(uid, logId, log, aenderungen) {
  const fs = db(uid);
  const b = writeBatch(fs);
  b.set(doc(fs, `${K}/buchungen/${logId}`), { ...log, stempel: stempel(uid) });
  for (const [art, pfad, daten] of aenderungen) {
    const ref = doc(fs, `${K}/${pfad}`);
    if (art === 'set') b.set(ref, daten);
    else if (art === 'update') b.update(ref, daten);
    else b.delete(ref);
  }
  return b.commit();
}

async function lesen(pfad) {
  let daten;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(doc(ctx.firestore(), `${K}/${pfad}`));
    daten = snap.exists() ? snap.data() : undefined;
  });
  return daten;
}

const neuesMitglied = (name, { uid = 'anna', id = 'm1', nameKey = key(name), saldo = 0, mitIndex = true, ohneLog = false } = {}) => {
  const aenderungen = [
    ['set', `mitglieder/${id}`, { name, nameKey, istGast: false, bierwartUid: null, entfernt: false, saldoCents: saldo, letzteBuchungId: 'l1', angelegtAm: serverTimestamp() }],
  ];
  if (mitIndex) aenderungen.push(['set', `namen/${nameKey}`, { mitgliedId: id }]);
  if (ohneLog) {
    const fs = db(uid);
    const b = writeBatch(fs);
    for (const [, pfad, daten] of aenderungen) b.set(doc(fs, `${K}/${pfad}`), daten);
    return b.commit();
  }
  return batch(uid, 'l1', { typ: 'mitgliedAngelegt', mitgliedId: id, name }, aenderungen);
};

const umbenennen = (id, alt, neu, { uid = 'anna', mitBierwart = false, alterIndexBleibt = false } = {}) => {
  const aenderungen = [
    ['update', `mitglieder/${id}`, { name: neu, nameKey: key(neu), letzteBuchungId: 'l2' }],
    ['set', `namen/${key(neu)}`, { mitgliedId: id }],
  ];
  if (!alterIndexBleibt) aenderungen.push(['delete', `namen/${key(alt)}`]);
  if (mitBierwart) aenderungen.push(['update', `bierwarte/${id}`, { name: neu, letzteBuchungId: 'l2' }]);
  return batch(uid, 'l2', { typ: 'mitgliedUmbenannt', mitgliedId: id, nameAlt: alt, nameNeu: neu }, aenderungen);
};

const entfernen = (id, { typ = 'mitgliedEntfernt', entfernt = true } = {}) =>
  batch('anna', 'l3', { typ, mitgliedId: id }, [
    ['update', `mitglieder/${id}`, { entfernt, letzteBuchungId: 'l3' }],
  ]);

describe('Mitglied anlegen (KAD-01)', () => {
  test('mit Namensindex und Log-Eintrag', async () => {
    await assertSucceeds(neuesMitglied('Lena Koch'));
    expect((await lesen('namen/lena koch')).mitgliedId).toBe('m1');
  });

  test('vergebener Name wird abgelehnt (AUTH-07)', async () => {
    await assertFails(neuesMitglied('Jonas Weber'));
  });

  test('auch mit anderer Schreibweise (Normalisierung)', async () => {
    await assertFails(neuesMitglied('  jonas   WEBER '));
  });

  test('Name eines entfernten Mitglieds bleibt reserviert (KAD-08)', async () => {
    await assertFails(neuesMitglied('Paul Alt'));
  });

  test('ohne Namensindex abgelehnt', async () => {
    await assertFails(neuesMitglied('Lena Koch', { mitIndex: false }));
  });

  test('ohne Log-Eintrag abgelehnt (LOG-01)', async () => {
    await assertFails(neuesMitglied('Lena Koch', { ohneLog: true }));
  });

  test('neues Mitglied startet mit Saldo 0', async () => {
    await assertFails(neuesMitglied('Lena Koch', { saldo: -500 }));
  });

  test('falscher Schlüssel im Index abgelehnt', async () => {
    await assertFails(neuesMitglied('Lena Koch', { nameKey: 'jemand anders' }));
  });

  test('Nicht-Bierwart darf nicht anlegen', async () => {
    await assertFails(neuesMitglied('Lena Koch', { uid: 'fremd' }));
  });
});

describe('Mitglied umbenennen (KAD-01, UI-09)', () => {
  test('neuer Name im Index, alter frei', async () => {
    await assertSucceeds(umbenennen('jonas', 'Jonas Weber', 'Jonas Becker'));
    expect(await lesen('namen/jonas weber')).toBeUndefined();
    expect((await lesen('namen/jonas becker')).mitgliedId).toBe('jonas');
  });

  test('alter Name muss frei werden', async () => {
    await assertFails(umbenennen('jonas', 'Jonas Weber', 'Jonas Becker', { alterIndexBleibt: true }));
  });

  test('nicht auf einen vergebenen Namen', async () => {
    await assertFails(umbenennen('jonas', 'Jonas Weber', 'Anna Schulz'));
  });

  test('Bierwart: Name im Stempel zieht mit', async () => {
    await assertSucceeds(umbenennen('kw', 'Karl Wagner', 'Karl Wagenknecht', { uid: 'kw', mitBierwart: true }));
    expect((await lesen('bierwarte/kw')).name).toBe('Karl Wagenknecht');
  });

  test('Bierwart ohne Stempel-Namen abgelehnt', async () => {
    await assertFails(umbenennen('kw', 'Karl Wagner', 'Karl Wagenknecht', { uid: 'kw' }));
  });

  test('„Gäste“ lässt sich nicht umbenennen (KAD-03)', async () => {
    await assertFails(umbenennen('gaeste', 'Gäste', 'Besucher'));
  });

  test('entfernte Mitglieder lassen sich nicht umbenennen (KAD-08)', async () => {
    await assertFails(umbenennen('weg', 'Paul Alt', 'Paul Neu'));
  });

  // Nur Groß- und Kleinschreibung (offene Frage 26): gleicher Schlüssel,
  // der Index bleibt, wie er ist.
  const schreibweise = (id, alt, neu, { uid = 'anna', mitBierwart = false, mitIndex = false } = {}) => {
    const aenderungen = [['update', `mitglieder/${id}`, { name: neu, nameKey: key(neu), letzteBuchungId: 'l2' }]];
    if (mitIndex) aenderungen.push(['delete', `namen/${key(alt)}`]);
    if (mitBierwart) aenderungen.push(['update', `bierwarte/${id}`, { name: neu, letzteBuchungId: 'l2' }]);
    return batch(uid, 'l2', { typ: 'mitgliedUmbenannt', mitgliedId: id, nameAlt: alt, nameNeu: neu }, aenderungen);
  };

  test('nur die Schreibweise ändern, der Index bleibt', async () => {
    await assertSucceeds(schreibweise('jonas', 'Jonas Weber', 'Jonas WEBER'));
    expect((await lesen('mitglieder/jonas')).name).toBe('Jonas WEBER');
    expect((await lesen('namen/jonas weber')).mitgliedId).toBe('jonas');
  });

  test('Schreibweise eines Bierwarts: Stempel-Name zieht mit', async () => {
    await assertFails(schreibweise('kw', 'Karl Wagner', 'KARL Wagner', { uid: 'kw' }));
    await assertSucceeds(schreibweise('kw', 'Karl Wagner', 'KARL Wagner', { uid: 'kw', mitBierwart: true }));
  });

  test('bei gleicher Schreibweise wird nichts gebucht', async () => {
    await assertFails(schreibweise('jonas', 'Jonas Weber', 'Jonas Weber'));
  });

  test('der Index darf dabei nicht verschwinden', async () => {
    await assertFails(schreibweise('jonas', 'Jonas Weber', 'Jonas WEBER', { mitIndex: true }));
  });

  test('auch bei „Gäste“ und entfernten nicht', async () => {
    await assertFails(schreibweise('gaeste', 'Gäste', 'GÄSTE'));
    await assertFails(schreibweise('weg', 'Paul Alt', 'Paul ALT'));
  });

  test('Namensindex fremder Mitglieder lässt sich nicht löschen', async () => {
    const fs = db('anna');
    await assertFails(writeBatch(fs).delete(doc(fs, `${K}/namen/jonas weber`)).commit());
  });
});

describe('Mitglied entfernen und wieder aufnehmen (KAD-04, KAD-08)', () => {
  test('bei Saldo 0', async () => {
    await assertSucceeds(entfernen('jonas'));
    expect((await lesen('mitglieder/jonas')).entfernt).toBe(true);
    expect((await lesen('namen/jonas weber')).mitgliedId).toBe('jonas');
  });

  test('nicht mit offenem Betrag', async () => {
    await assertFails(entfernen('schuldner'));
  });

  test('nicht „Gäste“', async () => {
    await assertFails(entfernen('gaeste'));
  });

  test('nicht aktive Bierwarte (KAD-02)', async () => {
    await assertFails(entfernen('anna'));
  });

  test('wieder aufnehmen', async () => {
    await assertSucceeds(entfernen('weg', { typ: 'mitgliedWiederaufgenommen', entfernt: false }));
    expect((await lesen('mitglieder/weg')).entfernt).toBe(false);
  });

  test('Log-Typ muss zur Änderung passen', async () => {
    await assertFails(entfernen('jonas', { typ: 'mitgliedWiederaufgenommen' }));
  });
});

describe('Sorten (BES-01, BES-02)', () => {
  const neueSorte = ({ bestand = 0, preis = 180 } = {}) =>
    batch('anna', 'l4', { typ: 'sorteAngelegt', sorteId: 's1', name: 'Fanta 0,5', preisCents: preis, aktiv: true }, [
      ['set', 'sorten/s1', { name: 'Fanta 0,5', preisCents: preis, vorherigerPreisCents: null, aktiv: true, bestand, letzteBuchungId: 'l4', reihenfolge: 1 }],
    ]);
  const aendern = ({ name = 'Bier 0,5', preis = 150, vorheriger = null, aktiv = true, logPreis = preis } = {}) =>
    batch('anna', 'l5', { typ: 'sorteGeaendert', sorteId: 's0', name, preisCents: logPreis, aktiv }, [
      ['update', 'sorten/s0', { name, preisCents: preis, vorherigerPreisCents: vorheriger, aktiv, letzteBuchungId: 'l5' }],
    ]);

  test('anlegen mit Bestand 0', async () => {
    await assertSucceeds(neueSorte());
  });

  test('anlegen mit Bestand ≠ 0 abgelehnt', async () => {
    await assertFails(neueSorte({ bestand: 24 }));
  });

  test('Preis muss ganze Cent sein', async () => {
    await assertFails(neueSorte({ preis: 1.8 }));
  });

  test('Preis ändern: alter Preis wird vorheriger Preis', async () => {
    await assertSucceeds(aendern({ preis: 170, vorheriger: 150 }));
    expect((await lesen('sorten/s0')).vorherigerPreisCents).toBe(150);
  });

  test('Preis ändern ohne vorherigen Preis abgelehnt', async () => {
    await assertFails(aendern({ preis: 170, vorheriger: null }));
  });

  test('Log muss die neuen Werte nennen', async () => {
    await assertFails(aendern({ preis: 170, vorheriger: 150, logPreis: 150 }));
  });

  test('ausblenden', async () => {
    await assertSucceeds(aendern({ aktiv: false }));
  });

  test('Bestand lässt sich nicht über Stammdaten ändern', async () => {
    await assertFails(batch('anna', 'l6', { typ: 'sorteGeaendert', sorteId: 's0', name: 'Bier 0,5', preisCents: 150, aktiv: true }, [
      ['update', 'sorten/s0', { bestand: 100, letzteBuchungId: 'l6' }],
    ]));
  });

  test('Reihenfolge ohne Log', async () => {
    await assertSucceeds(updateDoc(doc(db('anna'), `${K}/sorten/s0`), { reihenfolge: 5 }));
  });
});
