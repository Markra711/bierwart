import '../../kader/domain/eintrag.dart';

/// „Das bin ich“ (UC-03, AUTH-07, ADR-0008): Ein neues Gerät fragt an, eine
/// bestehende Mitgliedschaft zu übernehmen. Ein aktiver Bierwart entscheidet.
enum UebernahmeStatus { offen, bestaetigt, abgelehnt, zurueckgezogen }

/// Eine Anfrage aus `kassen/{k}/uebernahmen/{id}`.
class Uebernahme {
  const Uebernahme({
    required this.id,
    required this.kasseId,
    required this.mitgliedId,
    required this.neueUid,
    required this.einladungCode,
    required this.status,
    required this.angefragtAm,
  });

  final String id;
  final String kasseId;
  final String mitgliedId;
  final String neueUid;
  final String einladungCode;
  final UebernahmeStatus status;

  /// Serverzeit der Anfrage; `null`, solange sie nur lokal geschrieben ist.
  final DateTime? angefragtAm;

  /// Wie die Einladung 7 Tage (architecture.md, offene Frage 22).
  static const gueltigkeit = Duration(days: 7);

  DateTime? get gueltigBis => angefragtAm?.add(gueltigkeit);

  /// Offen und noch nicht abgelaufen. Maßgeblich bleiben die Rules mit der
  /// Serverzeit.
  bool istOffen(DateTime jetzt) {
    final bis = gueltigBis;
    return status == UebernahmeStatus.offen &&
        (bis == null || jetzt.isBefore(bis));
  }

  bool istAbgelaufen(DateTime jetzt) =>
      status == UebernahmeStatus.offen && !istOffen(jetzt);

  /// „angefragt Mi 05.11., 21:12“
  String get angefragtText => angefragtAm == null
      ? 'gerade angefragt'
      : 'angefragt ${zeitText(angefragtAm!)}';
}

/// Die eigene Anfrage, solange das neue Gerät wartet. Sie liegt auch im
/// Gerätespeicher, damit der Warte-Bildschirm einen Neustart übersteht.
class WartendeAnfrage {
  const WartendeAnfrage({
    required this.kasseId,
    required this.anfrageId,
    required this.mitgliedId,
    required this.name,
    required this.kassenName,
  });

  final String kasseId;
  final String anfrageId;
  final String mitgliedId;

  /// Der Name, wie ihn der Nutzer eingetippt hat.
  final String name;
  final String kassenName;

  Map<String, String> toJson() => {
    'kasseId': kasseId,
    'anfrageId': anfrageId,
    'mitgliedId': mitgliedId,
    'name': name,
    'kassenName': kassenName,
  };

  /// `null` bei kaputten oder alten Daten.
  static WartendeAnfrage? fromJson(Object? json) {
    if (json is! Map) return null;
    final felder = [
      for (final k in [
        'kasseId',
        'anfrageId',
        'mitgliedId',
        'name',
        'kassenName',
      ])
        json[k],
    ];
    if (felder.any((f) => f is! String)) return null;
    return WartendeAnfrage(
      kasseId: felder[0] as String,
      anfrageId: felder[1] as String,
      mitgliedId: felder[2] as String,
      name: felder[3] as String,
      kassenName: felder[4] as String,
    );
  }
}

/// Was der Entscheider vor dem Bestätigen frisch vom Server liest. Daraus
/// baut er den Batch so, wie die Rules ihn verlangen (`uebernahmeGueltig`).
class UebernahmeStand {
  const UebernahmeStand({
    required this.anfrage,
    required this.mitgliedName,
    required this.alteUid,
    required this.alteAktiv,
    required this.altesPortemonnaieCents,
    required this.adminUid,
    required this.kassenwartUid,
    required this.einladungCode,
  });

  final Uebernahme anfrage;
  final String mitgliedName;

  /// `bierwartUid` des Mitglieds; `null` bei einem Mitglied ohne App.
  final String? alteUid;

  /// Ob [alteUid] noch aktiver Bierwart ist.
  final bool alteAktiv;

  /// Stand des alten Portemonnaies; `null`, wenn es keins gibt.
  final int? altesPortemonnaieCents;
  final String adminUid;
  final String kassenwartUid;

  /// Aktueller Code der Kasse; dort zählt die Anzahl der Bierwarte mit.
  final String einladungCode;

  /// Ob das Portemonnaie umzieht (alter Stand geht auf die neue UID).
  bool get umzug =>
      alteUid != null &&
      alteUid != anfrage.neueUid &&
      altesPortemonnaieCents != null;

  int get standCents => umzug ? altesPortemonnaieCents! : 0;
}
