import 'dart:js' as js;

String? getWebBaseApi() {
  try {
    final env = js.context['__ENV'];
    if (env == null) return null;
    final base = env['BASE_API'];
    return base?.toString();
  } catch (_) {
    return null;
  }
}
