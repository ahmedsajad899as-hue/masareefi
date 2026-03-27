class CategoryModel {
  final String id;
  final String nameAr;
  final String nameEn;
  final String icon;
  final String color;
  final bool isSystem;

  const CategoryModel({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.color,
    required this.isSystem,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as String,
        nameAr: json['name_ar'] as String,
        nameEn: json['name_en'] as String,
        icon: json['icon'] as String? ?? '💰',
        color: json['color'] as String? ?? '#4CAF50',
        isSystem: json['is_system'] as bool? ?? false,
      );

  String localName(String lang) => lang == 'ar' ? nameAr : nameEn;
}
