// lib/data/models/service_model.dart
class ServiceModel {
  final int? id;
  final String? title;
  final String? description;
  final double? price;
  final Map<String, dynamic>? additionalData;

  ServiceModel({
    this.id,
    this.title,
    this.description,
    this.price,
    this.additionalData,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as int?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      additionalData: json,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      ...?additionalData,
    };
  }
}

