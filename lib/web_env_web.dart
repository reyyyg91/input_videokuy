import 'dart:html' show window;

String? getWebBaseApi() {
  try {
    // ignore: avoid_web_libraries_in_flutter
    // (dibatasi oleh conditional import: hanya dipakai saat dart.library.html tersedia)
    // ignore: undefined_prefixed_name
    // (analyzer lint bisa berbeda tergantung target platform)
    dynamic env = (window as dynamic).__ENV;
    if (env == null) return null;
    final dynamic base = env.BASE_API;
    return base?.toString();
  } catch (_) {
    return null;
  }
}
