import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_campus/core/constants.dart';
import 'package:smart_campus/core/utils.dart';
import 'package:smart_campus/data/models/models.dart';

/// PDF and CSV generation. The built in PDF fonts have no rupee glyph, so
/// amounts in documents are written as "Rs".
class ExportService {
  // ------------------------------------------------------------------ receipt
  static Future<Uint8List> receiptPdf({
    required Student student,
    required Payment payment,
    required int total,
    required int paidTotal,
  }) async {
    final doc = pw.Document();
    pw.Widget row(String l, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 120,
                child: pw.Text(l, style: const pw.TextStyle(color: PdfColors.grey700))),
            pw.Expanded(
                child: pw.Text(v, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          ]),
        );
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue900, width: 1.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(AppStrings.collegeName,
                  style: const pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            ),
            pw.Center(child: pw.Text('Fee Receipt', style: const pw.TextStyle(fontSize: 13))),
            pw.Divider(color: PdfColors.blue900),
            pw.SizedBox(height: 6),
            row('Receipt no', payment.receiptNo),
            row('Date', Fmt.date(payment.paidOn)),
            row('Student', student.name),
            row('Student ID', student.studentId),
            row('Program', '${student.program}, Semester ${student.semester}'),
            pw.SizedBox(height: 8),
            pw.Divider(),
            row('Amount paid', Fmt.rs(payment.amount)),
            row('Payment method', payment.method),
            row('Total fees', Fmt.rs(total)),
            row('Paid to date', Fmt.rs(paidTotal)),
            row('Balance', Fmt.rs(total - paidTotal > 0 ? total - paidTotal : 0)),
            pw.Spacer(),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Computer generated receipt',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            ),
          ],
        ),
      ),
    ));
    return doc.save();
  }

  static Future<void> showReceipt({
    required Student student,
    required Payment payment,
    required int total,
    required int paidTotal,
  }) async {
    final bytes = await receiptPdf(
        student: student, payment: payment, total: total, paidTotal: paidTotal);
    await Printing.layoutPdf(name: 'Receipt ${payment.receiptNo}', onLayout: (_) async => bytes);
  }

  // ------------------------------------------------------------------- report
  static Future<Uint8List> reportPdf(ReportData d, {String? subtitle}) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        pw.Text(AppStrings.collegeName,
            style: const pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.Text(d.title, style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            '${subtitle == null || subtitle.isEmpty ? '' : '$subtitle  |  '}Generated ${Fmt.date(DateTime.now())}  |  ${d.rows.length} records',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 14),
        if (d.rows.isEmpty)
          pw.Text('No records for the selected filters.')
        else
          pw.TableHelper.fromTextArray(
            context: ctx,
            headers: d.columns,
            data: d.rows,
            headerStyle: const pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
      ],
    ));
    return doc.save();
  }

  static Future<void> previewReport(ReportData d, {String? subtitle}) async {
    final bytes = await reportPdf(d, subtitle: subtitle);
    await Printing.layoutPdf(name: d.title, onLayout: (_) async => bytes);
  }

  static Future<void> shareReportPdf(ReportData d, {String? subtitle}) async {
    final bytes = await reportPdf(d, subtitle: subtitle);
    await Printing.sharePdf(bytes: bytes, filename: '${_fileStem(d.title)}.pdf');
  }

  static String _csvCell(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String reportCsv(ReportData d) {
    final buf = StringBuffer()..writeln(d.columns.map(_csvCell).join(','));
    for (final r in d.rows) {
      buf.writeln(r.map(_csvCell).join(','));
    }
    return buf.toString();
  }

  static Future<void> shareReportCsv(ReportData d) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, '${_fileStem(d.title)}.csv'));
    await file.writeAsString(reportCsv(d));
    await Share.shareXFiles([XFile(file.path)], text: d.title);
  }

  static String _fileStem(String title) =>
      '${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${Fmt.dbDate(DateTime.now())}';
}
