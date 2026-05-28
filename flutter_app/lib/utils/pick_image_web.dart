/// Web implementation — uses a fresh dart:html FileUploadInputElement on every
/// call so the browser file dialog always opens, even on repeated picks.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<({Uint8List bytes, String mime})?> pickImageFile() async {
  final completer = Completer<({Uint8List bytes, String mime})?>();
  bool fileSelected = false;

  // Always create a brand-new element — reusing the same element can silently
  // prevent the dialog from opening on the second+ call in some browsers.
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/jpg,image/png,image/webp'
    ..style.display = 'none';

  html.document.body!.append(input);

  void safeComplete(({Uint8List bytes, String mime})? value) {
    if (!completer.isCompleted) completer.complete(value);
    try {
      input.remove();
    } catch (_) {}
  }

  // ── Handle file selected ──────────────────────────────────────────────────
  input.onChange.listen((event) {
    fileSelected = true;
    final files = input.files;
    if (files == null || files.isEmpty) {
      safeComplete(null);
      return;
    }
    final file = files[0]!;
    final mimeType =
        file.type.isNotEmpty ? file.type : 'image/jpeg';
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is List<int>) {
        safeComplete(
            (bytes: Uint8List.fromList(result), mime: mimeType));
      } else {
        safeComplete(null);
      }
    });
    reader.onError.listen((_) => safeComplete(null));
  });

  // ── Detect dialog cancelled (window regains focus, no file chosen) ────────
  html.window.onFocus.first.then((_) async {
    // Give onChange a chance to fire first (it fires slightly after focus)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!fileSelected) safeComplete(null);
  });

  // ── Safety timeout (5 minutes) ────────────────────────────────────────────
  Future.delayed(const Duration(minutes: 5), () => safeComplete(null));

  // ── Trigger dialog — must be synchronous (no await before this line) ──────
  input.click();

  return completer.future;
}
