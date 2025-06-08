import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
          'http://api.labelary.com/v1/printers/8dpmm/labels/3.15x0.98',
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
    required String originPath,
    required String destinyPath,
    required BuildContext context,
    required Function(bool) changeIsLoading,
  }) async {
    changeIsLoading(true);
    final dir = Directory(originPath);
    if (!dir.existsSync()) {
      SnackMessage.show("Pasta não existe", Colors.red, context);
      changeIsLoading(false);
      return;
    }

    // 1) Extrai só o primeiro bloco ^XA…^XZ de cada arquivo
    final List<String> blocks = [];
    final regex = RegExp(
      r'\^XA.*?\^XZ',
      caseSensitive: false,
      dotAll: true,
    );
    for (final ent in dir.listSync().whereType<File>()) {
      if (!ent.path.toLowerCase().endsWith('.txt')) continue;
      final content = await ent.readAsString();
      for (final m in regex.allMatches(content)) {
        blocks.add(m.group(0)!);
      }
    }

    if (blocks.isEmpty) {
      SnackMessage.show("Nenhuma etiqueta encontrada", Colors.orange, context);
      changeIsLoading(false);
      return;
    }

    // 2) Monta o ZPL único com 1 bloco por arquivo
    final allZpl = blocks.join('\n\n');

    try {
      // 3) Uma única requisição → PDF com 4 páginas
      final uri = Uri.parse(
          'http://api.labelary.com/v1/printers/8dpmm/labels/3.15x0.98/'); // sem índice, para multi-page
      final req = http.Request('POST', uri)
        ..headers['Accept'] = 'application/pdf'
        ..headers['Content-Type'] = 'application/x-www-form-urlencoded'
        ..body = allZpl;

      final resp = await req.send();
      if (resp.statusCode == 200) {
        final bytes = await resp.stream.toBytes();
        final outPath = '$destinyPath/all_labels_merged.pdf';
        await File(outPath).writeAsBytes(bytes);
        SnackMessage.show(
          "PDF gerado em all_labels_merged.pdf",
          Colors.green,
          context,
        );
      } else {
        SnackMessage.show(
          "Erro ${resp.statusCode}: ${resp.reasonPhrase}",
          Colors.red,
          context,
        );
      }
    } catch (e) {
      SnackMessage.show("Falha na requisição: $e", Colors.red, context);
    }

    changeIsLoading(false);
  }

  static Future<void> mergePdfs(
      List<String> inputPaths, String outputPath) async {
    // 1) Create an empty document
    final PdfDocument merged = PdfDocument();
    PdfSection? section;

    // 2) Loop through each source PDF
    for (final pdfPath in inputPaths) {
      // Read the bytes and load
      final List<int> data = File(pdfPath).readAsBytesSync();
      final PdfDocument src = PdfDocument(inputBytes: data);

      // 3) For every page in the source...
      for (int i = 0; i < src.pages.count; i++) {
        final PdfPage page = src.pages[i];

        // Create a template of the entire page
        final PdfTemplate tpl = page.createTemplate();

        // 4) If this is the first page (or the size changed), make a new section
        if (section == null || section.pageSettings.size != tpl.size) {
          section = merged.sections!.add();
          section.pageSettings.size = tpl.size;
          section.pageSettings.margins.all = 0;
        }

        // 5) Add a new page in that section and draw the template at the top-left
        section.pages.add().graphics.drawPdfTemplate(tpl, const Offset(0, 0));
      }

      src.dispose();
    }

    // 6) Save & write out
    final List<int> bytes = await merged.save();
    merged.dispose();
    await File(outputPath).writeAsBytes(bytes);
  }
}
