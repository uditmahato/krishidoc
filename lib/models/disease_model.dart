// lib/models/disease_model.dart

class TopPrediction {
  final String className;
  final double confidence;
  TopPrediction({required this.className, required this.confidence});

  factory TopPrediction.fromMap(Map<String, dynamic> map) {
    return TopPrediction(
      className: map['class'] ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'class': className,
      'confidence': confidence,
    };
  }
}

class Disease {
  final String id;
  final String name;
  final double confidence;
  final List<TopPrediction> topPredictions;
  final String description;
  final String treatment;
  final String imageUrl;

  Disease({
    required this.id,
    required this.name,
    required this.confidence,
    required this.topPredictions,
    required this.description,
    required this.treatment,
    required this.imageUrl,
  });

  factory Disease.fromMap(Map<String, dynamic> map) {
    // Parse top 3 predictions
    List<TopPrediction> preds = [];
    if (map['top_3'] is List) {
      preds = (map['top_3'] as List)
          .map((e) => TopPrediction.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Disease(
      id: map['id']?.toString() ?? '',
      name: map['prediction'] ?? map['name'] ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      topPredictions: preds,
      description: map['description'] ?? '',
      treatment: map['treatment'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'prediction': name,
      'confidence': confidence,
      'top_3': topPredictions.map((e) => e.toMap()).toList(),
      'description': description,
      'treatment': treatment,
      'imageUrl': imageUrl,
    };
  }
}
