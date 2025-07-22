import 'package:flutter/material.dart';
import '../models/disease_model.dart';
import '../services/api_service.dart';

class DiseaseProvider with ChangeNotifier {
  Disease? _currentDisease;
  String? _lastImagePath; // Add this line
  bool _isLoading = false;

  Disease? get currentDisease => _currentDisease;
  String? get lastImagePath => _lastImagePath; // Add this getter
  bool get isLoading => _isLoading;

  Future<void> detectDisease(String imagePath) async {
    _isLoading = true;
    _lastImagePath = imagePath; // Store the image path
    notifyListeners();

    _currentDisease = await ApiService().detectDisease(imagePath);

    _isLoading = false;
    notifyListeners();
  }

  void clearDisease() {
    _currentDisease = null;
    _lastImagePath = null; // clear the path
    notifyListeners();
  }
}

