import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'lab/model_store.dart';
import 'lab/result_store.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Models go in the app's data folder, not its cache: Android may empty the
  // cache whenever it is short of space, and these files are gigabytes.
  final support = await getApplicationSupportDirectory();
  final documents = await getApplicationDocumentsDirectory();
  runApp(
    AssistLabApp(
      models: ModelStore('${support.path}/models'),
      results: ResultStore(Directory('${documents.path}/results')),
    ),
  );
}

class AssistLabApp extends StatelessWidget {
  const AssistLabApp({super.key, required this.models, required this.results});

  final ModelStore models;
  final ResultStore results;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return MaterialApp(
      title: 'ZT Assist',
      theme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: HomePage(models: models, results: results),
    );
  }
}
