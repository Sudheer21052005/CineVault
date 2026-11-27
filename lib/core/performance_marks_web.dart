import 'dart:js_interop';

@JS('performance')
external _BrowserPerformance get _performance;

extension type _BrowserPerformance(JSObject _) implements JSObject {
  external void mark(JSString name, _MarkOptions options);
  external void clearMarks(JSString name);
}

extension type _MarkOptions._(JSObject _) implements JSObject {
  external factory _MarkOptions({JSAny? detail});
}

void markBrowserPerformance(String name, Map<String, Object> fields) {
  final label = name.toJS;
  // Keep only the latest mark for each allowlisted event on long sessions.
  _performance.clearMarks(label);
  _performance.mark(label, _MarkOptions(detail: fields.jsify()));
}
