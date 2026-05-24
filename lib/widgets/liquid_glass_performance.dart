bool shouldDisableLiquidGlassBlur({
  required bool isWeb,
  required bool disableAnimations,
  required int rasterJankCount,
  required int totalJankCount,
}) {
  if (disableAnimations) {
    return true;
  }
  if (!isWeb) {
    return false;
  }

  return rasterJankCount >= 3 || totalJankCount >= 3;
}
