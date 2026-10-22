import '../../../core/money/cents.dart';
import '../../kader/domain/eintrag.dart';
import 'ort.dart';

/// Art einer Buchung im Log (architecture.md, Buchungen).
enum LogTyp {
  strich,
  strichBar,
  storno,
  zahlung,
  einkauf,
  bestandKorrektur,
  uebergabe,
  einzahlung,
  auszahlung,
  kassensturz,
  mitgliedAngelegt,
  mitgliedUmbenannt,
  mitgliedEntfernt,
  mitgliedWiederaufgenommen,
  sorteAngelegt,
  sorteGeaendert,
  kasseErstellt,
  bierwartBeigetreten,
  uebernahmeAngefragt,
  uebernahmeZurueckgezogen,
  uebernahmeAbgelehnt,
  uebernahmeBestaetigt,
  ausgetreten,
  einladungErneuert,
  wiederherstellungscodeErneuert,
  kasseAufgeloest,
  bierwartEntfernt,
  rolleGeaendert,
  kasseUmbenannt,
  adminWiederhergestellt,
  unbekannt,
}

/// Eine Buchung aus dem Log (LOG-01), nur mit den Feldern, die der Verlauf
/// zeigt. Welche gesetzt sind, hängt vom [typ] ab.
class Logbuchung {
  const Logbuchung({
    required this.id,
    required this.typ,
    required this.zeit,
    required this.von,
    this.mitgliedId,
    this.sorteId,
    this.ortId,
    this.vonOrtId,
    this.nachOrtId,
    this.cents,
    this.anzahl,
    this.differenz,
    this.grund,
    this.name,
    this.nameAlt,
    this.nameNeu,
    this.rolle,
    this.zielUid,
    this.bezugBar = false,
    this.bezugZahlung = false,
    this.aktiv = true,
  });

  final String id;
  final LogTyp typ;

  /// Serverzeit, solange die Buchung nur lokal liegt die Gerätezeit.
  final DateTime zeit;

  /// Name im Stempel: wer gebucht hat.
  final String von;
  final String? mitgliedId;
  final String? sorteId;
  final String? ortId;
  final String? vonOrtId;
  final String? nachOrtId;

  /// Preis, Betrag, Startbetrag oder beim Kassensturz der gezählte Betrag.
  final int? cents;

  /// Flaschen: beim Einkauf die Summe, bei der Korrektur der gezählte Wert.
  final int? anzahl;

  /// Differenz der Korrektur (Flaschen) oder des Kassensturzes (Cent).
  final int? differenz;
  final String? grund;

  /// Name einer neuen Sorte, eines neuen Mitglieds oder der Kasse.
  final String? name;
  final String? nameAlt;
  final String? nameNeu;

  /// `admin` oder `kassenwart` bei einem Rollenwechsel.
  final String? rolle;

  /// An wen eine Rolle ging oder wer entfernt wurde.
  final String? zielUid;

  /// Storno eines Bar-Strichs.
  final bool bezugBar;

  /// Storno einer Zahlung (offene Frage 24).
  final bool bezugZahlung;

  /// Sichtbarkeit einer geänderten Sorte (BES-01).
  final bool aktiv;
}

/// Wie ein Betrag im Verlauf erscheint.
enum Tendenz { neutral, plus, minus, keiner }

/// Eine Zeile im Verlauf (LOG-03), wie im Design-Canvas: „Strich · Jonas
/// Weber“, darunter „Bier 0,5 · offen · von Tobias“, rechts der Betrag.
class LogZeile {
  const LogZeile({
    required this.titel,
    required this.unterzeile,
    required this.betrag,
    required this.tendenz,
  });

  final String titel;
  final String unterzeile;
  final String betrag;
  final Tendenz tendenz;
}

/// Namen, mit denen der Verlauf IDs auflöst. Fehlt ein Name, steht dort ein
/// neutrales Wort statt der ID.
class LogNamen {
  const LogNamen({
    this.mitglieder = const {},
    this.sorten = const {},
    this.bierwarte = const {},
  });

  /// Mitglied-ID → Name, auch entfernte (KAD-08).
  final Map<String, String> mitglieder;
  final Map<String, String> sorten;

  /// UID → Name, auch ehemalige; zugleich die Portemonnaies.
  final Map<String, String> bierwarte;

  String mitglied(String? id) => mitglieder[id] ?? 'Mitglied';
  String sorte(String? id) => sorten[id] ?? 'Sorte';
  String bierwart(String? uid) => bierwarte[uid] ?? 'Bierwart';

  /// „in die Kasse“ oder „in Portemonnaie Max“.
  String inOrt(String? id) => id == Ort.kasseId
      ? 'in die Kasse'
      : 'in Portemonnaie ${vorname(bierwart(id))}';

  /// „aus der Kasse“ oder „aus Portemonnaie Max“.
  String ausOrt(String? id) => id == Ort.kasseId
      ? 'aus der Kasse'
      : 'aus Portemonnaie ${vorname(bierwart(id))}';

  /// „Kasse“ oder „Max“, für Übergaben.
  String ortKurz(String? id) =>
      id == Ort.kasseId ? 'Kasse' : vorname(bierwart(id));
}

String _mitVorzeichen(int cents) =>
    cents > 0 ? '+${formatEuro(cents)}' : formatEuro(cents);

/// Text und Betrag einer Buchung im Verlauf (LOG-03).
LogZeile logZeile(Logbuchung b, LogNamen n) {
  final von = 'von ${vorname(b.von)}';
  final cents = b.cents ?? 0;

  LogZeile zeile(
    String titel,
    List<String> teile, {
    String betrag = '—',
    Tendenz tendenz = Tendenz.keiner,
  }) => LogZeile(
    titel: titel,
    unterzeile: [...teile, von].join(' · '),
    betrag: betrag,
    tendenz: tendenz,
  );

  return switch (b.typ) {
    LogTyp.strich => zeile(
      'Strich · ${n.mitglied(b.mitgliedId)}',
      [n.sorte(b.sorteId), 'offen'],
      betrag: formatEuro(cents),
      tendenz: Tendenz.neutral,
    ),
    LogTyp.strichBar => zeile(
      'Strich · ${n.mitglied(b.mitgliedId)}',
      [n.sorte(b.sorteId), 'bar ${n.inOrt(b.ortId)}'],
      betrag: formatEuro(cents),
      tendenz: Tendenz.neutral,
    ),
    LogTyp.storno when b.bezugZahlung => zeile(
      'Storno · Zahlung · ${n.mitglied(b.mitgliedId)}',
      [n.ausOrt(b.ortId)],
      betrag: formatEuro(-cents),
      tendenz: Tendenz.minus,
    ),
    LogTyp.storno => zeile(
      'Storno · ${n.mitglied(b.mitgliedId)}',
      [n.sorte(b.sorteId), if (b.bezugBar) 'bar zurück ${n.ausOrt(b.ortId)}'],
      betrag: formatEuro(-cents),
      tendenz: Tendenz.neutral,
    ),
    LogTyp.zahlung => zeile(
      'Zahlung · ${n.mitglied(b.mitgliedId)}',
      [n.inOrt(b.ortId)],
      betrag: _mitVorzeichen(cents),
      tendenz: Tendenz.plus,
    ),
    LogTyp.einkauf => zeile(
      'Einkauf · ${flaschenWort(b.anzahl ?? 0)}',
      [n.ausOrt(b.ortId)],
      betrag: formatEuro(-cents),
      tendenz: Tendenz.minus,
    ),
    LogTyp.bestandKorrektur => zeile(
      'Bestand korrigiert · ${n.sorte(b.sorteId)}',
      [
        '${(b.anzahl ?? 0) - (b.differenz ?? 0)} → '
            '${flaschenWort(b.anzahl ?? 0)}',
      ],
    ),
    LogTyp.uebergabe => LogZeile(
      titel: 'Übergabe · ${n.ortKurz(b.vonOrtId)} → ${n.ortKurz(b.nachOrtId)}',
      unterzeile: b.nachOrtId == Ort.kasseId
          ? 'angenommen von ${vorname(b.von)}'
          : 'gegeben von ${vorname(b.von)}',
      betrag: formatEuro(cents),
      tendenz: Tendenz.neutral,
    ),
    LogTyp.einzahlung => zeile(
      'Einzahlung · ${b.grund ?? ''}',
      [n.inOrt(b.ortId)],
      betrag: _mitVorzeichen(cents),
      tendenz: Tendenz.plus,
    ),
    LogTyp.auszahlung => zeile(
      'Auszahlung · ${b.grund ?? ''}',
      [n.ausOrt(b.ortId)],
      betrag: formatEuro(-cents),
      tendenz: Tendenz.minus,
    ),
    LogTyp.kassensturz => switch (b.differenz ?? 0) {
      0 => zeile('Kassensturz', ['stimmt genau']),
      final d => zeile(
        'Kassensturz',
        ['Differenz gebucht'],
        betrag: _mitVorzeichen(d),
        tendenz: d < 0 ? Tendenz.minus : Tendenz.plus,
      ),
    },
    LogTyp.mitgliedAngelegt => zeile('Mitglied angelegt · ${b.name ?? ''}', []),
    LogTyp.mitgliedUmbenannt => zeile(
      'Umbenannt · ${b.nameAlt} → ${b.nameNeu}',
      [],
    ),
    LogTyp.mitgliedEntfernt => zeile(
      'Mitglied entfernt · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.mitgliedWiederaufgenommen => zeile(
      'Wieder aufgenommen · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.sorteAngelegt => zeile('Sorte angelegt · ${b.name ?? ''}', [
      formatEuro(cents),
    ]),
    LogTyp.sorteGeaendert => zeile('Sorte geändert · ${b.name ?? ''}', [
      formatEuro(cents),
      if (!b.aktiv) 'ausgeblendet',
    ]),
    LogTyp.kasseErstellt => zeile('Kasse erstellt · ${b.name ?? ''}', [
      'Start ${formatEuro(cents)}',
    ]),
    LogTyp.bierwartBeigetreten => zeile(
      'Beigetreten · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.uebernahmeAngefragt => zeile(
      'Übernahme angefragt · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.uebernahmeZurueckgezogen => zeile(
      'Übernahme zurückgezogen · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.uebernahmeAbgelehnt => zeile(
      'Übernahme abgelehnt · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.uebernahmeBestaetigt => zeile(
      'Übernahme bestätigt · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.ausgetreten => zeile(
      'Ausgetreten · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.einladungErneuert => zeile('Einladungslink erneuert', []),
    LogTyp.wiederherstellungscodeErneuert => zeile(
      'Wiederherstellungscode erneuert',
      [],
    ),
    LogTyp.kasseAufgeloest => zeile('Kasse aufgelöst', []),
    LogTyp.bierwartEntfernt => zeile(
      'Bierwart entfernt · ${n.mitglied(b.mitgliedId)}',
      [],
    ),
    LogTyp.rolleGeaendert => zeile(
      '${b.rolle == 'admin' ? 'Admin' : 'Kassenwart'} übergeben · '
      '${n.bierwart(b.zielUid)}',
      [],
    ),
    LogTyp.kasseUmbenannt => zeile(
      'Kasse umbenannt · ${b.nameAlt} → ${b.nameNeu}',
      [],
    ),
    LogTyp.adminWiederhergestellt => zeile('Admin wiederhergestellt', []),
    LogTyp.unbekannt => zeile('Buchung', []),
  };
}

/// „1 Flasche“, „44 Flaschen“.
String flaschenWort(int n) => n == 1 ? '1 Flasche' : '$n Flaschen';

const _wochentage = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _monate = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

/// „Samstag, 17. Oktober“ als Kopf einer Tagesgruppe.
String tagText(DateTime t) =>
    '${_wochentage[t.weekday - 1]}, ${t.day}. ${_monate[t.month - 1]}';

/// „20:41“.
String uhrzeit(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// Buchungen nach Tag, neueste zuerst; die Reihenfolge innerhalb eines Tages
/// bleibt.
List<(DateTime, List<Logbuchung>)> nachTagen(List<Logbuchung> buchungen) {
  final tage = <(DateTime, List<Logbuchung>)>[];
  for (final b in buchungen) {
    final tag = DateTime(b.zeit.year, b.zeit.month, b.zeit.day);
    if (tage.isEmpty || tage.last.$1 != tag) {
      tage.add((tag, [b]));
    } else {
      tage.last.$2.add(b);
    }
  }
  return tage;
}
