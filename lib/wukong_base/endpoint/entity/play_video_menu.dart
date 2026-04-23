/// Play video menu
/// 
/// Used for playing video content
class PlayVideoMenu {
  /// Video play URL
  final String playUrl;

  /// Video cover image URL
  final String? coverUrl;

  /// Video title
  final String? videoTitle;

  /// Video duration in milliseconds
  final int? duration;

  PlayVideoMenu({
    required this.playUrl,
    this.coverUrl,
    this.videoTitle,
    this.duration,
  });
}
