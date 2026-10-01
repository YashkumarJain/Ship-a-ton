class NewsItem {
  const NewsItem({
    required this.title,
    required this.source,
    required this.link,
    required this.overview,
    required this.sector,
    required this.marketSignal,
    required this.rationale,
    this.publishedAt,
  });

  final String title;
  final String source;
  final String link;
  final String overview;
  final String sector;
  final String marketSignal;
  final String rationale;
  final DateTime? publishedAt;

  factory NewsItem.fromJson(Map<String, dynamic> json) => NewsItem(
        title: '${json['title'] ?? ''}',
        source: '${json['source'] ?? ''}',
        link: '${json['link'] ?? ''}',
        overview: '${json['overview'] ?? ''}',
        sector: '${json['sector'] ?? 'Broad market'}',
        marketSignal: '${json['marketSignal'] ?? 'uncertain'}',
        rationale: '${json['rationale'] ?? ''}',
        publishedAt: DateTime.tryParse('${json['publishedAt'] ?? ''}'),
      );
}
