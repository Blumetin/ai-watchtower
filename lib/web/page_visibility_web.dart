import 'dart:js_interop';

extension type _Document(JSObject _) implements JSObject {
  external String get visibilityState;
  external void addEventListener(String type, JSFunction listener);
}

@JS('document')
external _Document get _document;

bool pageHidden() => _document.visibilityState == 'hidden';

void onPageVisibilityChange(void Function(bool hidden) onChange) {
  _document.addEventListener(
    'visibilitychange',
    ((JSAny? _) => onChange(pageHidden())).toJS,
  );
}
