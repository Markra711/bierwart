import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Codes für Einladung und Wiederherstellung (architecture.md, „Format des
// Wiederherstellungscodes“ und „Einladungslinks“).

/// Crockford-Base32: Ziffern und Großbuchstaben ohne I, L, O, U.
const crockford = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

/// 16 Zeichen = 80 Bit (AUTH-03, ADM-06).
const wiederherstellungscodeLaenge = 16;

/// 20 Zeichen = 100 Bit. Ohne Server-Code gibt es keine Bremse gegen
/// Durchprobieren, deshalb mindestens 96 Bit (AUTH-08).
const einladungscodeLaenge = 20;

const einladungslinkBasis = 'https://bier-wart.web.app/j/';

/// Zufälliger Code aus [crockford], standardmäßig mit `Random.secure()`.
String zufallsCode(int laenge, [Random? zufall]) {
  final r = zufall ?? Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < laenge; i++) crockford.codeUnitAt(r.nextInt(32)),
  ]);
}

/// Die Form, die gehasht und verglichen wird: Großbuchstaben, ohne
/// Bindestriche und Leerzeichen, O → 0, I und L → 1.
String normalisiereCode(String eingabe) => eingabe
    .toUpperCase()
    .replaceAll(RegExp(r'[\s-]'), '')
    .replaceAll('O', '0')
    .replaceAll(RegExp('[IL]'), '1');

bool istCode(String code, int laenge) =>
    code.length == laenge && code.split('').every(crockford.contains);

/// Anzeige in Vierergruppen: `K7QM-3XRA-9DWF-T2HC`.
String inGruppen(String code) => [
  for (var i = 0; i < code.length; i += 4)
    code.substring(i, min(i + 4, code.length)),
].join('-');

/// SHA-256 des normalisierten Codes, wie ihn die Rules mit
/// `hashing.sha256()` nachrechnen.
Uint8List hashVon(String normalisierterCode) =>
    Uint8List.fromList(sha256.convert(utf8.encode(normalisierterCode)).bytes);

/// Dokument-ID unter `wiederherstellung/`: Hex in Kleinbuchstaben.
String hexVon(List<int> hash) =>
    hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String einladungslink(String code) => '$einladungslinkBasis$code';

/// Code aus einem eingefügten Link oder dem Code allein; `null`, wenn keiner
/// erkennbar ist.
String? einladungscodeAus(String eingabe) {
  var roh = eingabe.trim();
  final pfad = roh.lastIndexOf('/j/');
  if (pfad >= 0) roh = roh.substring(pfad + 3);
  roh = roh.split(RegExp(r'[/?#]')).first;
  final code = normalisiereCode(roh);
  return istCode(code, einladungscodeLaenge) ? code : null;
}

/// Host der Einladungslinks (Firebase Hosting, AUTH-04).
const einladungslinkHost = 'bier-wart.web.app';

/// Code aus einem App-Link `https://bier-wart.web.app/j/{code}`; `null` für
/// fremde Links.
String? einladungscodeAusLink(Uri link) {
  if (link.host != einladungslinkHost) return null;
  if (link.pathSegments.length < 2 || link.pathSegments.first != 'j') {
    return null;
  }
  return einladungscodeAus(link.pathSegments[1]);
}

/// Code aus dem Play-Store-Referrer nach der Installation (AUTH-12). Die
/// Fallback-Seite setzt `referrer=code%3D{code}`, Google Play liefert
/// `code={code}`.
String? einladungscodeAusReferrer(String? referrer) {
  if (referrer == null || referrer.isEmpty) return null;
  final code = Uri.splitQueryString(referrer)['code'];
  return code == null ? null : einladungscodeAus(code);
}
