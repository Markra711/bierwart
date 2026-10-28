import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/fehler/verwaltung.dart';
import '../../../core/routing/router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/dialog.dart';
import '../../../core/widgets/eingaben.dart';
import '../../../core/widgets/flaechen.dart';
import '../../../core/widgets/karten.dart';
import '../../../core/widgets/knoepfe.dart';
import '../../../core/widgets/seite.dart';
import '../../../core/widgets/sheet.dart';
import '../../kader/application/kader_daten.dart';
import '../../kader/presentation/umbenennen_sheet.dart';
import '../../onboarding/data/anmeldung_repository.dart';
import '../../onboarding/domain/codes.dart';
import '../../onboarding/domain/einladung.dart';
import '../../strichliste/application/kasse_daten.dart';
import '../application/einstellungen.dart';
import '../domain/bierwart.dart';
import 'melden_sheet.dart';

/// Einstellungen, erreichbar über das Zahnrad auf jedem Tab (UI-02):
/// Einladungslink (UC-06, ADM-01), Bierwarte mit Rollen (ADM-02, ADM-03),
/// Kasse umbenennen (ADM-04) und der eigene Name (UI-09). Was nur der Admin
/// darf, sehen andere nicht.
class EinstellungenScreen extends ConsumerWidget {
  const EinstellungenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final admin = ref.watch(istAdminProvider);
    final bierwarte = ref.watch(bierwarteProvider);
    final uid = ref.watch(anmeldungProvider).value;
    final ich = (ref.watch(mitgliederProvider).value ?? const [])
        .where((m) => m.bierwartUid == uid && uid != null)
        .firstOrNull;
    // Hält den Stempel-Namen geladen, damit Aktionen sofort gehen.
    ref.watch(sitzungProvider);

    void zurueck() =>
        context.canPop() ? context.pop() : context.go(Routen.strichliste);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            BwSpacing.space4,
            BwSpacing.space4,
            BwSpacing.space4,
            BwSpacing.space6,
          ),
          children: [
            Row(
              children: [
                BwZurueck(onPressed: zurueck),
                const SizedBox(width: BwSpacing.space3),
                Expanded(
                  child: Semantics(
                    header: true,
                    container: true,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('EINSTELLUNGEN', style: text.pageTitle),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BwSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: BwSpacing.space1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BwLabel('Einladungslink'),
                  const SizedBox(height: BwSpacing.space3),
                  const _Einladungslink(),
                  const SizedBox(height: BwSpacing.space5),
                  const BwLabel('Bierwarte'),
                  const SizedBox(height: BwSpacing.space3),
                  switch (bierwarte) {
                    AsyncData(:final value) => _Bierwarte(
                      bierwarte: value,
                      uid: uid,
                      admin: admin,
                    ),
                    AsyncError() => const BwFehler(
                      'Die Bierwarte ließen sich nicht laden.',
                    ),
                    _ => const SizedBox.shrink(),
                  },
                  if (admin) ...[
                    const SizedBox(height: BwSpacing.space3),
                    const BwHinweis(
                      'Über „…“ entfernst du Bierwarte oder vergibst Rollen.',
                    ),
                  ],
                  const SizedBox(height: BwSpacing.space5),
                  const BwLabel('Kasse & ich'),
                  const SizedBox(height: BwSpacing.space3),
                  _Kacheln([
                    if (admin)
                      _Kachel(
                        text: 'Kasse umbenennen',
                        unterzeile: 'nur Admin',
                        onTap: () => _kasseUmbenennen(context),
                      ),
                    if (ich != null)
                      _Kachel(
                        text: 'Meinen Namen ändern',
                        onTap: () => zeigeUmbenennen(context, ich),
                      ),
                    if (admin)
                      _Kachel(
                        text: 'Neuer Wiederherstellungs\u00adcode',
                        unterzeile: 'nur Admin',
                        onTap: () => _codeErneuern(context, ref),
                      )
                    else
                      _Kachel(
                        text: 'Wiederherstellungs\u00adcode eingeben',
                        onTap: () => zeigeSheet<void>(
                          context,
                          titel: 'Admin werden',
                          inhalt: (_) => const _CodeEingeben(),
                        ),
                      ),
                    _Kachel(
                      text: 'Datenschutz',
                      onTap: () => context.push(Routen.datenschutz),
                    ),
                    _Kachel(
                      text: 'Melden',
                      onTap: () => zeigeSheet<void>(
                        context,
                        titel: 'Melden',
                        inhalt: (_) => const MeldenSheet(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: BwSpacing.space6),
                  Row(
                    children: [
                      Expanded(
                        child: BwKnopf(
                          text: 'Austreten',
                          art: BwKnopfArt.destruktiv,
                          onPressed: () => _austreten(context, ref),
                        ),
                      ),
                      if (admin) ...[
                        const SizedBox(width: BwSpacing.space3),
                        Expanded(
                          child: _AufloesenKnopf(
                            onPressed: () => zeigeSheet<void>(
                              context,
                              titel: 'Kasse auflösen',
                              inhalt: (_) => const _Aufloesen(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Neuer Wiederherstellungscode (ADM-08): danach genau einmal zeigen.
  Future<void> _codeErneuern(BuildContext context, WidgetRef ref) async {
    final ja = await bestaetigen(
      context,
      titel: 'Neuen Code erzeugen?',
      text:
          'Der bisherige Wiederherstellungscode gilt dann sofort nicht mehr. '
          'Den neuen siehst du nur einmal.',
      ja: 'Erzeugen',
      destruktiv: false,
    );
    if (!ja || !context.mounted) return;
    try {
      final code = await ref.read(verwaltungAktionenProvider).codeErneuern();
      if (context.mounted) zeigeNeuenCode(context, ref, code);
    } on VerwaltungsFehler catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.meldung)));
      }
    }
  }

  /// Austreten (UC-05, AUTH-09): erst sagen, was fehlt, dann bestätigen.
  Future<void> _austreten(BuildContext context, WidgetRef ref) async {
    final uid = ref.read(anmeldungProvider).value;
    final ich = ref
        .read(bierwarteProvider)
        .value
        ?.where((b) => b.uid == uid)
        .firstOrNull;
    final anzahl = ref.read(kasseInfoProvider).value?.anzahlBierwarte ?? 1;
    if (ich == null) return;
    final grund = austretenGeht(ich, anzahlBierwarte: anzahl);
    if (grund != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(grund)));
      return;
    }
    final folge = anzahl == 1
        ? 'Du bist der letzte Bierwart. Die Kasse bleibt bestehen, aber '
              'niemand kann mehr buchen. Zurück kommt man nur mit dem '
              'Wiederherstellungscode.'
        : 'Du kannst dann nicht mehr buchen und bleibst als Mitglied im '
              'Kader. Zurück geht es nur mit einem neuen Einladungslink.';
    final ja = await bestaetigen(
      context,
      titel: 'Austreten?',
      text: '$folge\n\n$austretenLoeschtKonto',
      ja: 'Austreten',
    );
    if (ja && context.mounted) {
      await verwalten(
        context,
        ref.read(verwaltungAktionenProvider).austreten,
        'Du bist ausgetreten.',
      );
    }
  }

  void _kasseUmbenennen(BuildContext context) => zeigeSheet<void>(
    context,
    titel: 'Kasse umbenennen',
    inhalt: (_) => const _KasseUmbenennen(),
  );
}

/// Führt eine Verwaltungsaktion aus und meldet Erfolg oder Fehler als
/// Snackbar (NFA-10).
Future<void> verwalten(
  BuildContext context,
  Future<void> Function() aktion,
  String erfolg,
) async {
  final boten = ScaffoldMessenger.of(context);
  try {
    await aktion();
    boten.showSnackBar(SnackBar(content: Text(erfolg)));
  } on VerwaltungsFehler catch (e) {
    boten.showSnackBar(SnackBar(content: Text(e.meldung)));
  }
}

const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// „Mo, 26.10.“
String gueltigBisText(DateTime t) =>
    '${_wochentage[t.weekday - 1]}, ${t.day.toString().padLeft(2, '0')}.'
    '${t.month.toString().padLeft(2, '0')}.';

/// Link mit Gültigkeit, „Teilen“ für alle, „Erneuern“ für den Admin
/// (UC-06, ADM-01).
class _Einladungslink extends ConsumerStatefulWidget {
  const _Einladungslink();

  @override
  ConsumerState<_Einladungslink> createState() => _EinladungslinkState();
}

class _EinladungslinkState extends ConsumerState<_Einladungslink> {
  bool _laeuft = false;

  Future<void> _erneuern() async {
    final ja = await bestaetigen(
      context,
      titel: 'Neuen Link erstellen?',
      text:
          'Der bisherige Link gilt dann sofort nicht mehr. Wer ihn noch '
          'nicht benutzt hat, braucht den neuen.',
      ja: 'Erneuern',
      destruktiv: false,
    );
    if (!ja || !mounted) return;
    setState(() => _laeuft = true);
    await verwalten(
      context,
      ref.read(verwaltungAktionenProvider).linkErneuern,
      'Neuer Link erstellt. Der alte gilt nicht mehr.',
    );
    if (mounted) setState(() => _laeuft = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    final kasse = ref.watch(kasseInfoProvider).value;
    final einladung = ref.watch(aktuelleEinladungProvider).value;
    final admin = ref.watch(istAdminProvider);
    final code = kasse?.einladungCode ?? '';
    final link = code.isEmpty ? null : einladungslink(code);
    final gueltig =
        einladung?.zustand(DateTime.now()) ?? EinladungsZustand.gueltig;
    final bis = einladung?.erstelltAm.add(Einladung.gueltigkeit);

    return BwErhaben(
      padding: const EdgeInsets.all(BwSpacing.space4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            right: -BwSpacing.space6,
            top: -BwSpacing.space6,
            child: BwSchraffur(durchmesser: 60, farbe: BwColors.lineStrong),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                link?.replaceFirst('https://', '') ?? '…',
                style: text.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (bis != null)
                Text(
                  gueltig == EinladungsZustand.gueltig
                      ? 'Gültig bis ${gueltigBisText(bis)} · alle dürfen ihn '
                            'teilen'
                      : admin
                      ? 'Abgelaufen. Erstell einen neuen Link.'
                      : 'Abgelaufen. Der Admin kann einen neuen erstellen.',
                  style: text.caption.copyWith(
                    color: gueltig == EinladungsZustand.gueltig
                        ? null
                        : BwColors.negative,
                  ),
                ),
              const SizedBox(height: BwSpacing.space3),
              Row(
                children: [
                  Expanded(
                    child: BwKnopf(
                      text: 'Teilen',
                      onPressed:
                          link == null || gueltig != EinladungsZustand.gueltig
                          ? null
                          : () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Komm in unsere Kasse „${kasse!.name}“: '
                                    '$link',
                              ),
                            ),
                    ),
                  ),
                  if (admin) ...[
                    const SizedBox(width: BwSpacing.space3),
                    Expanded(
                      child: BwKnopf(
                        text: 'Erneuern',
                        art: BwKnopfArt.outline,
                        laedt: _laeuft,
                        onPressed: _erneuern,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gruppierte Liste der Bierwarte; der Admin hat bei anderen ein Menü.
class _Bierwarte extends ConsumerWidget {
  const _Bierwarte({
    required this.bierwarte,
    required this.uid,
    required this.admin,
  });

  final List<Bierwart> bierwarte;
  final String? uid;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).extension<BwTextStyles>()!;
    return BwEingedrueckt(
      padding: const EdgeInsets.symmetric(vertical: BwSpacing.space1),
      child: Column(
        children: [
          for (final b in bierwarte)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.only(
                  left: BwSpacing.space4,
                  right: BwSpacing.space1,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: text.name),
                          Text(
                            bierwartZeile(b, ich: b.uid == uid),
                            style: text.caption,
                          ),
                        ],
                      ),
                    ),
                    SizedBox.square(
                      dimension: BwIconKnopf.groesse,
                      child: admin && b.uid != uid
                          ? IconButton(
                              tooltip: 'Aktionen für ${b.name}',
                              onPressed: () => _menue(context, ref, b),
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: BwColors.ink,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Rollen vergeben und entfernen (ADM-02, ADM-03, UI-04).
  void _menue(BuildContext context, WidgetRef ref, Bierwart b) {
    final aktionen = ref.read(verwaltungAktionenProvider);
    final grund = entfernenGeht(b);
    zeigeSheet<void>(
      context,
      titel: b.name,
      inhalt: (sheet) {
        Future<void> nach(
          Future<bool> Function() frage,
          Future<void> Function() aktion,
          String erfolg,
        ) async {
          Navigator.of(sheet).pop();
          if (await frage() && context.mounted) {
            await verwalten(context, aktion, erfolg);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!b.istKassenwart) ...[
              BwKnopf(
                text: 'Zum Kassenwart machen',
                art: BwKnopfArt.outline,
                onPressed: () => nach(
                  () => bestaetigen(
                    context,
                    titel: '${b.name} wird Kassenwart?',
                    text:
                        'Nur der Kassenwart bucht in die Kasse, nimmt '
                        'Übergaben an und macht den Kassensturz.',
                    ja: 'Kassenwart machen',
                    destruktiv: false,
                  ),
                  () => aktionen.rolleUebertragen(Rolle.kassenwart, b),
                  '${b.name} ist jetzt Kassenwart.',
                ),
              ),
              const SizedBox(height: BwSpacing.space4),
            ],
            BwKnopf(
              text: 'Admin-Rolle übergeben',
              art: BwKnopfArt.outline,
              onPressed: () => nach(
                () => bestaetigen(
                  context,
                  titel: 'Admin-Rolle an ${b.name}?',
                  text:
                      'Danach bist du normaler Bierwart. Zurück geht es '
                      'nur, wenn ${b.name} sie dir wieder gibt.',
                  ja: 'Übergeben',
                ),
                () => aktionen.rolleUebertragen(Rolle.admin, b),
                '${b.name} ist jetzt Admin.',
              ),
            ),
            const SizedBox(height: BwSpacing.space4),
            BwKnopf(
              text: 'Entfernen',
              art: BwKnopfArt.destruktiv,
              onPressed: grund != null
                  ? null
                  : () => nach(
                      () => bestaetigen(
                        context,
                        titel: '${b.name} entfernen?',
                        text:
                            '${b.name} kann nicht mehr buchen und bleibt als '
                            'Mitglied im Kader. Das Portemonnaie bleibt als '
                            '„ehemalig“ stehen, bis es per Übergabe auf 0 '
                            'ist. Der Einladungslink wird erneuert.',
                        ja: 'Entfernen',
                      ),
                      () => aktionen.entfernen(b),
                      '${b.name} ist nicht mehr Bierwart.',
                    ),
            ),
            if (grund != null) ...[
              const SizedBox(height: BwSpacing.space2),
              Text(
                grund,
                style: Theme.of(sheet).extension<BwTextStyles>()!.caption,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// „Kasse auflösen“: gestrichelt und schraffiert in `negative`, wie im
/// Design-Canvas; lauter als „Austreten“, weil es alles löscht.
class _AufloesenKnopf extends StatelessWidget {
  const _AufloesenKnopf({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!.button;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          height: BwKnopf.hoehe,
          child: CustomPaint(
            painter: const GestricheltPainter(
              radius: BwRadius.pill,
              farbe: BwColors.negative,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BwRadius.pill),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned(
                    right: -BwSpacing.space4,
                    child: BwSchraffur(
                      durchmesser: 80,
                      farbe: BwColors.negative,
                    ),
                  ),
                  Text(
                    'KASSE AUFLÖSEN',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: stil.copyWith(color: BwColors.negative),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Auflösen mit Warnung und abgetipptem Kassennamen (ADM-05, UC-10).
class _Aufloesen extends ConsumerStatefulWidget {
  const _Aufloesen();

  @override
  ConsumerState<_Aufloesen> createState() => _AufloesenState();
}

class _AufloesenState extends ConsumerState<_Aufloesen> {
  final _name = TextEditingController();
  String? _fehler;
  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _aufloesen() async {
    setState(() => _laeuft = true);
    try {
      await ref.read(verwaltungAktionenProvider).aufloesen(_name.text);
      // Die Weiterleitung führt zur Seite, die alles löscht.
      if (mounted) Navigator.of(context).pop();
    } on VerwaltungsFehler catch (e) {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _fehler = e.meldung;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(kasseInfoProvider).value?.name ?? '';
    final passt = aufloesenBestaetigt(_name.text, name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFehler(
          'Alles wird gelöscht: Kader, Striche, Lager, Geld und Verlauf. '
          'Das lässt sich nicht rückgängig machen.',
        ),
        const SizedBox(height: BwSpacing.space4),
        BwFeld(
          label: 'Zum Bestätigen „$name“ abtippen',
          controller: _name,
          aufSheet: true,
          platzhalter: name,
          schreibweise: TextCapitalization.none,
          eingabeAktion: TextInputAction.done,
          fehler: _fehler,
        ),
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(
          text: 'Kasse auflösen',
          art: BwKnopfArt.destruktiv,
          laedt: _laeuft,
          onPressed: passt ? _aufloesen : null,
        ),
      ],
    );
  }
}

/// Den neuen Wiederherstellungscode auf eigener Seite zeigen (ADM-06,
/// ADM-08).
void zeigeNeuenCode(BuildContext context, WidgetRef ref, String code) =>
    context.push(
      Routen.neuerCode,
      extra: (code, ref.read(kasseInfoProvider).value?.name ?? ''),
    );

/// Mit dem Wiederherstellungscode Admin werden (ADM-06, UC-04).
class _CodeEingeben extends ConsumerStatefulWidget {
  const _CodeEingeben();

  @override
  ConsumerState<_CodeEingeben> createState() => _CodeEingebenState();
}

class _CodeEingebenState extends ConsumerState<_CodeEingeben> {
  final _code = TextEditingController();
  String? _fehler;
  bool _laeuft = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _admin() async {
    setState(() => _laeuft = true);
    try {
      final neu = await ref
          .read(verwaltungAktionenProvider)
          .adminWiederherstellen(_code.text);
      if (!mounted) return;
      final seite = Navigator.of(context);
      seite.pop();
      if (seite.context.mounted) zeigeNeuenCode(seite.context, ref, neu);
    } on VerwaltungsFehler catch (e) {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _fehler = e.meldung;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BwErklaerung(
          'Mit dem Code, den der Gründer beim Erstellen der Kasse bekommen '
          'hat, wirst du Admin. Der bisherige Admin bleibt Bierwart, und es '
          'gibt einen neuen Code.',
        ),
        const SizedBox(height: BwSpacing.space4),
        BwFeld(
          label: 'Wiederherstellungscode',
          controller: _code,
          aufSheet: true,
          autofocus: true,
          platzhalter: 'K7QM-3XRA-9DWF-T2HC',
          schreibweise: TextCapitalization.characters,
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _laeuft ? null : _admin(),
          fehler: _fehler,
        ),
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(
          text: 'Admin werden',
          gross: true,
          laedt: _laeuft,
          onPressed: _admin,
        ),
      ],
    );
  }
}

/// Zwei Spalten erhabener Kacheln (Design-Canvas, „Kasse & ich“).
class _Kacheln extends StatelessWidget {
  const _Kacheln(this.kacheln);

  final List<_Kachel> kacheln;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, raum) {
        final breite = (raum.maxWidth - BwSpacing.space4) / 2;
        return Wrap(
          spacing: BwSpacing.space4,
          runSpacing: BwSpacing.space4,
          children: [
            for (final k in kacheln) SizedBox(width: breite, child: k),
          ],
        );
      },
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({required this.text, required this.onTap, this.unterzeile});

  final String text;
  final String? unterzeile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).extension<BwTextStyles>()!;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: BwErhaben(
          radius: BwRadius.lg,
          schatten: BwShadows.raisedSm,
          padding: const EdgeInsets.symmetric(
            horizontal: BwSpacing.space4,
            vertical: BwSpacing.space3,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: stil.body.copyWith(fontWeight: FontWeight.w700),
                ),
                if (unterzeile != null) Text(unterzeile!, style: stil.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// „Kasse umbenennen“ (ADM-04): wartet auf den Server.
class _KasseUmbenennen extends ConsumerStatefulWidget {
  const _KasseUmbenennen();

  @override
  ConsumerState<_KasseUmbenennen> createState() => _KasseUmbenennenState();
}

class _KasseUmbenennenState extends ConsumerState<_KasseUmbenennen> {
  late final _name = TextEditingController(
    text: ref.read(kasseInfoProvider).value?.name ?? '',
  );
  String? _fehler;
  bool _laeuft = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    setState(() => _laeuft = true);
    try {
      final fehler = await ref
          .read(verwaltungAktionenProvider)
          .kasseUmbenennen(_name.text);
      if (!mounted) return;
      if (fehler == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _fehler = fehler);
    } on VerwaltungsFehler catch (e) {
      if (mounted) setState(() => _fehler = e.meldung);
    }
    if (mounted) setState(() => _laeuft = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BwFeld(
          label: 'Name der Kasse',
          controller: _name,
          aufSheet: true,
          autofocus: true,
          eingabeAktion: TextInputAction.done,
          onSubmitted: (_) => _laeuft ? null : _speichern(),
          fehler: _fehler,
          hinweis: 'Der Name steht auch in der Einladung.',
        ),
        const SizedBox(height: BwSpacing.space6),
        BwKnopf(
          text: 'Umbenennen',
          gross: true,
          laedt: _laeuft,
          onPressed: _speichern,
        ),
      ],
    );
  }
}
