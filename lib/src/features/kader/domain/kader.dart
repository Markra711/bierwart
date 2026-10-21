import '../../../core/money/cents.dart';
import 'mitglied.dart';

/// Reihenfolge im Kader: höchste Schulden zuerst, Guthaben zuletzt, bei
/// gleichem Betrag alphabetisch (KAD-05). „Gäste“ führt keinen Saldo und
/// steht nicht im Kader.
List<Mitglied> kaderNachSchulden(Iterable<Mitglied> mitglieder) =>
    mitglieder.where((m) => !m.istGast).toList()..sort((a, b) {
      final s = b.saldoCents.compareTo(a.saldoCents);
      return s != 0 ? s : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

/// Summen für die beiden Karten oben im Kader.
({int offenCents, int guthabenCents}) kaderSummen(
  Iterable<Mitglied> mitglieder,
) {
  var offen = 0;
  var guthaben = 0;
  for (final m in mitglieder) {
    if (m.saldoCents > 0) offen += m.saldoCents;
    if (m.saldoCents < 0) guthaben -= m.saldoCents;
  }
  return (offenCents: offen, guthabenCents: guthaben);
}

/// „Wer schuldet was“ als Text fürs Teilen-Menü (KAD-07).
String werSchuldetWas(String kassenName, Iterable<Mitglied> mitglieder) {
  final kader = kaderNachSchulden(mitglieder);
  final offen = kader.where((m) => m.saldoCents > 0);
  final guthaben = kader.where((m) => m.saldoCents < 0);
  final zeilen = <String>['Wer schuldet was – $kassenName', ''];
  if (offen.isEmpty) {
    zeilen.add('Niemand schuldet etwas.');
  } else {
    for (final m in offen) {
      zeilen.add('${m.name}: ${formatEuro(m.saldoCents)}');
    }
  }
  if (guthaben.isNotEmpty) {
    zeilen
      ..add('')
      ..add('Guthaben:');
    for (final m in guthaben) {
      zeilen.add('${m.name}: ${formatEuro(-m.saldoCents)}');
    }
  }
  return zeilen.join('\n');
}

/// Rolle für das Badge in der Liste; Admin vor Kassenwart vor Bierwart.
enum Rolle { admin, kassenwart, bierwart }

/// Die höchste Rolle eines Mitglieds oder `null` (kein aktiver Bierwart).
Rolle? rolleVon(
  Mitglied m, {
  required Set<String> aktiveBierwarte,
  required String? adminUid,
  required String? kassenwartUid,
}) {
  final uid = m.bierwartUid;
  if (uid == null || !aktiveBierwarte.contains(uid)) return null;
  if (uid == adminUid) return Rolle.admin;
  if (uid == kassenwartUid) return Rolle.kassenwart;
  return Rolle.bierwart;
}
