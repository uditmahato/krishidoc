/// Turns a model label key into something a farmer can read.
///
/// **This is a stopgap and it is the wrong place for this to live.** D-35 says
/// display names come from the reviewed knowledge base, because a disease name
/// is content: it has a register, a regional variant, and a native reviewer.
/// Deriving it from the classifier key means the name shown is whatever an ML
/// label happened to be called, and it can only ever produce English.
///
/// It exists because the alternative today is showing `tomato_late_blight` to a
/// farmer, which is worse. It is deleted by the handbook module, and the
/// signature is deliberately awkward to build on so that deletion is easy.
String stopgapLabelName(String labelKey, {String? cropKey}) {
  var key = labelKey;
  // Labels are prefixed with their crop, which the screen already states, so
  // repeating it reads as stuttering: "Tomato: Tomato late blight".
  if (cropKey != null && key.startsWith('${cropKey}_')) {
    key = key.substring(cropKey.length + 1);
  }
  final words = key.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return labelKey;
  return [
    words.first.isEmpty
        ? words.first
        : words.first[0].toUpperCase() + words.first.substring(1),
    ...words.skip(1),
  ].join(' ');
}
