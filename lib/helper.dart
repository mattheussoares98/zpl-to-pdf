import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:pdf_combiner/responses/pdf_combiner_status.dart';

import 'snack_message.dart';

class Helper {
  Helper._();

  static Future<String?> selectFolder(BuildContext context) async {
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: 'Confirmar',
    );

    if (directoryPath != null) {
      return directoryPath;
    }

    SnackMessage.show("Nenhuma pasta selecionada", Colors.red, context);
    return null;
  }

  static int countLabels(String zpl) {
    final matches = RegExp(
      r'\^XA',
      caseSensitive: false,
    ).allMatches(zpl).toList();
    debugPrint('Found ^XA ${matches.length} times');
    return matches.length;
  }

  static Future<void> convertFile({
    required File file,
    required String destinyPath,
    required List<String> generatedPdfs,
    required List<String> filesSucceeds,
    required List<String> filesWithErrors,
  }) async {
    try {
      var headers = {
        'Accept': 'application/pdf',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      var request = http.Request(
        'POST',
        Uri.parse(
          'http://api.labelary.com/v1/printers/8dpmm/labels/3.15x0.98/0/',
        ),
      );

      final fileContent = await file.readAsString();
      request.body = fileContent; // Put file content here
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        // load the returned PDF into a temporary PdfDocument
        // write a single PDF for this ZPL:
        final outPath =
            '$destinyPath/${path.basenameWithoutExtension(file.path)}.pdf';
        final outFile = File(outPath);
        await outFile.writeAsBytes(bytes);
        generatedPdfs.add(outPath);

        filesSucceeds.add(file.path);
      } else {
        debugPrint('Error: ${response.statusCode} - ${response.reasonPhrase}');
        filesWithErrors.add(file.path);
      }
    } catch (e) {
      debugPrint('Exception: $e');
    }
  }

  static Future<void> convertPath({
    required String path,
    required String destinyPath,
    required BuildContext context,
    required Function(bool) changeIsLoading,
    required List<String> generatedPdfs,
    required List<String> filesSucceeds,
    required List<String> filesWithErrors,
  }) async {
    final directory = Directory(path);
    changeIsLoading(true);
    filesSucceeds = [];
    filesWithErrors = [];
    generatedPdfs.clear();

    if (directory.existsSync()) {
      final files = directory.listSync();

      for (final f in files) {
        if (f is File && f.path.endsWith('.txt')) {
          await Helper.convertFile(
            file: f,
            destinyPath: destinyPath,
            generatedPdfs: generatedPdfs,
            filesSucceeds: filesSucceeds,
            filesWithErrors: filesWithErrors,
          );
        }
      }

      // Now merge:
      final mergedOutput = '$destinyPath/all_labels_merged.pdf';
      final mergeResponse = await PdfCombiner.mergeMultiplePDFs(
        inputPaths: generatedPdfs,
        outputPath: mergedOutput,
      );

      if (mergeResponse.status == PdfCombinerStatus.success) {
        debugPrint('Merged PDF saved to: ${mergeResponse.outputPath}');
        SnackMessage.show(
          "PDF final gerado em: all_labels_merged.pdf",
          Colors.green,
          context,
        );
      } else {
        debugPrint('Merge error: ${mergeResponse.message}');
        SnackMessage.show(
          "Erro ao mesclar PDFs: ${mergeResponse.message}",
          Colors.red,
          context,
        );
      }
    }

    changeIsLoading(false);
  }
}
