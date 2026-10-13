import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/invite_link.dart';
import '../utils/settlement.dart';
import '../utils/statement.dart';
import '../utils/statement_wording.dart';

const _regularFont = 'assets/fonts/NotoSans-Regular.ttf';
const _boldFont = 'assets/fonts/NotoSans-Bold.ttf';

/// The app icon, small and as JPEG: `pdf` embeds a JPEG as it is, where the
/// 1024px WebP would be decoded in Dart and stored uncompressed.
const _logo = 'assets/images/split_pdf_logo.jpg';

/// The app's own light colours, so the PDF stays on brand if the theme
/// changes.
final _scheme = AppTheme.light.colorScheme;
final _brand = _pdfColor(_scheme.primary);
final _ink = _pdfColor(_scheme.onSurface);
final _muted = _pdfColor(_scheme.onSurfaceVariant);
final _rule = _pdfColor(_scheme.outlineVariant);
final _panel = _pdfColor(_scheme.surfaceContainer);
final _positive = _pdfColor(_scheme.positive);
final _negative = _pdfColor(_scheme.error);

PdfColor _pdfColor(Color color) => PdfColor.fromInt(color.toARGB32());

/// e.g. `Split statement - Rohit - Goa Trip - 2026-10-11.pdf`, without the
/// characters file systems refuse.
String statementFileName(Statement statement) {
  final date = statement.generatedAt;
  final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final name = 'Split statement - ${statement.memberName} - '
      '${statement.groupName} - $day';
  return '${name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').trim()}.pdf';
}

/// [statement] as an A4 PDF, every transaction included, in Split's
/// branding: the icon and name heading the first page, a running header on
/// the others, and "Powered by Split" with a link to the site on every page.
///
/// Drawn with the bundled Noto Sans (the PDF's built-in fonts have no ₹),
/// which is subset to Latin, punctuation and currency symbols. Anything else
/// in a name or title, such as an emoji or another script, would come out as
/// nothing or a box, so it is left out.
Future<Uint8List> statementPdf(Statement statement, Currency currency) async {
  final regular = await rootBundle.load(_regularFont);
  final bold = await rootBundle.load(_boldFont);
  final logo =
      pw.MemoryImage((await rootBundle.load(_logo)).buffer.asUint8List());
  final glyphs = TtfParser(regular).charToGlyphIndexMap.keys.toSet();
  final s = _drawable(statement, glyphs);
  final name = s.memberName;

  String signed(int minor) => minor > 0
      ? '+${currency.format(minor)}'
      : minor < 0
          ? '−${currency.format(-minor)}'
          : currency.format(0);

  PdfColor tone(int minor) => minor > 0
      ? _positive
      : minor < 0
          ? _negative
          : _muted;

  final doc = pw.Document(
    title: 'Statement for $name, ${s.groupName}',
    subject: 'Group expense statement',
    author: 'Split',
    creator: 'Split',
    producer: 'Split',
    theme: pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    ).copyWith(
      defaultTextStyle: pw.TextStyle(fontSize: 10, color: _ink),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 28),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _runningHeader(logo, name, s.groupName),
      footer: (context) => _footer(logo, context),
      build: (context) => [
        _letterhead(logo, s.generatedAt),
        pw.SizedBox(height: 20),
        pw.Text(
          name,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '${s.groupName} · Amounts in ${currency.name}',
          style: pw.TextStyle(color: _muted),
        ),
        pw.SizedBox(height: 16),
        _summary(s, currency, tone(s.balance)),
        if (s.settleUp.isNotEmpty) ...[
          pw.SizedBox(height: 18),
          _heading('To settle up'),
          for (final SuggestedPayment payment in s.settleUp)
            pw.Bullet(
              text: settleUpWords(payment, currency),
              style: const pw.TextStyle(fontSize: 10),
              bulletColor: _brand,
              margin: const pw.EdgeInsets.only(top: 2, bottom: 2),
            ),
        ],
        pw.SizedBox(height: 18),
        _heading('Transactions (${s.lines.length})'),
        if (s.lines.isEmpty)
          pw.Text('None yet.', style: pw.TextStyle(color: _muted))
        else
          pw.Table(
            columnWidths: const {
              0: pw.FixedColumnWidth(72),
              1: pw.FlexColumnWidth(),
              2: pw.FixedColumnWidth(84),
              3: pw.FixedColumnWidth(90),
            },
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
              bottom: pw.BorderSide(color: _rule, width: 0.5),
            ),
            children: [
              pw.TableRow(
                repeat: true,
                decoration: pw.BoxDecoration(color: _panel),
                children: [
                  _headerCell('Date'),
                  _headerCell('Details'),
                  _headerCell('Change', right: true),
                  _headerCell('Balance', right: true),
                ],
              ),
              for (final line in s.lines)
                pw.TableRow(
                  children: [
                    _cell(pw.Text(statementDateFormat.format(line.date))),
                    _cell(pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(statementLineTitle(line)),
                        pw.SizedBox(height: 1),
                        pw.Text(
                          statementLineDetail(line, name, currency),
                          style: pw.TextStyle(fontSize: 8, color: _muted),
                        ),
                      ],
                    )),
                    _cell(
                      pw.Text(
                        signed(line.change),
                        style: pw.TextStyle(color: tone(line.change)),
                      ),
                      right: true,
                    ),
                    _cell(pw.Text(signed(line.balance)), right: true),
                  ],
                ),
            ],
          ),
        pw.SizedBox(height: 14),
        pw.Text(
          "Change is what each transaction did to $name's balance. A positive "
          'balance is what $name gets back; a negative one is what $name '
          "owes. Prepared by Split from the group's records on "
          '${statementDateTimeFormat.format(s.generatedAt)}.',
          style: pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _icon(pw.ImageProvider logo, double size) => pw.ClipRRect(
      horizontalRadius: size * 0.22,
      verticalRadius: size * 0.22,
      child: pw.Image(logo, width: size, height: size),
    );

/// The first page's heading: the app's icon and name, and what this is.
pw.Widget _letterhead(pw.ImageProvider logo, DateTime generatedAt) => pw.Column(
      children: [
        pw.Row(
          children: [
            _icon(logo, 36),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Split',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Group expenses made easy',
                  style: pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.6,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  statementDateTimeFormat.format(generatedAt),
                  style: pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: _brand),
      ],
    );

/// Heads every page after the first, so a loose page still says whose
/// statement it is.
pw.Widget _runningHeader(
  pw.ImageProvider logo,
  String name,
  String groupName,
) =>
    pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1)),
      ),
      child: pw.Row(
        children: [
          _icon(logo, 14),
          pw.SizedBox(width: 6),
          pw.Text(
            'Split',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Spacer(),
          pw.Text(
            "$name's statement · $groupName",
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );

pw.Widget _footer(pw.ImageProvider logo, pw.Context context) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.5)),
      ),
      child: pw.Row(
        children: [
          _icon(logo, 12),
          pw.SizedBox(width: 5),
          pw.Text(
            'Powered by ',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
          pw.Text(
            'Split',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(' · ', style: pw.TextStyle(fontSize: 8, color: _muted)),
          pw.UrlLink(
            destination: 'https://$inviteLinkHost',
            child: pw.Text(
              inviteLinkHost,
              style: pw.TextStyle(fontSize: 8, color: _brand),
            ),
          ),
          pw.Spacer(),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );

pw.Widget _summary(Statement s, Currency currency, PdfColor tone) {
  pw.Widget figure(String label, int minor) => pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _muted)),
            pw.Text(currency.format(minor)),
          ],
        ),
      );

  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      color: _panel,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          statementHeadline(s, currency),
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: tone,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          figure('Paid for expenses', s.paidForExpenses),
          figure('Share of expenses', s.shareOfExpenses),
          figure('Payments made', s.paymentsSent),
          figure('Payments received', s.paymentsReceived),
        ]),
      ],
    ),
  );
}

pw.Widget _heading(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _headerCell(String text, {bool right = false}) => _cell(
      pw.Text(
        text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      right: right,
    );

pw.Widget _cell(pw.Widget child, {bool right = false}) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: right ? pw.Alignment.topRight : pw.Alignment.topLeft,
      child: child,
    );

/// [statement] with every name and title reduced to what the font can draw.
Statement _drawable(Statement statement, Set<int> glyphs) {
  String keep(String? text, String fallback) {
    final kept = String.fromCharCodes((text ?? '').runes.where(glyphs.contains))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return kept.isEmpty ? fallback : kept;
  }

  return Statement(
    userId: statement.userId,
    memberName: keep(statement.memberName, 'Member'),
    groupName: keep(statement.groupName, 'Group'),
    generatedAt: statement.generatedAt,
    paidForExpenses: statement.paidForExpenses,
    shareOfExpenses: statement.shareOfExpenses,
    paymentsSent: statement.paymentsSent,
    paymentsReceived: statement.paymentsReceived,
    settleUp: [
      for (final p in statement.settleUp)
        SuggestedPayment(
          from: p.from,
          fromName: keep(p.fromName, 'Member'),
          to: p.to,
          toName: keep(p.toName, 'Member'),
          amount: p.amount,
        ),
    ],
    lines: [
      for (final line in statement.lines)
        StatementLine(
          date: line.date,
          kind: line.kind,
          title: keep(line.title, 'Expense'),
          paidByName: keep(line.paidByName, 'Member'),
          counterpartName: line.counterpartName == null
              ? null
              : keep(line.counterpartName, 'Member'),
          total: line.total,
          paid: line.paid,
          share: line.share,
          balance: line.balance,
        ),
    ],
  );
}
