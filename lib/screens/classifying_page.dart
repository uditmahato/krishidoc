// lib/screens/classifying_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/disease_provider.dart';

class ClassifyingPage extends StatefulWidget {
  final String imagePath;
  const ClassifyingPage({required this.imagePath, super.key});

  @override
  State<ClassifyingPage> createState() => _ClassifyingPageState();
}

class _ClassifyingPageState extends State<ClassifyingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startClassification());
  }

  Future<void> _startClassification() async {
    await Provider.of<DiseaseProvider>(context, listen: false)
        .detectDisease(widget.imagePath);
    Navigator.pushReplacementNamed(context, '/diseaseResult');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.file(File(widget.imagePath), height: 120, fit: BoxFit.cover),
            const SizedBox(height: 24),
            const SizedBox(
              width: 48, height: 48,
              child: CircularProgressIndicator(strokeWidth: 6),
            ),
            const SizedBox(height: 24),
            const Text(
              'Classifying disease…\nPlease wait',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
