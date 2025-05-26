// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZPL to PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? _originPath;
  String? _destinyPath;
  bool isLoading = false;
  List<String> filesSucceeds = [];
  List<String> filesWithErrors = [];

  String get originPath {
    if (_originPath == null) {
      return "Selecione a pasta de origem";
    } else {
      return _originPath!;
    }
  }

  String get destinyPath {
    if (_destinyPath == null && _originPath == null) {
      return "";
    } else if (_destinyPath != null) {
      return _destinyPath!;
    } else {
      return _originPath!;
    }
  }

  Future<String?> selectFolder() async {
    final String? directoryPath = await getDirectoryPath(
      confirmButtonText: 'Confirmar',
    );

    if (directoryPath != null) {
      return directoryPath;
    }

    showSnackBar('Nenhuma pasta selecionada');
    return null;
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> convertFile(File file) async {
    try {
      // Read file content
      final fileContent = await file.readAsString();

      var headers = {
        'Accept': 'application/pdf',
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      var request = http.Request(
        'POST',
        Uri.parse('http://api.labelary.com/v1/printers/8dpmm/labels/3.15x0.98/0/'),
      );

      request.body = fileContent; // Put file content here
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        final fileName = path
            .basename(file.path)
            .replaceAll(RegExp(r'.txt'), '');

        debugPrint('File name: $fileName');
        final bytes = await response.stream.toBytes();

        final fileOut = File('$destinyPath/$fileName.pdf');
        await fileOut.writeAsBytes(bytes);
        debugPrint('PDF saved to: ${fileOut.path}');

        filesSucceeds.add('${file.path}.pdf');
      } else {
        debugPrint('Error: ${response.statusCode} - ${response.reasonPhrase}');
        filesWithErrors.add(file.path);
      }
    } catch (e) {
      debugPrint('Exception: $e');
    }
  }

  Future<void> convertPath(String path) async {
    final directory = Directory(path);

    setState(() {
      isLoading = true;
      filesSucceeds = [];
      filesWithErrors = [];
    });

    if (directory.existsSync()) {
      final files = directory.listSync(
        recursive: false,
      ); // `true` to list all subfolders recursively

      for (final fileEntity in files) {
        if (fileEntity is File && fileEntity.path.endsWith("txt")) {
          debugPrint('File: ${fileEntity.path}');

          await convertFile(fileEntity);
        } else if (fileEntity is Directory) {
          debugPrint('only a directory: ${fileEntity.path}');
        }
      }
    } else {
      debugPrint('Directory does not exist');
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text("ZPL to PDF"),
            centerTitle: true,
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              originPath,
                              style: TextStyle(
                                color: _originPath == null
                                    ? Colors.red
                                    : Colors.black,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                _originPath = await selectFolder();
                                setState(() {});
                              },
                              child: Text("Alterar origem"),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(destinyPath),
                            ElevatedButton(
                              onPressed: () async {
                                _destinyPath = await selectFolder();
                                setState(() {});
                              },
                              child: Text("Alterar destino (opcional)"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: ElevatedButton(
                      onPressed: _originPath == null
                          ? null
                          : () async {
                              await convertPath(_originPath!);
                            },
                      child: Text("Converter"),
                    ),
                  ),
                  if (filesSucceeds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Text(
                            "Arquivos convertidos: ${filesSucceeds.length}",
                            style: TextStyle(color: Colors.green),
                          ),
                          for (String file in filesSucceeds)
                            Text(file, style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  if (filesWithErrors.isNotEmpty)
                    Column(
                      children: [
                        Text(
                          "Arquivos com erro pra converter: ${filesWithErrors.length}",
                          style: TextStyle(color: Colors.red),
                        ),
                        for (String file in filesWithErrors)
                          Text(file, style: TextStyle(color: Colors.green)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isLoading)
          Positioned(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Container(
                height: MediaQuery.of(context).size.height,
                width: MediaQuery.of(context).size.width,
                color: Colors.black45,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Conversão em andamento...",
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
