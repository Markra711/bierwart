// Tests der Security Rules für Kasse und Mitgliedschaft: Kasse erstellen,
// Beitreten, Übernahme (ADR-0008), Austreten.
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
const NAMEN = { anna: 'Anna Schulz', kw: 'Karl Wagner' };
const TAG = 24 * 60 * 60 * 1000;
const RCODE_K1 = 'K7QM3XRA9DWFT2HC';
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
const vor = (tage) => Timestamp.fromMillis(Date.now() - tage * TAG);
// Wiederherstellungscode: SHA-256 der normalisierten Form, ID ist das Hex klein.
const sha256 = (code) => createHash('sha256').update(code, 'utf8').digest();
const hashHex = (code) => sha256(code).toString('hex');
const hashBytes = (code) => Bytes.fromUint8Array(sha256(code));

// Kasse k1: kw ist Admin und Kassenwart, anna Bierwartin mit 12,50 € im
// Portemonnaie, jonas ohne App, weg entfernt. Offene Anfragen von neuen Geräten.
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const set = (pfad, daten) => setDoc(doc(db, pfad.startsWith('/') ? pfad.slice(1) : `${K}/${pfad}`), daten);
    await set('/' + K, {
      name: 'FC Test', adminUid: 'kw', kassenwartUid: 'kw', einladungCode: CODE, anzahlBierwarte: 2,
      wiederherstellungHash: hashBytes(RCODE_K1), leerSeit: null, aufgeloest: false, erstelltAm: vor(30), letzteBuchungId: null,
    });
    await set(`/wiederherstellung/${hashHex(RCODE_K1)}`, { kasseId: 'k1' });
    await set(`/einladungen/${CODE}`, { kasseId: 'k1', kassenName: 'FC Test', anzahlBierwarte: 2, erstelltAm: vor(1), ersetzt: false });
    await set('/einladungen/einladung-ersetzt-0001', { kasseId: 'k1', kassenName: 'FC Test', anzahlBierwarte: 2, erstelltAm: vor(1), ersetzt: true });
    // Nicht mehr der Link der Kasse, aber versehentlich nicht als ersetzt markiert
    await set('/einladungen/einladung-veraltet-0001', { kasseId: 'k1', kassenName: 'FC Test', anzahlBierwarte: 2, erstelltAm: vor(1), ersetzt: false });
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
    await mitglied('weg', 'Paul Alt', { entfernt: true });
    await mitglied('gaeste', 'Gäste', { istGast: true });
    const anfrage = (id, neueUid, mitgliedId, extra = {}) => set(`uebernahmen/${id}`, {
      neueUid, mitgliedId, einladungCode: CODE, status: 'offen', angefragtAm: vor(1),
      entschiedenVon: null, entschiedenAm: null, letzteBuchungId: null, ...extra,
    });
    await anfrage('fuerAnna', 'neu', 'anna');
    await anfrage('fuerKw', 'neu', 'kw');
    await anfrage('fuerJonas', 'neu', 'jonas');
    await anfrage('fuerWeg', 'neu', 'weg');
    await anfrage('abgelaufen', 'neu', 'jonas', { angefragtAm: vor(8) });
    await anfrage('abgelehnt', 'neu', 'jonas', { status: 'abgelehnt' });
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const ref = (fs, pfad) => doc(fs, pfad.startsWith('/') ? pfad.slice(1) : `${K}/${pfad}`);

// Ein Batch: Log-Buchung + Änderungen. aenderungen: [[art, pfad, daten], …],
// art = set | update | delete; Pfade mit „/“ sind absolut, sonst unter k1.
function batch(uid, logId, log, aenderungen, { name = NAMEN[uid], kasse = K } = {}) {
  const fs = db(uid);
  const b = writeBatch(fs);
  b.set(doc(fs, `${kasse}/buchungen/${logId}`), { ...log, stempel: { uid, name, am: serverTimestamp(), geraetAm: new Date() } });
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

const ohne = (liste, weg) => liste.filter(([, pfad]) => !weg.includes(pfad));

describe('Kasse erstellen (UC-01, AUTH-02, AUTH-03)', () => {
  const RCODE = 'ABCD1234EFGH5678';
  const erstellen = ({
    uid = 'gruender', start = 5000, admin = uid, hex = hashHex(RCODE), mitGaesten = true,
    weglassen = [], kasse = {},
  } = {}) => {
    const k = '/kassen/k2';
    const mitglied = (id, name, extra) => ({ name, nameKey: key(name), istGast: false, bierwartUid: null, entfernt: false, saldoCents: 0, letzteBuchungId: 'l1', angelegtAm: serverTimestamp(), ...extra });
    let aenderungen = [
      ['set', k, {
        name: 'SV Neu', adminUid: admin, kassenwartUid: uid, einladungCode: 'neuer-code-12345678', anzahlBierwarte: 1,
        wiederherstellungHash: hashBytes(RCODE), leerSeit: null, aufgeloest: false, erstelltAm: serverTimestamp(), letzteBuchungId: 'l1', ...kasse,
      }],
      ['set', `${k}/bierwarte/${uid}`, { mitgliedId: 'm1', name: 'Lena Koch', beigetretenAm: serverTimestamp(), einladungCode: null, letzteBuchungId: 'l1' }],
      ['set', `${k}/mitglieder/m1`, mitglied('m1', 'Lena Koch', { bierwartUid: uid })],
      ['set', `${k}/namen/lena koch`, { mitgliedId: 'm1' }],
      ['set', `${k}/mitglieder/gaeste`, mitglied('gaeste', 'Gäste', { istGast: true })],
      ['set', `${k}/namen/gäste`, { mitgliedId: 'gaeste' }],
      ['set', `${k}/orte/kasse`, { art: 'kasse', uid: null, name: 'Kasse', standCents: start, ehemalig: false, letzteBuchungId: 'l1' }],
      ['set', `${k}/orte/${uid}`, { art: 'portemonnaie', uid, name: 'Lena Koch', standCents: 0, ehemalig: false, letzteBuchungId: 'l1' }],
      ['set', '/einladungen/neuer-code-12345678', { kasseId: 'k2', kassenName: 'SV Neu', anzahlBierwarte: 1, erstelltAm: serverTimestamp(), ersetzt: false }],
      ['set', `/wiederherstellung/${hex}`, { kasseId: 'k2' }],
      ['set', `/users/${uid}`, { kasseId: 'k2' }],
    ];
    if (!mitGaesten) aenderungen = ohne(aenderungen, [`${k}/mitglieder/gaeste`, `${k}/namen/gäste`]);
    aenderungen = ohne(aenderungen, weglassen);
    return batch(uid, 'l1', { typ: 'kasseErstellt', kassenName: 'SV Neu', startCents: start, mitgliedId: 'm1', name: 'Lena Koch' },
      aenderungen, { name: 'Lena Koch', kasse: 'kassen/k2' });
  };

  test('mit Gäste, Einladung, Wiederherstellung und Log', async () => {
    await assertSucceeds(erstellen());
    expect((await lesen('/kassen/k2')).adminUid).toBe('gruender');
    expect((await lesen('/kassen/k2/mitglieder/gaeste')).istGast).toBe(true);
    expect((await lesen(`/wiederherstellung/${hashHex(RCODE)}`)).kasseId).toBe('k2');
  });

  test('Dokument-ID passt nicht zum Hash (AUTH-03)', async () => {
    await assertFails(erstellen({ hex: hashHex('ANDERERCODE00000') }));
  });

  test('Hash-ID in Großbuchstaben abgelehnt', async () => {
    await assertFails(erstellen({ hex: hashHex(RCODE).toUpperCase() }));
  });

  test('Ersteller muss Admin sein', async () => {
    await assertFails(erstellen({ admin: 'jemand' }));
  });

  test('Startbetrag in ganzen Cent (ADR-0002)', async () => {
    await assertFails(erstellen({ start: 50.5 }));
  });

  test('ohne „Gäste“ abgelehnt (KAD-03)', async () => {
    await assertFails(erstellen({ mitGaesten: false }));
  });

  test('ohne Einladung abgelehnt', async () => {
    await assertFails(erstellen({ weglassen: ['/einladungen/neuer-code-12345678'] }));
  });

  test('Einladung einer fremden Kasse abgelehnt', async () => {
    await assertFails(erstellen({ kasse: { einladungCode: CODE }, weglassen: ['/einladungen/neuer-code-12345678'] }));
  });

  test('zu kurzer Einladungscode abgelehnt', async () => {
    await assertFails(erstellen({ kasse: { einladungCode: 'kurz' } }));
  });

  test('wer noch Bierwart einer Kasse ist, erstellt keine zweite', async () => {
    await assertFails(erstellen({ uid: 'anna' }));
  });

  test('bestehende Kasse lässt sich nicht überschreiben', async () => {
    const fs = db('kw');
    await assertFails(setDoc(doc(fs, K), { name: 'Übernommen', adminUid: 'kw' }));
  });
});

describe('Beitreten (UC-02, AUTH-05, AUTH-08)', () => {
  const beitreten = ({ uid = 'neu', name = 'Lena Koch', code = CODE, anzahl = 1, weglassen = [] } = {}) => {
    const aenderungen = ohne([
      ['set', `bierwarte/${uid}`, { mitgliedId: 'm1', name, beigetretenAm: serverTimestamp(), einladungCode: code, letzteBuchungId: 'l1' }],
      ['set', 'mitglieder/m1', { name, nameKey: key(name), istGast: false, bierwartUid: uid, entfernt: false, saldoCents: 0, letzteBuchungId: 'l1', angelegtAm: serverTimestamp() }],
      ['set', `namen/${key(name)}`, { mitgliedId: 'm1' }],
      ['set', `orte/${uid}`, { art: 'portemonnaie', uid, name, standCents: 0, ehemalig: false, letzteBuchungId: 'l1' }],
      ['update', '/' + K, { anzahlBierwarte: increment(anzahl), letzteBuchungId: 'l1' }],
      ['update', `/einladungen/${CODE}`, { anzahlBierwarte: increment(anzahl) }],
      ['set', `/users/${uid}`, { kasseId: 'k1' }],
    ], weglassen);
    return batch(uid, 'l1', { typ: 'bierwartBeigetreten', mitgliedId: 'm1', name }, aenderungen, { name });
  };

  test('Einladung ohne Mitgliedschaft lesbar, aber nicht auflistbar', async () => {
    await assertSucceeds(getDoc(doc(db('neu'), `einladungen/${CODE}`)));
    await assertFails(getDocs(collection(db('neu'), 'einladungen')));
  });

  test('mit gültigem Link', async () => {
    await assertSucceeds(beitreten());
    expect((await lesen('/' + K)).anzahlBierwarte).toBe(3);
    expect((await lesen(`/einladungen/${CODE}`)).anzahlBierwarte).toBe(3);
  });

  test('ersetzter Link abgelehnt (AUTH-08)', async () => {
    await assertFails(beitreten({ code: 'einladung-ersetzt-0001' }));
  });

  test('nur der aktuelle Link der Kasse gilt (ADM-01)', async () => {
    await assertFails(beitreten({ code: 'einladung-veraltet-0001' }));
  });

  test('abgelaufener Link abgelehnt (AUTH-08)', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), `einladungen/${CODE}`), { erstelltAm: vor(8) }, { merge: true }));
    await assertFails(beitreten());
  });

  test('vergebener Name abgelehnt (AUTH-07)', async () => {
    await assertFails(beitreten({ name: 'jonas weber' }));
  });

  test('Anzahl der Bierwarte muss mitzählen', async () => {
    await assertFails(beitreten({ anzahl: 2 }));
  });

  test('Anzahl in der Einladung muss mitzählen (AUTH-05)', async () => {
    await assertFails(beitreten({ weglassen: [`/einladungen/${CODE}`] }));
  });

  test('ohne Portemonnaie abgelehnt', async () => {
    await assertFails(beitreten({ weglassen: ['orte/neu'] }));
  });

  test('wer schon Bierwart ist, tritt nicht noch einmal bei', async () => {
    await assertFails(beitreten({ uid: 'anna' }));
  });

  test('Name im Index ohne Mitgliedschaft lesbar (AUTH-07)', async () => {
    await assertSucceeds(getDoc(doc(db('neu'), `${K}/namen/jonas weber`)));
    await assertFails(getDocs(collection(db('neu'), `${K}/namen`)));
    await assertFails(getDoc(doc(db('neu'), `${K}/mitglieder/jonas`)));
  });
});

describe('Übernahme anfragen und zurückziehen (UC-03, AUTH-07)', () => {
  const anfragen = ({ uid = 'neu', mitglied = 'jonas', name = 'Jonas Weber', code = CODE, neueUid = uid } = {}) =>
    batch(uid, 'l1', { typ: 'uebernahmeAngefragt', uebernahmeId: 'a1', mitgliedId: mitglied }, [
      ['set', 'uebernahmen/a1', {
        neueUid, mitgliedId: mitglied, einladungCode: code, status: 'offen', angefragtAm: serverTimestamp(),
        entschiedenVon: null, entschiedenAm: null, letzteBuchungId: 'l1',
      }],
    ], { name });
  const zurueckziehen = (uid = 'neu') =>
    batch(uid, 'l2', { typ: 'uebernahmeZurueckgezogen', uebernahmeId: 'fuerJonas', mitgliedId: 'jonas' }, [
      ['update', 'uebernahmen/fuerJonas', { status: 'zurueckgezogen', entschiedenVon: uid, entschiedenAm: serverTimestamp(), letzteBuchungId: 'l2' }],
    ], { name: 'Jonas Weber' });

  test('für ein Mitglied ohne App', async () => {
    await assertSucceeds(anfragen());
    await assertSucceeds(getDoc(doc(db('neu'), `${K}/uebernahmen/a1`)));
  });

  test('für einen Bierwart', async () => {
    await assertSucceeds(anfragen({ mitglied: 'anna', name: NAMEN.anna }));
  });

  test('mit ersetztem Link abgelehnt (AUTH-08)', async () => {
    await assertFails(anfragen({ code: 'einladung-ersetzt-0001' }));
  });

  test('nicht für „Gäste“ (KAD-03)', async () => {
    await assertFails(anfragen({ mitglied: 'gaeste', name: 'Gäste' }));
  });

  test('nur für die eigene UID', async () => {
    await assertFails(anfragen({ neueUid: 'jemand' }));
  });

  test('nicht als Bierwart der Kasse', async () => {
    await assertFails(anfragen({ uid: 'anna', name: 'Jonas Weber' }));
  });

  test('Stempel trägt den angefragten Namen', async () => {
    await assertFails(anfragen({ name: 'Anna Schulz' }));
  });

  test('fremde Anfragen sind nicht lesbar', async () => {
    await assertFails(getDoc(doc(db('fremd'), `${K}/uebernahmen/fuerJonas`)));
  });

  test('zurückziehen durch das neue Gerät', async () => {
    await assertSucceeds(zurueckziehen());
    expect((await lesen('uebernahmen/fuerJonas')).status).toBe('zurueckgezogen');
  });

  test('zurückziehen durch Fremde abgelehnt', async () => {
    await assertFails(zurueckziehen('fremd'));
  });
});

describe('Übernahme entscheiden (UC-03, AUTH-07, ADR-0008)', () => {
  const ablehnen = ({ uid = 'kw', anfrage = 'fuerJonas' } = {}) =>
    batch(uid, 'l1', { typ: 'uebernahmeAbgelehnt', uebernahmeId: anfrage, mitgliedId: 'jonas' }, [
      ['update', `uebernahmen/${anfrage}`, { status: 'abgelehnt', entschiedenVon: uid, entschiedenAm: serverTimestamp(), letzteBuchungId: 'l1' }],
    ], { name: NAMEN[uid] ?? 'Jonas Weber' });

  // Bestätigung samt Umzug. Standard: Anna (Bierwartin, 12,50 €) auf UID „neu“.
  const bestaetigen = ({
    uid = 'kw', anfrage = 'fuerAnna', mitglied = 'anna', name = NAMEN.anna, alteUid = 'anna', stand = 1250,
    altAktiv = true, kasse = null, weglassen = [],
  } = {}) => {
    const aenderungen = [
      ['update', `uebernahmen/${anfrage}`, { status: 'bestaetigt', entschiedenVon: uid, entschiedenAm: serverTimestamp(), letzteBuchungId: 'l1' }],
      ['update', `mitglieder/${mitglied}`, { bierwartUid: 'neu', entfernt: false, letzteBuchungId: 'l1' }],
      ['set', 'bierwarte/neu', { mitgliedId: mitglied, name, beigetretenAm: serverTimestamp(), einladungCode: CODE, letzteBuchungId: 'l1' }],
      ['set', 'orte/neu', { art: 'portemonnaie', uid: 'neu', name, standCents: stand, ehemalig: false, letzteBuchungId: 'l1' }],
    ];
    if (altAktiv) aenderungen.push(['delete', `bierwarte/${alteUid}`]);
    if (stand !== 0) aenderungen.push(['update', `orte/${alteUid}`, { standCents: increment(-stand), letzteBuchungId: 'l1' }]);
    if (kasse) {
      aenderungen.push(['update', '/' + K, { ...kasse, letzteBuchungId: 'l1' }]);
      if (kasse.anzahlBierwarte) aenderungen.push(['update', `/einladungen/${CODE}`, { anzahlBierwarte: kasse.anzahlBierwarte }]);
    }
    return batch(uid, 'l1', { typ: 'uebernahmeBestaetigt', uebernahmeId: anfrage, mitgliedId: mitglied, alteUid, neueUid: 'neu', standCents: stand },
      ohne(aenderungen, weglassen));
  };

  test('ablehnen durch einen Bierwart', async () => {
    await assertSucceeds(ablehnen());
    expect((await lesen('uebernahmen/fuerJonas')).entschiedenVon).toBe('kw');
  });

  test('das neue Gerät entscheidet nicht selbst', async () => {
    await assertFails(ablehnen({ uid: 'neu' }));
  });

  test('Bierwart: Mitgliedschaft und Portemonnaie gehen über', async () => {
    await assertSucceeds(bestaetigen());
    expect(await lesen('bierwarte/anna')).toBeUndefined();
    expect((await lesen('bierwarte/neu')).mitgliedId).toBe('anna');
    expect((await lesen('mitglieder/anna')).bierwartUid).toBe('neu');
    expect((await lesen('orte/neu')).standCents).toBe(1250);
    expect((await lesen('orte/anna')).standCents).toBe(0);
  });

  test('das alte Gerät darf selbst bestätigen', async () => {
    await assertSucceeds(bestaetigen({ uid: 'anna' }));
  });

  test('alte UID muss den Zugang verlieren', async () => {
    await assertFails(bestaetigen({ weglassen: ['bierwarte/anna'] }));
  });

  test('Stand muss 1:1 übergehen', async () => {
    await assertFails(bestaetigen({ stand: 1000 }));
  });

  test('Admin und Kassenwart: Rollen gehen über', async () => {
    await assertSucceeds(bestaetigen({ anfrage: 'fuerKw', mitglied: 'kw', name: NAMEN.kw, alteUid: 'kw', stand: 0, uid: 'anna', kasse: { adminUid: 'neu', kassenwartUid: 'neu' } }));
    expect((await lesen('/' + K)).adminUid).toBe('neu');
  });

  test('Rollen dürfen nicht bei der alten UID bleiben', async () => {
    await assertFails(bestaetigen({ anfrage: 'fuerKw', mitglied: 'kw', name: NAMEN.kw, alteUid: 'kw', stand: 0, uid: 'anna', kasse: { adminUid: 'neu' } }));
  });

  test('Rollen anderer bleiben, wo sie sind', async () => {
    await assertFails(bestaetigen({ kasse: { adminUid: 'neu' } }));
  });

  test('Mitglied ohne App: neuer Bierwart mit leerem Portemonnaie', async () => {
    await assertSucceeds(bestaetigen({ anfrage: 'fuerJonas', mitglied: 'jonas', name: 'Jonas Weber', alteUid: null, stand: 0, altAktiv: false, kasse: { anzahlBierwarte: 3 } }));
    expect((await lesen('/' + K)).anzahlBierwarte).toBe(3);
  });

  test('Mitglied ohne App: Anzahl muss mitzählen', async () => {
    await assertFails(bestaetigen({ anfrage: 'fuerJonas', mitglied: 'jonas', name: 'Jonas Weber', alteUid: null, stand: 0, altAktiv: false }));
  });

  test('entferntes Mitglied wird wieder aktiv (KAD-08)', async () => {
    await assertSucceeds(bestaetigen({ anfrage: 'fuerWeg', mitglied: 'weg', name: 'Paul Alt', alteUid: null, stand: 0, altAktiv: false, kasse: { anzahlBierwarte: 3 } }));
    expect((await lesen('mitglieder/weg')).entfernt).toBe(false);
  });

  test('abgelaufene Anfrage abgelehnt (7 Tage)', async () => {
    await assertFails(bestaetigen({ anfrage: 'abgelaufen', mitglied: 'jonas', name: 'Jonas Weber', alteUid: null, stand: 0, altAktiv: false, kasse: { anzahlBierwarte: 3 } }));
  });

  test('entschiedene Anfrage nicht noch einmal', async () => {
    await assertFails(bestaetigen({ anfrage: 'abgelehnt', mitglied: 'jonas', name: 'Jonas Weber', alteUid: null, stand: 0, altAktiv: false, kasse: { anzahlBierwarte: 3 } }));
  });

  test('Anfrage für ein anderes Mitglied passt nicht', async () => {
    await assertFails(bestaetigen({ anfrage: 'fuerJonas' }));
  });

  test('ohne Anfrage kein fremder Bierwart-Eintrag', async () => {
    const fs = db('kw');
    await assertFails(setDoc(doc(fs, `${K}/bierwarte/neu`), { mitgliedId: 'jonas', name: 'Jonas Weber', beigetretenAm: serverTimestamp(), einladungCode: CODE, letzteBuchungId: null }));
  });
});

describe('Austreten (UC-05, AUTH-09, KAD-02)', () => {
  const austreten = ({ uid = 'anna', logId = 'l1', anzahl = -1, leerSeit = null, mitUser = true } = {}) => {
    const aenderungen = [
      ['delete', `bierwarte/${uid}`],
      ['update', '/' + K, { anzahlBierwarte: increment(anzahl), leerSeit, letzteBuchungId: logId }],
      ['update', `/einladungen/${CODE}`, { anzahlBierwarte: increment(anzahl) }],
    ];
    if (mitUser) aenderungen.push(['delete', `/users/${uid}`]);
    return batch(uid, logId, { typ: 'ausgetreten', mitgliedId: uid }, aenderungen);
  };
  const portemonnaie = (uid, standCents) => env.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `${K}/orte/${uid}`), { standCents }, { merge: true }));

  test('mit leerem Portemonnaie; bleibt Mitglied', async () => {
    await portemonnaie('anna', 0);
    await assertSucceeds(austreten());
    expect(await lesen('bierwarte/anna')).toBeUndefined();
    expect((await lesen('mitglieder/anna')).bierwartUid).toBe('anna');
    expect((await lesen('/' + K)).anzahlBierwarte).toBe(1);
  });

  test('nicht mit Geld im Portemonnaie', async () => {
    await assertFails(austreten());
  });

  test('Kassenwart übergibt vorher', async () => {
    await assertFails(austreten({ uid: 'kw' }));
  });

  test('der letzte Bierwart darf mit Rollen gehen, Kasse ist dann leer', async () => {
    await portemonnaie('anna', 0);
    await assertSucceeds(austreten());
    await assertSucceeds(austreten({ uid: 'kw', logId: 'l2', leerSeit: serverTimestamp() }));
    expect((await lesen('/' + K)).leerSeit).toBeDefined();
  });

  test('leere Kasse ohne leerSeit abgelehnt', async () => {
    await portemonnaie('anna', 0);
    await assertSucceeds(austreten());
    await assertFails(austreten({ uid: 'kw', logId: 'l2' }));
  });

  test('Anzahl muss sinken', async () => {
    await portemonnaie('anna', 0);
    await assertFails(austreten({ anzahl: 0 }));
  });

  test('fremden Bierwart-Eintrag nicht löschen', async () => {
    await portemonnaie('anna', 0);
    const fs = db('kw');
    await assertFails(writeBatch(fs).delete(doc(fs, `${K}/bierwarte/anna`)).commit());
  });

  test('Kasseneintrag bleibt, solange man Bierwart ist', async () => {
    const fs = db('anna');
    await assertFails(writeBatch(fs).delete(doc(fs, 'users/anna')).commit());
    await assertSucceeds(getDoc(doc(fs, 'users/anna')));
    await assertFails(getDoc(doc(db('kw'), 'users/anna')));
  });
});
