import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../wallet/domain/models/wallet_transaction.dart';

class ReceiptGenerator {
  /// Builds the premium PDF Document
  static Future<pw.Document> _buildPdf(WalletTransaction txn) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Fallback if logo not found
    }

    final String amountStr = CurrencyFormatter.fromPaise(txn.amountPaise);
    final String dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(txn.completedAt);
    
    // Calculate display values
    final bool hasCommission = txn.commissionEarnedPaise > 0;
    final int walletDebitedPaise = txn.isDebit 
      ? (hasCommission ? txn.amountPaise - txn.commissionEarnedPaise : txn.amountPaise)
      : 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(24),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF8FAFC),
                    borderRadius: pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(16),
                      topRight: pw.Radius.circular(16),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (logoImage != null)
                            pw.Image(logoImage, width: 120)
                          else
                            pw.Text(
                              'A1 Recharge',
                              style: pw.TextStyle(
                                fontSize: 24,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue800,
                              ),
                            ),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            'Retailer Receipt',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: PdfColors.grey600,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        width: 80,
                        height: 80,
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: txn.referenceId,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Divider(color: PdfColors.grey300, thickness: 1, height: 1),
                
                // Transaction Details
                pw.Padding(
                  padding: const pw.EdgeInsets.all(24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfRow('Transaction Type', txn.transactionTitle),
                      if (txn.operatorName.isNotEmpty)
                        _buildPdfRow('Operator', txn.operatorName),
                      if (txn.customerIdentifier.isNotEmpty)
                        _buildPdfRow('Mobile / Identifier', txn.customerIdentifier),
                      
                      pw.SizedBox(height: 16),
                      pw.Divider(color: PdfColors.grey200, thickness: 1),
                      pw.SizedBox(height: 16),

                      _buildPdfRow('Recharge Amount', amountStr, isBold: true, valueColor: PdfColors.black),
                      if (hasCommission)
                        _buildPdfRow('Commission Earned', '+${CurrencyFormatter.fromPaise(txn.commissionEarnedPaise)}', valueColor: PdfColors.green700),
                      if (txn.isDebit)
                        _buildPdfRow('Wallet Debited', CurrencyFormatter.fromPaise(walletDebitedPaise)),
                      
                      pw.SizedBox(height: 16),
                      pw.Divider(color: PdfColors.grey200, thickness: 1),
                      pw.SizedBox(height: 16),

                      _buildPdfRow('Status', txn.status.name.toUpperCase(), valueColor: txn.status == TransactionStatus.success ? PdfColors.green700 : PdfColors.red700),
                      _buildPdfRow('Transaction ID', txn.referenceId),
                      if (txn.apiReference != null && txn.apiReference!.isNotEmpty)
                        _buildPdfRow('Operator Ref', txn.apiReference!),
                      _buildPdfRow('Date & Time', dateStr),
                    ],
                  ),
                ),

                pw.Spacer(),
                
                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(24),
                  decoration: const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFF1F5F9),
                    borderRadius: pw.BorderRadius.only(
                      bottomLeft: pw.Radius.circular(16),
                      bottomRight: pw.Radius.circular(16),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Generated by A1 Recharge', style: pw.TextStyle(color: PdfColors.grey700, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Text('vasavitechsolutions06@gmail.com', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 12)),
                        ],
                      ),
                      pw.Text('www.a1recharge.in', style: pw.TextStyle(color: PdfColors.blue700, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildPdfRow(String label, String value, {bool isBold = false, PdfColor valueColor = PdfColors.grey800}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Share as PDF
  static Future<void> sharePdf(WalletTransaction txn) async {
    final pdf = await _buildPdf(txn);
    final bytes = await pdf.save();
    
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Receipt_${txn.referenceId}.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Receipt for ${txn.transactionTitle} - ${txn.referenceId}');
  }

  /// Download as PDF
  static Future<void> downloadPdf(WalletTransaction txn) async {
    final pdf = await _buildPdf(txn);
    final bytes = await pdf.save();
    
    // Typically you'd use path_provider's getDownloadsDirectory or external storage
    // But for a cross-platform reliable approach, we use printing package's save dialog
    await Printing.sharePdf(bytes: bytes, filename: 'Receipt_${txn.referenceId}.pdf');
  }

  /// Share as Image
  static Future<void> shareImage(WalletTransaction txn) async {
    final pdf = await _buildPdf(txn);
    final bytes = await pdf.save();
    
    // Rasterize the first page to an image
    final images = await Printing.raster(bytes, pages: [0], dpi: 200).toList();
    if (images.isEmpty) return;

    final image = images.first;
    final imgBytes = await image.toPng();

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Receipt_${txn.referenceId}.png');
    await file.writeAsBytes(imgBytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Receipt for ${txn.transactionTitle} - ${txn.referenceId}');
  }
}
