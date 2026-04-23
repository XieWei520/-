class LinkPreview {
  final String url;
  final String host;
  final String displayUrl;
  final String title;
  final String description;
  final String? imageUrl;
  final bool isFallback;

  const LinkPreview({
    required this.url,
    required this.host,
    required this.displayUrl,
    required this.title,
    required this.description,
    this.imageUrl,
    this.isFallback = false,
  });

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
  bool get hasRichContent =>
      title.trim().isNotEmpty || description.trim().isNotEmpty || hasImage;

  LinkPreview copyWith({
    String? url,
    String? host,
    String? displayUrl,
    String? title,
    String? description,
    String? imageUrl,
    bool? isFallback,
  }) {
    return LinkPreview(
      url: url ?? this.url,
      host: host ?? this.host,
      displayUrl: displayUrl ?? this.displayUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isFallback: isFallback ?? this.isFallback,
    );
  }
}
