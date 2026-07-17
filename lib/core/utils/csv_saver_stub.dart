import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> saveCsvFile(String csv, String fileName) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(csv);
  return file.path;
}
