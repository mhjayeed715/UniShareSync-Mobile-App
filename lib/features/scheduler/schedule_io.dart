// Native implementation – uses dart:io (Android, iOS, desktop only).
// Conditionally imported by schedule_repository.dart.
import 'dart:io';

Future<String> readFileAsString(String path) => File(path).readAsString();
