import 'dart:js_interop';

@JS('mhdlpMeasureSection')
external JSFunction? get _measureSection;

void measureSiteSection(int section) {
  try {
    _measureSection?.callAsFunction(null, section.toJS);
  } catch (_) {
    // Measurement must never interrupt navigation.
  }
}
