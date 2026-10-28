import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Kontakt des Betreibers, wie auf `bier-wart.web.app/datenschutz`.
const kontaktEmail = 'bierwart.app@gmail.com';

/// Nutzungsbedingungen im Web (NFA-13).
final nutzungsbedingungenUrl = Uri.parse(
  'https://bier-wart.web.app/nutzungsbedingungen',
);

/// Öffnet Webseiten und E-Mails außerhalb der App. Tests überschreiben den
/// Provider.
abstract interface class LinkOeffner {
  /// `false`, wenn kein Browser oder Mail-Programm den Link annimmt.
  Future<bool> oeffnen(Uri ziel);
}

class GeraeteLinkOeffner implements LinkOeffner {
  @override
  Future<bool> oeffnen(Uri ziel) async {
    try {
      return await launchUrl(ziel, mode: LaunchMode.externalApplication);
    } on Exception {
      return false;
    }
  }
}

final linkOeffnerProvider = Provider<LinkOeffner>(
  (ref) => GeraeteLinkOeffner(),
);
