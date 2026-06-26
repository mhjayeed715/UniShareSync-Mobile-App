// Web stub – dart:io is unavailable on web. importFromFiles() is always
// guarded by !kIsWeb in the calling code so this path is never reached at
// runtime. It exists solely so dart2js can compile the repository file.
Future<String> readFileAsString(String path) {
  throw UnsupportedError('File I/O is not supported on web.');
}
