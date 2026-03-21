import 'package:pdf/pdf.dart';
import 'dart:typed_data'; 
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Added for Timestamp check
import '../utils/helpers.dart'; 

class PdfService {
  
  // Helper for detailed rows
  // Helper for Table Row
  pw.TableRow _tableRow(String label, String value, pw.Font font, pw.Font fontBold) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 10)),
        ),
      ]
    );
  }

  // Helper for Signature Box
  pw.Widget _signatureBox(String title, pw.Font font) {
     return pw.Column(
       children: [
         pw.Container(width: 80, height: 1, color: PdfColors.black),
         pw.SizedBox(height: 4),
         pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10)),
       ]
     );
  }

  /// Generates the PDF bytes for the application form
  Future<Uint8List> generatePdfBytes(Map<String, dynamic> request) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // Data Extraction & Handling
    final String leaveType = request['leaveType'] ?? 'Leave';
    final double days = (request['numberOfDays'] ?? 0.0).toDouble();
    final dynamic fromVal = request['fromDate'];
    final dynamic toVal = request['toDate'];
    final dynamic appliedVal = request['appliedAt'] ?? request['createdAt'];
    
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime fromDate = parseDate(request['fromDate']);
    DateTime toDate = parseDate(request['toDate']);
    DateTime appliedAt = parseDate(request['appliedAt'] ?? request['createdAt']);

    final String userName = request['userName'] ?? 'User';
    final String? employeeId = request['employeeId'];
    final String status = request['status'] ?? 'Pending';
    final String reason = request['reason'] ?? 'Personal';

    // Logic for Day vs Days
    final isHalfDay = days == 0.5;
    final isSingleDay = days == 1.0 || isHalfDay;
    final durationText = isHalfDay ? "Half Day" : "$days ${days == 1.0 ? 'Day' : 'Days'}";

    // Logic for Date Text
    String dateText;
    if (isSingleDay) {
      dateText = "${DateFormat('dd-MM-yyyy').format(fromDate)} (Single Day)";
    } else {
      dateText = "${DateFormat('dd-MM-yyyy').format(fromDate)} To ${DateFormat('dd-MM-yyyy').format(toDate)}";
    }

    // Logic for Content
    final isCredit = leaveType.toUpperCase().contains('COMP-OFF EARN');
    final titleText = isCredit ? "WORK CREDIT APPLICATION FORM" : "LEAVE APPLICATION FORM";
    
    String subjectText;
    String bodyText;

    if (isCredit) {
      subjectText = "Sub: Requisition for Comp-Off Credit - Reg.";
      bodyText = "I would like to inform you that I worked $dateText for the reason: \"$reason\". Hence, I request you to kindly credit $durationText to my leave account.";
    } else {
      subjectText = "Sub: Requisition for ${Helpers.getLeaveName(leaveType)} - Reg.";
      bodyText = "I would like to inform you that I am unable to attend my duties due to the following reason: \"$reason\". Hence, I request you to kindly grant me leave $dateText ($durationText).";
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🏫 HEADER
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text("KONGU ENGINEERING COLLEGE", style: pw.TextStyle(font: fontBold, fontSize: 16)),
                    pw.Text("(Autonomous)", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.Text("PERUNDURAI, ERODE - 638 060", style: pw.TextStyle(font: fontBold, fontSize: 10)),
                    pw.SizedBox(height: 10),
                    pw.Text(titleText, style: pw.TextStyle(font: fontBold, fontSize: 12, decoration: pw.TextDecoration.underline)),
                  ]
                )
              ),
              pw.SizedBox(height: 20),

              // 📋 APPLICANT DETAILS TABLE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                   _tableRow("Application No", request['applicationId'] ?? 'N/A', font, fontBold),
                   _tableRow("Date of Application", DateFormat('dd-MM-yyyy').format(appliedAt), font, fontBold),
                   _tableRow("Name of the Applicant", userName.toUpperCase(), font, fontBold),
                   if (employeeId != null && employeeId != "0000")
                     _tableRow("Employee ID", employeeId, font, fontBold),
                   _tableRow("Type of Leave", Helpers.getLeaveName(leaveType), font, fontBold),
                   _tableRow(isCredit ? "Worked Date" : "Period of Leave", dateText, font, fontBold),
                   _tableRow("No. of Days", durationText, font, fontBold),
                   _tableRow("Reason for Leave", reason, font, fontBold),
                ]
              ),
              
              pw.SizedBox(height: 15),
              
              // Declaration
              pw.Text("Declaration:", style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.SizedBox(height: 5),
              pw.Text(
                "I hereby request that the above leave may kindly be granted. I have made alternative arrangements for my duties during my absence.",
                style: pw.TextStyle(font: font, fontSize: 10),
                textAlign: pw.TextAlign.justify
              ),

              pw.Spacer(),

              // ✍️ SIGNATURES
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 40, bottom: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _signatureBox("Signature of the Staff", font),
                    _signatureBox("Placement Admin", font),
                    _signatureBox("Principal", font),
                  ]
                )
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Opens the PDF in the native print preview (Standard)
  Future<void> generateApplicationPdf(Map<String, dynamic> request) async {
    final bytes = await generatePdfBytes(request);
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Application_${request['userName'] ?? 'User'}',
    );
  }
}
