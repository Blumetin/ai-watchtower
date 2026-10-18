import 'dart:js_interop';

extension type _History(JSObject _) implements JSObject {
  external void back();
}

@JS('history')
external _History get _history;

void browserBack() => _history.back();
