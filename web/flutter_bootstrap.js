{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Self-host CanvasKit so Flutter Web does not depend on gstatic, which can
    // be unreachable for some users/networks and leaves the app on a blank page.
    canvasKitBaseUrl: 'canvaskit/',
    // Keep Flutter Web fallback font probes on the same host. The app bundles
    // its UI fonts, so any extra fallback shard probes should fail fast locally
    // instead of waiting on fonts.gstatic.com.
    fontFallbackBaseUrl: 'assets/flutter-font-fallback/',
  },
});
