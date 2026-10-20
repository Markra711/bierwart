// Tests der Security Rules für Buchungen (ADR-0009). Laufen gegen den Firestore-Emulator:
//   firebase emulators:exec --only firestore --project demo-bierwart "npm --prefix rules-tests test"
import { readFileSync } from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  increment,
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

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const set = (pfad, daten) => setDoc(doc(db, `${K}/${pfad}`), daten);
    await setDoc(doc(db, K), { name: 'FC Test', adminUid: 'kw', kassenwartUid: 'kw' });
    for (const [uid, name] of Object.entries(NAMEN)) {
      await set(`bierwarte/${uid}`, { mitgliedId: uid, name });
      await set(`orte/${uid}`, { art: 'portemonnaie', standCents: 0, letzteBuchungId: null });
    }
    await set('orte/kasse', { art: 'kasse', standCents: 10000, letzteBuchungId: null });
    await set('mitglieder/jonas', { name: 'Jonas Weber', saldoCents: 0, letzteBuchungId: null });
    await set('mitglieder/gaeste', { name: 'Gäste', istGast: true, saldoCents: 0, letzteBuchungId: null });
    await set('mitglieder/weg', { name: 'Paul Alt', entfernt: true, saldoCents: 0, letzteBuchungId: null });
    for (let i = 0; i < 12; i++) {
      await set(`sorten/s${i}`, {
        name: `Sorte ${i}`, preisCents: 150, vorherigerPreisCents: i === 0 ? 120 : null,
        bestand: 10, letzteBuchungId: null,
      });
    }
  });
});

const db = (uid) => env.authenticatedContext(uid).firestore();
const stempel = (uid) => ({ uid, name: NAMEN[uid] ?? uid, am: serverTimestamp(), geraetAm: new Date() });

// Ein Batch aus Buchung und Summen-Änderungen.
// summen: [[pfad, feld, {inc: n} | {set: n}], …]
function buche(uid, id, buchung, summen) {
  const fs = db(uid);
  const batch = writeBatch(fs);
  batch.set(doc(fs, `${K}/buchungen/${id}`), { ...buchung, stempel: stempel(uid) });
  for (const [pfad, feld, wert] of summen) {
    batch.update(doc(fs, `${K}/${pfad}`), {
      [feld]: 'inc' in wert ? increment(wert.inc) : wert.set,
      letzteBuchungId: id,
    });
  }
  return batch.commit();
}

const strich = ({ uid = 'anna', id = 'b1', mitglied = 'jonas', sorte = 's0', preis = 150, saldo = preis } = {}) =>
  buche(uid, id, { typ: 'strich', mitgliedId: mitglied, sorteId: sorte, preisCents: preis }, [
    [`mitglieder/${mitglied}`, 'saldoCents', { inc: saldo }],
    [`sorten/${sorte}`, 'bestand', { inc: -1 }],
  ]);

const strichBar = ({ uid = 'anna', id = 'b1', mitglied = 'jonas', ortId = uid, preis = 150 } = {}) =>
  buche(uid, id, { typ: 'strichBar', mitgliedId: mitglied, sorteId: 's0', preisCents: preis, ortId }, [
    ['sorten/s0', 'bestand', { inc: -1 }],
    [`orte/${ortId}`, 'standCents', { inc: preis }],
  ]);

const zahlung = ({ uid = 'anna', id = 'z1', betrag = 500, ortId = uid } = {}) =>
  buche(uid, id, { typ: 'zahlung', mitgliedId: 'jonas', betragCents: betrag, ortId }, [
    ['mitglieder/jonas', 'saldoCents', { inc: -betrag }],
    [`orte/${ortId}`, 'standCents', { inc: betrag }],
  ]);

function einkauf(anzahlSorten, { uid = 'anna', id = 'e1', anzahl = 6 } = {}) {
  const zeilen = {};
  for (let i = 0; i < anzahlSorten; i++) zeilen[`s${i}`] = anzahl;
  const betrag = 900 * anzahlSorten;
  return buche(uid, id, { typ: 'einkauf', zeilen, betragCents: betrag, ortId: uid }, [
    [`orte/${uid}`, 'standCents', { inc: -betrag }],
    ...Object.keys(zeilen).map((s) => [`sorten/${s}`, 'bestand', { inc: anzahl }]),
  ]);
}

async function lesen(pfad) {
  let daten;
  await env.withSecurityRulesDisabled(async (ctx) => {
    daten = (await getDoc(doc(ctx.firestore(), `${K}/${pfad}`))).data();
  });
  return daten;
}

describe('Strich offen (STR-02)', () => {
  test('bucht Saldo und Bestand', async () => {
    await assertSucceeds(strich());
    expect((await lesen('mitglieder/jonas')).saldoCents).toBe(150);
    expect((await lesen('sorten/s0')).bestand).toBe(9);
  });

  test('zwei Striche von zwei Bierwarten summieren sich (NFA-03)', async () => {
    await assertSucceeds(strich({ id: 'b1' }));
    await assertSucceeds(strich({ id: 'b2', uid: 'kw' }));
    expect((await lesen('mitglieder/jonas')).saldoCents).toBe(300);
  });

  test('auch bei Bestand 0 und darunter (STR-05)', async () => {
    await env.withSecurityRulesDisabled((ctx) => updateDoc(doc(ctx.firestore(), `${K}/sorten/s0`), { bestand: 0 }));
    await assertSucceeds(strich());
    expect((await lesen('sorten/s0')).bestand).toBe(-1);
  });

  test('vorheriger Preis ist erlaubt (BES-02)', async () => {
    await assertSucceeds(strich({ preis: 120 }));
  });

  test('anderer Preis wird abgelehnt', async () => {
    await assertFails(strich({ preis: 100 }));
  });

  test('Saldo passt nicht zur Buchung', async () => {
    await assertFails(strich({ saldo: 1000 }));
  });

  test('auf „Gäste“ nur bar (KAD-03)', async () => {
    await assertFails(strich({ mitglied: 'gaeste' }));
  });

  test('nicht auf entfernte Mitglieder', async () => {
    await assertFails(strich({ mitglied: 'weg' }));
  });

  test('Nicht-Bierwart darf nicht buchen', async () => {
    await assertFails(strich({ uid: 'fremd' }));
  });

  test('Stempel mit falschem Namen wird abgelehnt', async () => {
    const fs = db('anna');
    const batch = writeBatch(fs);
    batch.set(doc(fs, `${K}/buchungen/b1`), {
      typ: 'strich', mitgliedId: 'jonas', sorteId: 's0', preisCents: 150,
      stempel: { uid: 'anna', name: 'Karl Wagner', am: serverTimestamp() },
    });
    batch.update(doc(fs, `${K}/mitglieder/jonas`), { saldoCents: increment(150), letzteBuchungId: 'b1' });
    batch.update(doc(fs, `${K}/sorten/s0`), { bestand: increment(-1), letzteBuchungId: 'b1' });
    await assertFails(batch.commit());
  });

  test('Buchung ohne Saldo-Änderung wird abgelehnt', async () => {
    await assertFails(buche('anna', 'b1', { typ: 'strich', mitgliedId: 'jonas', sorteId: 's0', preisCents: 150 }, [
      ['sorten/s0', 'bestand', { inc: -1 }],
    ]));
  });
});

describe('Strich bar (STR-03)', () => {
  test('Geld ins eigene Portemonnaie, Saldo bleibt', async () => {
    await assertSucceeds(strichBar());
    expect((await lesen('orte/anna')).standCents).toBe(150);
    expect((await lesen('mitglieder/jonas')).saldoCents).toBe(0);
    expect((await lesen('sorten/s0')).bestand).toBe(9);
  });

  test('auf „Gäste“ (KAD-03)', async () => {
    await assertSucceeds(strichBar({ mitglied: 'gaeste' }));
  });

  test('nicht in fremdes Portemonnaie', async () => {
    await assertFails(strichBar({ ortId: 'kw' }));
  });

  test('Kassenwart darf in die Kasse buchen', async () => {
    await assertSucceeds(strichBar({ uid: 'kw', ortId: 'kasse' }));
    expect((await lesen('orte/kasse')).standCents).toBe(10150);
  });
});

describe('Storno (STR-04, STR-06)', () => {
  const stornoStrich = ({ uid = 'anna', id = 'storno-b1', bezugId = 'b1', preis = 150 } = {}) =>
    buche(uid, id, { typ: 'storno', bezugId, bezugTyp: 'strich', mitgliedId: 'jonas', sorteId: 's0', preisCents: preis }, [
      ['mitglieder/jonas', 'saldoCents', { inc: -preis }],
      ['sorten/s0', 'bestand', { inc: 1 }],
    ]);
  const stornoBar = ({ uid = 'anna', ortId = uid } = {}) =>
    buche(uid, 'storno-b1', { typ: 'storno', bezugId: 'b1', bezugTyp: 'strichBar', mitgliedId: 'jonas', sorteId: 's0', preisCents: 150, ortId }, [
      ['sorten/s0', 'bestand', { inc: 1 }],
      [`orte/${ortId}`, 'standCents', { inc: -150 }],
    ]);

  test('Strich stornieren stellt Saldo und Bestand wieder her', async () => {
    await assertSucceeds(strich());
    await assertSucceeds(stornoStrich());
    expect((await lesen('mitglieder/jonas')).saldoCents).toBe(0);
    expect((await lesen('sorten/s0')).bestand).toBe(10);
  });

  test('jede Buchung nur einmal', async () => {
    await assertSucceeds(strich());
    await assertSucceeds(stornoStrich());
    await assertFails(stornoStrich());
  });

  test('nur mit der festen ID storno-{bezugId}', async () => {
    await assertSucceeds(strich());
    await assertFails(stornoStrich({ id: 'x1' }));
  });

  test('Felder müssen zur Ursprungsbuchung passen', async () => {
    await assertSucceeds(strich());
    await assertFails(stornoStrich({ preis: 300 }));
  });

  test('Bar-Strich: Geld aus dem Portemonnaie dessen, der storniert', async () => {
    await assertSucceeds(strichBar({ uid: 'anna' }));
    await assertSucceeds(stornoBar({ uid: 'kw' }));
    expect((await lesen('orte/anna')).standCents).toBe(150);
    expect((await lesen('orte/kw')).standCents).toBe(-150);
  });

  test('Bar-Strich: nicht aus fremdem Portemonnaie', async () => {
    await assertSucceeds(strichBar({ uid: 'anna' }));
    await assertFails(stornoBar({ uid: 'kw', ortId: 'anna' }));
  });

  test('Zahlungen lassen sich nicht stornieren', async () => {
    await assertSucceeds(zahlung({ id: 'z1' }));
    await assertFails(buche('anna', 'storno-z1', { typ: 'storno', bezugId: 'z1', bezugTyp: 'zahlung', mitgliedId: 'jonas', sorteId: 's0', preisCents: 500 }, [
      ['mitglieder/jonas', 'saldoCents', { inc: 500 }],
      ['sorten/s0', 'bestand', { inc: 1 }],
    ]));
  });
});

describe('Zahlung (GEL-02, GEL-03)', () => {
  test('ins eigene Portemonnaie, Überzahlung wird Guthaben', async () => {
    await assertSucceeds(zahlung({ betrag: 500 }));
    expect((await lesen('orte/anna')).standCents).toBe(500);
    expect((await lesen('mitglieder/jonas')).saldoCents).toBe(-500);
  });

  test('nicht in fremdes Portemonnaie', async () => {
    await assertFails(zahlung({ ortId: 'kw' }));
  });

  test('in die Kasse nur als Kassenwart', async () => {
    await assertFails(zahlung({ ortId: 'kasse' }));
    await assertSucceeds(zahlung({ uid: 'kw', ortId: 'kasse' }));
  });

  test('Betrag muss eine positive Ganzzahl in Cent sein (ADR-0002)', async () => {
    await assertFails(zahlung({ betrag: 4.5 }));
    await assertFails(zahlung({ betrag: -100 }));
    await assertFails(zahlung({ betrag: 0 }));
  });
});

describe('Einkauf (BES-04, BES-05)', () => {
  test('eine Sorte', async () => {
    await assertSucceeds(einkauf(1));
    expect((await lesen('sorten/s0')).bestand).toBe(16);
    expect((await lesen('orte/anna')).standCents).toBe(-900);
  });

  test('10 Sorten gehen', async () => {
    await assertSucceeds(einkauf(10));
  });

  test('11 Sorten werden abgelehnt (ADR-0009)', async () => {
    await assertFails(einkauf(11));
  });

  test('Anzahl muss positiv sein', async () => {
    await assertFails(einkauf(1, { anzahl: -6 }));
  });

  test('jede Zeile muss den Bestand ändern', async () => {
    await assertFails(buche('anna', 'e1', { typ: 'einkauf', zeilen: { s0: 6, s1: 6 }, betragCents: 1800, ortId: 'anna' }, [
      ['orte/anna', 'standCents', { inc: -1800 }],
      ['sorten/s0', 'bestand', { inc: 6 }],
    ]));
  });
});

describe('Bestandskorrektur (BES-06)', () => {
  const korrektur = ({ gezaehlt = 7, differenz = -3 } = {}) =>
    buche('anna', 'k1', { typ: 'bestandKorrektur', sorteId: 's0', gezaehlt, differenz }, [
      ['sorten/s0', 'bestand', { set: gezaehlt }],
    ]);

  test('setzt den gezählten Bestand', async () => {
    await assertSucceeds(korrektur());
    expect((await lesen('sorten/s0')).bestand).toBe(7);
  });

  test('abgelehnt, wenn sich der Stand inzwischen geändert hat', async () => {
    await assertSucceeds(strich());   // Bestand jetzt 9, die App hat noch 10 gesehen
    await assertFails(korrektur({ gezaehlt: 7, differenz: -3 }));
  });
});

describe('Übergabe (GEL-04)', () => {
  const uebergabe = ({ uid = 'kw', von = 'anna', nach = 'kasse', betrag = 500 } = {}) =>
    buche(uid, 'u1', { typ: 'uebergabe', vonOrtId: von, nachOrtId: nach, betragCents: betrag }, [
      [`orte/${von}`, 'standCents', { inc: -betrag }],
      [`orte/${nach}`, 'standCents', { inc: betrag }],
    ]);

  test('Kassenwart: Portemonnaie → Kasse', async () => {
    await assertSucceeds(uebergabe());
    expect((await lesen('orte/anna')).standCents).toBe(-500);
    expect((await lesen('orte/kasse')).standCents).toBe(10500);
  });

  test('Kassenwart: Kasse → Portemonnaie', async () => {
    await assertSucceeds(uebergabe({ von: 'kasse', nach: 'anna' }));
  });

  test('nur der Kassenwart', async () => {
    await assertFails(uebergabe({ uid: 'anna' }));
  });

  test('nicht zwischen zwei Portemonnaies', async () => {
    await assertFails(uebergabe({ von: 'anna', nach: 'kw' }));
  });
});

describe('Ein- und Auszahlung (GEL-05)', () => {
  const bewegung = ({ uid = 'anna', typ = 'auszahlung', ortId = uid, grund = 'Schiri bezahlt', betrag = 2500 } = {}) =>
    buche(uid, 'a1', { typ, ortId, betragCents: betrag, grund }, [
      [`orte/${ortId}`, 'standCents', { inc: typ === 'auszahlung' ? -betrag : betrag }],
    ]);

  test('Auszahlung aus eigenem Portemonnaie', async () => {
    await assertSucceeds(bewegung());
    expect((await lesen('orte/anna')).standCents).toBe(-2500);
  });

  test('Einzahlung ins eigene Portemonnaie', async () => {
    await assertSucceeds(bewegung({ typ: 'einzahlung' }));
  });

  test('braucht einen Grund', async () => {
    await assertFails(bewegung({ grund: '' }));
  });

  test('aus der Kasse nur als Kassenwart', async () => {
    await assertFails(bewegung({ ortId: 'kasse' }));
    await assertSucceeds(bewegung({ uid: 'kw', ortId: 'kasse' }));
  });
});

describe('Kassensturz (GEL-06)', () => {
  const sturz = ({ uid = 'kw', gezaehlt = 9800, differenz = -200 } = {}) =>
    buche(uid, 'ks1', { typ: 'kassensturz', gezaehltCents: gezaehlt, differenzCents: differenz }, [
      ['orte/kasse', 'standCents', { set: gezaehlt }],
    ]);

  test('Kassenwart bucht gezählten Betrag und Differenz', async () => {
    await assertSucceeds(sturz());
    expect((await lesen('orte/kasse')).standCents).toBe(9800);
  });

  test('Differenz muss zum Serverstand passen', async () => {
    await assertFails(sturz({ differenz: -100 }));
  });

  test('nur der Kassenwart', async () => {
    await assertFails(sturz({ uid: 'anna' }));
  });
});

describe('Summen ohne passende Buchung', () => {
  test('Saldo allein ändern geht nicht', async () => {
    await assertFails(updateDoc(doc(db('anna'), `${K}/mitglieder/jonas`), { saldoCents: increment(-500), letzteBuchungId: 'x' }));
  });

  test('eine alte Buchung lässt sich nicht ein zweites Mal anwenden', async () => {
    await assertSucceeds(zahlung({ id: 'z1' }));
    await assertFails(updateDoc(doc(db('anna'), `${K}/mitglieder/jonas`), { saldoCents: increment(-500), letzteBuchungId: 'z1' }));
  });
});

describe('Log ist unveränderlich (LOG-02)', () => {
  test('Buchung ändern oder löschen geht nicht', async () => {
    await assertSucceeds(strich());
    await assertFails(updateDoc(doc(db('anna'), `${K}/buchungen/b1`), { preisCents: 0 }));
    await assertFails(deleteDoc(doc(db('anna'), `${K}/buchungen/b1`)));
  });
});
