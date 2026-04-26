String sleepEncyclopediaCardSubtitle(String value) {
  final String trimmed = value.trimRight();
  if (trimmed.endsWith('。') || trimmed.endsWith('.')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return value;
}
