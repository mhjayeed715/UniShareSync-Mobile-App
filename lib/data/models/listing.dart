/// Enumerates the three possible listing types.
enum ListingType { borrow, rent, sell }

/// Base model for any listing.
class Listing {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final String condition;
  final List<String> semesterTags;
  final List<String> photos;
  final ListingType type;
  final String status;
  final Map<String, dynamic> terms;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Listing({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.semesterTags,
    required this.photos,
    required this.type,
    required this.status,
    this.terms = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// Factory constructor to create a Listing from JSON data
  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      condition: json['condition'] as String,
      semesterTags: (json['semester_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ?? [],
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ?? [],
      type: ListingType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ListingType.borrow,
      ),
      status: json['status'] as String,
      terms: (json['terms'] is Map<String, dynamic>)
          ? json['terms'] as Map<String, dynamic>
          : {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  String toString() => 'Listing(id: $id, title: $title, type: $type)';
}