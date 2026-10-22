// Tests der Security Rules für die Admin-Funktionen: Link erneuern, Bierwart
// entfernen, Rollen, Umbenennen, Wiederherstellung, Code erneuern, Auflösen.
//   npm --prefix rules-tests run test:emulator
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Bytes,
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  writeBatch,
} from 'firebase/firestore';

const K = 'kassen/k1';
const CODE = 'einladung-aktuell-0001';
const NEUER_CODE = 'einladung-neu-000002';
const RCODE = 'K7QM3XRA9DWFT2HC';
const RNEU = 'ABCD1234EFGH5678';
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
const gestern = () => Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000);
const sha256 = (code) => createHash('sha256').update(code, 'utf8').digest();
const hashHex = (code) => sha256(code).toString('hex');
const hashBytes = (code) => Bytes.fromUint8Array(sha256(code));

const pfadVon = (pfad) => (pfad.startsWith('/') ? pfad.slice(1) : `${K}/${pfad}`);
const ref = (fs, pfad) => doc(fs, pfadVon(pfad));

// Kasse k1: kw ist Admin und Kassenwart, anna Bierwartin mit 12,50 € im
// Portemonnaie, jonas ohne App.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const set = (pfad, daten) => setDoc(ref(db, pfad), daten);
    await set('/' + K, {
      name: 'FC Test', adminUid: 'kw', kassenwartUid: 'kw', einladungCode: CODE, anzahlBierwarte: 2,
      wiederherstellungHash: hashBytes(RCODE), leerSeit: null, aufgeloest: false, erstelltAm: gestern(), letzteBuchungId: null,
    });
    await set(`/einladungen/${CODE}`, { kasseId: 'k1', kassenName: 'FC Test', anzahlBierwarte: 2, erstelltAm: gestern(), ersetzt: false });
    await set(`/wiederherstellung/${hashHex(RCODE)}`, { kasseId: 'k1' });
    const mitglied = (id, name, extra = {}) => Promise.all([
      set(`mitglieder/${id}`, { name, nameKey: key(name), istGast: false, bierwartUid: null, entfernt: false, saldoCents: 0, letzteBuchungId: null, ...extra }),
      set(`namen/${key(name)}`, { mitgliedId: id }),
    ]);
    for (const [uid, name] of Object.entries(NAMEN)) {
      await set(`bierwarte/${uid}`, { mitgliedId: uid, name, einladungCode: null, letzteBuchungId: null });
      await mitglied(uid, name, { bierwartUid: uid });
      await set(`/users/${uid}`, { kasseId: 'k1' });
    }
    await set('orte/kasse', { art: 'kasse', uid: null, name: 'Kasse', standCents: 10000, ehemalig: false, letzteBuchungId: null });
    await set('orte/anna', { art: 'portemonnaie', uid: 'anna', name: NAMEN.anna, standCents: 1250, ehemalig: false, letzteBuchungId: null });
    await set('orte/kw', { art: 'portemonnaie', uid: 'kw', name: NAMEN.kw, standCents: 0, ehemalig: false, letzteBuchungId: null });
    await mitglied('jonas', 'Jonas Weber');
    await mitglied('gaeste', 'Gäste', { istGast: true });
    await set('buchungen/b0', { typ: 'mitgliedAngelegt', mitgliedId: 'jonas', name: 'Jonas Weber', stempel: { uid: 'kw', name: NAMEN.kw, am: gestern() } });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();

// Ein Batch: Log-Buchung + Änderungen. aenderungen: [[art, pfad, daten], …],
// art = set | update | delete; Pfade mit „/“ sind absolut, sonst unter k1.
function batch(uid, logId, log, aenderungen, { name = NAMEN[uid] } = {}) {
  const fs = db(uid);
  const b = writeBatch(fs);
  b.set(doc(fs, `${K}/buchungen/${logId}`), { ...log, stempel: { uid, name, am: serverTimestamp(), geraetAm: new Date() } });
  for (const [art, pfad, daten] of aenderungen) {
    if (art === 'set') b.set(ref(fs, pfad), daten);
    else if (art === 'update') b.update(ref(fs, pfad), daten);
    else b.delete(ref(fs, pfad));
  }
  return b.commit();
}

async function lesen(pfad) {
  let daten;
  await env.withSecurityRulesDisabled(async (ctx) => {
    const snap = await getDoc(ref(ctx.firestore(), pfad));
    daten = snap.exists() ? snap.data() : undefined;
  });
  return daten;
}

const aendern = (pfad, daten) => env.withSecurityRulesDisabled((ctx) =>
  setDoc(ref(ctx.firestore(), pfad), daten, { merge: true }));

const ohne = (liste, weg) => liste.filter(([, pfad]) => !weg.includes(pfad));

// Neuer Link, alter ersetzt (ADM-01); anzahl ist die Anzahl nach dem Batch.
const linkAenderungen = ({ anzahl = 2, kasse = {} } = {}) => [
  ['update', '/' + K, { einladungCode: NEUER_CODE, letzteBuchungId: 'l1', ...kasse }],
  ['set', `/einladungen/${NEUER_CODE}`, { kasseId: 'k1', kassenName: 'FC Test', anzahlBierwarte: anzahl, erstelltAm: serverTimestamp(), ersetzt: false }],
  ['update', `/einladungen/${CODE}`, { ersetzt: true }],
];

describe('Link erneuern (ADM-01, UC-07)', () => {
  const erneuern = ({ uid = 'kw', anzahl = 2, weglassen = [] } = {}) =>
    batch(uid, 'l1', { typ: 'einladungErneuert' }, ohne(linkAenderungen({ anzahl }), weglassen));

  test('neuer Link, alter ersetzt', async () => {
    await assertSucceeds(erneuern());
    expect((await lesen('/' + K)).einladungCode).toBe(NEUER_CODE);
    expect((await lesen(`/einladungen/${CODE}`)).ersetzt).toBe(true);
  });

  test('alter Link muss ersetzt werden', async () => {
    await assertFails(erneuern({ weglassen: [`/einladungen/${CODE}`] }));
  });

  test('neue Einladung zeigt die richtige Anzahl (AUTH-05)', async () => {
    await assertFails(erneuern({ anzahl: 5 }));
  });

  test('nur der Admin', async () => {
    await assertFails(erneuern({ uid: 'anna' }));
  });

  test('der aktuelle Link lässt sich nicht als ersetzt markieren', async () => {
    const fs = db('anna');
    await assertFails(writeBatch(fs).update(doc(fs, `einladungen/${CODE}`), { ersetzt: true }).commit());
  });
});

describe('Bierwart entfernen (ADM-02, UC-08, GEL-08)', () => {
  const entfernen = ({ uid = 'kw', wer = 'anna', ehemalig = true, mitLink = true } = {}) => {
    const aenderungen = [
      ['delete', `bierwarte/${wer}`],
      ['update', `orte/${wer}`, { ehemalig, letzteBuchungId: 'l1' }],
      ...(mitLink
        ? linkAenderungen({ anzahl: 1, kasse: { anzahlBierwarte: increment(-1) } })
        : [['update', '/' + K, { anzahlBierwarte: increment(-1), letzteBuchungId: 'l1' }],
           ['update', `/einladungen/${CODE}`, { anzahlBierwarte: increment(-1) }]]),
    ];
    return batch(uid, 'l1', { typ: 'bierwartEntfernt', uid: wer, mitgliedId: wer }, aenderungen);
  };

  test('Zugang weg, bleibt Mitglied, Portemonnaie ehemalig', async () => {
    await assertSucceeds(entfernen());
    expect(await lesen('bierwarte/anna')).toBeUndefined();
    expect((await lesen('mitglieder/anna')).entfernt).toBe(false);
    expect((await lesen('orte/anna'))).toMatchObject({ ehemalig: true, standCents: 1250 });
    expect((await lesen('/' + K)).anzahlBierwarte).toBe(1);
  });

  test('Link wird dabei erneuert', async () => {
    await assertFails(entfernen({ mitLink: false }));
  });

  test('Portemonnaie muss ehemalig werden', async () => {
    await assertFails(entfernen({ ehemalig: false }));
  });

  test('nicht den Kassenwart', async () => {
    await aendern('/' + K, { kassenwartUid: 'anna' });
    await assertFails(entfernen());
  });

  test('nur der Admin', async () => {
    await assertFails(entfernen({ uid: 'anna', wer: 'kw' }));
  });
});

describe('Rolle übertragen (ADM-03, UC-09)', () => {
  const uebertragen = ({ uid = 'kw', rolle = 'kassenwart', von = 'kw', nach = 'anna', logVon = von } = {}) =>
    batch(uid, 'l1', { typ: 'rolleGeaendert', rolle, vonUid: logVon, nachUid: nach }, [
      ['update', '/' + K, { [`${rolle}Uid`]: nach, letzteBuchungId: 'l1' }],
    ]);

  test('Kassenwart bestimmen', async () => {
    await assertSucceeds(uebertragen());
    expect((await lesen('/' + K)).kassenwartUid).toBe('anna');
  });

  test('Admin-Rolle übergeben', async () => {
    await assertSucceeds(uebertragen({ rolle: 'admin' }));
    expect((await lesen('/' + K)).adminUid).toBe('anna');
  });

  test('nur an aktive Bierwarte', async () => {
    await assertFails(uebertragen({ nach: 'jonas' }));
  });

  test('nur der Admin', async () => {
    await assertFails(uebertragen({ uid: 'anna', nach: 'anna' }));
  });

  test('Log nennt den bisherigen Inhaber', async () => {
    await assertFails(uebertragen({ logVon: 'jonas' }));
  });

  test('keine anderen Rollen', async () => {
    await assertFails(uebertragen({ rolle: 'chef' }));
  });
});

describe('Kasse umbenennen (ADM-04)', () => {
  const umbenennen = ({ uid = 'kw', mitEinladung = true } = {}) => {
    const aenderungen = [['update', '/' + K, { name: 'FC Neu', letzteBuchungId: 'l1' }]];
    if (mitEinladung) aenderungen.push(['update', `/einladungen/${CODE}`, { kassenName: 'FC Neu' }]);
    return batch(uid, 'l1', { typ: 'kasseUmbenannt', nameAlt: 'FC Test', nameNeu: 'FC Neu' }, aenderungen);
  };

  test('Name in Kasse und Einladung', async () => {
    await assertSucceeds(umbenennen());
    expect((await lesen(`/einladungen/${CODE}`)).kassenName).toBe('FC Neu');
  });

  test('Einladung muss mitziehen (AUTH-05)', async () => {
    await assertFails(umbenennen({ mitEinladung: false }));
  });

  test('nur der Admin', async () => {
    await assertFails(umbenennen({ uid: 'anna' }));
  });
});

describe('Wiederherstellungscode erneuern (ADM-08)', () => {
  const erneuern = ({ uid = 'kw', hex = hashHex(RNEU), altLoeschen = true } = {}) => {
    const aenderungen = [
      ['update', '/' + K, { wiederherstellungHash: hashBytes(RNEU), letzteBuchungId: 'l1' }],
      ['set', `/wiederherstellung/${hex}`, { kasseId: 'k1' }],
    ];
    if (altLoeschen) aenderungen.push(['delete', `/wiederherstellung/${hashHex(RCODE)}`]);
    return batch(uid, 'l1', { typ: 'wiederherstellungscodeErneuert' }, aenderungen);
  };

  test('neuer Code, alter ungültig', async () => {
    await assertSucceeds(erneuern());
    expect(await lesen(`/wiederherstellung/${hashHex(RCODE)}`)).toBeUndefined();
  });

  test('altes Dokument muss weg', async () => {
    await assertFails(erneuern({ altLoeschen: false }));
  });

  test('neues Dokument muss zum Hash passen', async () => {
    await assertFails(erneuern({ hex: hashHex('FALSCH0000000000') }));
  });

  test('nur der Admin', async () => {
    await assertFails(erneuern({ uid: 'anna' }));
  });

  test('aktuelles Dokument lässt sich nicht löschen', async () => {
    await assertFails(deleteDoc(doc(db('fremd'), `wiederherstellung/${hashHex(RCODE)}`)));
  });
});

// Neuer Code und Wechsel des Dokuments, wie bei jeder Wiederherstellung.
const codeWechsel = (kasse) => [
  ['update', '/' + K, { wiederherstellungHash: hashBytes(RNEU), letzteBuchungId: 'l1', ...kasse }],
  ['set', `/wiederherstellung/${hashHex(RNEU)}`, { kasseId: 'k1' }],
  ['delete', `/wiederherstellung/${hashHex(RCODE)}`],
];

describe('Admin wiederherstellen als Bierwart (ADM-06, UC-04)', () => {
  const wiederherstellen = ({ uid = 'anna', nachweis = RCODE, kassenwart = 'kw' } = {}) =>
    batch(uid, 'l1', { typ: 'adminWiederhergestellt', nachweis }, codeWechsel({ adminUid: uid, kassenwartUid: kassenwart }));

  test('mit dem Code wird man Admin, der bisherige bleibt Bierwart', async () => {
    await assertSucceeds(wiederherstellen());
    expect((await lesen('/' + K)).adminUid).toBe('anna');
    expect(await lesen('bierwarte/kw')).toBeDefined();
  });

  test('falscher Code abgelehnt', async () => {
    await assertFails(wiederherstellen({ nachweis: RNEU }));
  });

  test('nur die normalisierte Form', async () => {
    await assertFails(wiederherstellen({ nachweis: 'K7QM-3XRA-9DWF-T2HC' }));
  });

  test('aktiver Kassenwart bleibt', async () => {
    await assertFails(wiederherstellen({ kassenwart: 'anna' }));
  });

  test('verwaister Kassenwart geht mit (offene Frage 25)', async () => {
    await aendern('/' + K, { kassenwartUid: 'weg' });
    await assertFails(wiederherstellen());
    await assertSucceeds(wiederherstellen({ kassenwart: 'anna' }));
  });
});

describe('Admin wiederherstellen ohne Bierwart-Eintrag (ADM-06, UC-03)', () => {
  // „neu“ übernimmt Karl (Admin und Kassenwart), dessen Gerät weg ist.
  const uebernehmen = ({ nachweis = RCODE, mitglied = 'kw', name = NAMEN.kw, ehemalig = true } = {}) =>
    batch('neu', 'l1', { typ: 'adminWiederhergestellt', nachweis, mitgliedId: mitglied, alteUid: mitglied, neueUid: 'neu' }, [
      ...codeWechsel({ adminUid: 'neu', kassenwartUid: 'neu' }),
      ['update', `mitglieder/${mitglied}`, { bierwartUid: 'neu', entfernt: false, letzteBuchungId: 'l1' }],
      ['set', 'bierwarte/neu', { mitgliedId: mitglied, name, beigetretenAm: serverTimestamp(), einladungCode: null, letzteBuchungId: 'l1' }],
      ['delete', `bierwarte/${mitglied}`],
      ['update', `orte/${mitglied}`, { ehemalig, letzteBuchungId: 'l1' }],
      ['set', 'orte/neu', { art: 'portemonnaie', uid: 'neu', name, standCents: 0, ehemalig: false, letzteBuchungId: 'l1' }],
      ['set', '/users/neu', { kasseId: 'k1' }],
    ], { name });
  const neuesMitglied = ({ name = 'Lena Koch' } = {}) =>
    batch('neu', 'l1', { typ: 'adminWiederhergestellt', nachweis: RCODE, mitgliedId: 'm1', alteUid: null, neueUid: 'neu' }, [
      ...codeWechsel({ adminUid: 'neu', anzahlBierwarte: increment(1) }),
      ['update', `/einladungen/${CODE}`, { anzahlBierwarte: increment(1) }],
      ['set', 'mitglieder/m1', { name, nameKey: key(name), istGast: false, bierwartUid: 'neu', entfernt: false, saldoCents: 0, letzteBuchungId: 'l1', angelegtAm: serverTimestamp() }],
      ['set', `namen/${key(name)}`, { mitgliedId: 'm1' }],
      ['set', 'bierwarte/neu', { mitgliedId: 'm1', name, beigetretenAm: serverTimestamp(), einladungCode: null, letzteBuchungId: 'l1' }],
      ['set', 'orte/neu', { art: 'portemonnaie', uid: 'neu', name, standCents: 0, ehemalig: false, letzteBuchungId: 'l1' }],
      ['set', '/users/neu', { kasseId: 'k1' }],
    ], { name });

  test('Name, Rollen und Zugang gehen über, altes Portemonnaie ehemalig', async () => {
    await assertSucceeds(uebernehmen());
    const kasse = await lesen('/' + K);
    expect([kasse.adminUid, kasse.kassenwartUid, kasse.anzahlBierwarte]).toEqual(['neu', 'neu', 2]);
    expect(await lesen('bierwarte/kw')).toBeUndefined();
    expect((await lesen('orte/kw')).ehemalig).toBe(true);
  });

  test('altes Portemonnaie muss ehemalig werden (GEL-08)', async () => {
    await assertFails(uebernehmen({ ehemalig: false }));
  });

  test('ohne gültigen Code abgelehnt', async () => {
    await assertFails(uebernehmen({ nachweis: RNEU }));
  });

  test('nicht „Gäste“ (KAD-03)', async () => {
    await assertFails(batch('neu', 'l1', { typ: 'adminWiederhergestellt', nachweis: RCODE, mitgliedId: 'gaeste', alteUid: null, neueUid: 'neu' }, [
      ...codeWechsel({ adminUid: 'neu', anzahlBierwarte: increment(1) }),
      ['update', `/einladungen/${CODE}`, { anzahlBierwarte: increment(1) }],
      ['update', 'mitglieder/gaeste', { bierwartUid: 'neu', entfernt: false, letzteBuchungId: 'l1' }],
      ['set', 'bierwarte/neu', { mitgliedId: 'gaeste', name: 'Gäste', beigetretenAm: serverTimestamp(), einladungCode: null, letzteBuchungId: 'l1' }],
      ['set', 'orte/neu', { art: 'portemonnaie', uid: 'neu', name: 'Gäste', standCents: 0, ehemalig: false, letzteBuchungId: 'l1' }],
      ['set', '/users/neu', { kasseId: 'k1' }],
    ], { name: 'Gäste' }));
  });

  test('als neues Mitglied', async () => {
    await assertSucceeds(neuesMitglied());
    expect((await lesen('/' + K)).anzahlBierwarte).toBe(3);
    expect((await lesen('/' + K)).kassenwartUid).toBe('kw');
  });

  test('neues Mitglied nur mit freiem Namen', async () => {
    await assertFails(neuesMitglied({ name: 'Jonas Weber' }));
  });

  test('nicht in einer aufgelösten Kasse', async () => {
    await aendern('/' + K, { aufgeloest: true });
    await assertFails(uebernehmen());
  });
});

describe('Nachweis für die Wiederherstellung (ADM-06, UC-03, ADR-0010)', () => {
  // „neu“ ist kein Bierwart und kennt nur den Code.
  const nachweisen = ({ uid = 'neu', nachweis = RCODE, felder = {} } = {}) =>
    setDoc(doc(db(uid), `${K}/wiederherstellungen/${uid}`), { nachweis, angelegtAm: serverTimestamp(), ...felder });
  const lesenAls = (uid, pfad) => getDoc(ref(db(uid), pfad));

  test('ohne Nachweis darf ein Fremder nichts lesen', async () => {
    await assertFails(lesenAls('neu', '/' + K));
    await assertFails(lesenAls('neu', 'mitglieder/jonas'));
  });

  test('mit gültigem Code: Kasse, Mitglieder, Bierwarte und Orte lesbar', async () => {
    await assertSucceeds(nachweisen());
    for (const pfad of ['/' + K, 'mitglieder/jonas', 'bierwarte/kw', 'orte/kw']) {
      await assertSucceeds(lesenAls('neu', pfad));
    }
  });

  test('falscher Code oder nicht normalisiert abgelehnt', async () => {
    await assertFails(nachweisen({ nachweis: RNEU }));
    await assertFails(nachweisen({ nachweis: 'K7QM-3XRA-9DWF-T2HC' }));
  });

  test('nur für die eigene UID und ohne weitere Felder', async () => {
    await assertFails(setDoc(doc(db('neu'), `${K}/wiederherstellungen/anna`), { nachweis: RCODE, angelegtAm: serverTimestamp() }));
    await assertFails(nachweisen({ felder: { extra: 1 } }));
  });

  test('den Nachweis lesen nur der Inhaber, nicht die Bierwarte', async () => {
    await assertSucceeds(nachweisen());
    await assertSucceeds(lesenAls('neu', 'wiederherstellungen/neu'));
    await assertFails(lesenAls('anna', 'wiederherstellungen/neu'));
  });

  test('nach einem neuen Code gilt der Nachweis nicht mehr', async () => {
    await assertSucceeds(nachweisen());
    await aendern('/' + K, { wiederherstellungHash: hashBytes(RNEU) });
    await assertFails(lesenAls('neu', '/' + K));
  });

  test('nicht in einer aufgelösten Kasse', async () => {
    await aendern('/' + K, { aufgeloest: true });
    await assertFails(nachweisen());
  });

  test('der Inhaber löscht ihn, ein anderer nicht', async () => {
    await assertSucceeds(nachweisen());
    await assertFails(deleteDoc(ref(db('anna'), 'wiederherstellungen/neu')));
    await assertSucceeds(deleteDoc(ref(db('neu'), 'wiederherstellungen/neu')));
  });

  test('beim Auflösen löscht der Admin auch Nachweise', async () => {
    await assertSucceeds(nachweisen());
    await aendern('/' + K, { aufgeloest: true });
    const q = await getDocs(collection(db('kw'), `${K}/wiederherstellungen`));
    expect(q.size).toBe(1);
    await assertSucceeds(deleteDoc(ref(db('kw'), 'wiederherstellungen/neu')));
  });
});

describe('Auflösen (ADM-05, UC-10)', () => {
  const aufloesen = ({ uid = 'kw', bestaetigung = 'FC Test' } = {}) =>
    batch(uid, 'l1', { typ: 'kasseAufgeloest' }, [
      ['update', '/' + K, { aufgeloest: true, aufloesenBestaetigung: bestaetigung, letzteBuchungId: 'l1' }],
    ]);

  test('nach Abtippen des Namens; danach sieht nur der Admin die Kasse', async () => {
    await assertSucceeds(aufloesen());
    await assertFails(getDoc(doc(db('anna'), `${K}/mitglieder/jonas`)));
    await assertSucceeds(getDoc(doc(db('kw'), `${K}/mitglieder/jonas`)));
  });

  test('falsche Bestätigung abgelehnt', async () => {
    await assertFails(aufloesen({ bestaetigung: 'FC Tst' }));
  });

  test('nur der Admin', async () => {
    await assertFails(aufloesen({ uid: 'anna' }));
  });

  test('danach keine Buchungen mehr', async () => {
    await assertSucceeds(aufloesen());
    await assertFails(batch('kw', 'l2', { typ: 'einzahlung', ortId: 'kw', betragCents: 100, grund: 'Spende' }, [
      ['update', 'orte/kw', { standCents: increment(100), letzteBuchungId: 'l2' }],
    ]));
  });

  test('danach löscht der Admin alles', async () => {
    await assertSucceeds(aufloesen());
    const fs = db('kw');
    for (const pfad of ['buchungen/b0', 'buchungen/l1', 'mitglieder/jonas', 'namen/jonas weber', 'orte/anna', 'bierwarte/anna', 'bierwarte/kw']) {
      await assertSucceeds(deleteDoc(ref(fs, pfad)));
    }
    const b = writeBatch(fs);
    for (const pfad of ['/' + K, `/einladungen/${CODE}`, `/wiederherstellung/${hashHex(RCODE)}`]) b.delete(ref(fs, pfad));
    await assertSucceeds(b.commit());
    await assertSucceeds(deleteDoc(doc(fs, 'users/kw')));
  });

  test('andere Bierwarte löschen nichts', async () => {
    await assertSucceeds(aufloesen());
    await assertFails(deleteDoc(ref(db('anna'), 'buchungen/b0')));
  });

  test('vorher lässt sich nichts löschen (LOG-02)', async () => {
    await assertFails(deleteDoc(ref(db('kw'), 'buchungen/b0')));
    await assertFails(deleteDoc(ref(db('kw'), '/' + K)));
  });
});
