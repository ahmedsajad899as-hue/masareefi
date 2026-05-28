/// Conditional export: uses dart:html on web, file_picker on native platforms.
export 'pick_image_io.dart' if (dart.library.html) 'pick_image_web.dart';
