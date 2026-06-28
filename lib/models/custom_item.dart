class CustomItem {
  final String id;
  final String name;
  final String category;
  final String? imagePath;
  final String? imageBase64;
  final DateTime createdAt;

  const CustomItem({
    required this.id,
    required this.name,
    required this.category,
    this.imagePath,
    this.imageBase64,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomItem.fromJson(Map<String, dynamic> json) {
    return CustomItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'Мои предметы').toString(),
      imagePath: json['imagePath'] as String?,
      imageBase64: json['imageBase64'] as String?,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
