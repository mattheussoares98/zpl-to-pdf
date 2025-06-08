// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:zpl_to_pdf/helper.dart';

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
  List<String> generatedPdfs = [];

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
                                _originPath = await Helper.selectFolder(
                                  context,
                                );
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
                                _destinyPath = await Helper.selectFolder(
                                  context,
                                );
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
                              await Helper.convertPath(
                                originPath: originPath,
                                destinyPath: destinyPath,
                                context: context,
                                changeIsLoading: (value) {
                                  setState(() {
                                    isLoading = value;
                                  });
                                },
                              );
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
