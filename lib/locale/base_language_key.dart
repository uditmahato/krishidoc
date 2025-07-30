import 'package:flutter/material.dart';

abstract class BaseLanguage {
  static BaseLanguage of(BuildContext context) =>
      Localizations.of<BaseLanguage>(context, BaseLanguage)!;

      String get appName;
  String get welcome;
  String get welcomeSubtitle;
  String get diagnoseButton;
  String get askButton;
  String get history;
  String get settings;
  String get login;
  String get logout;
  String get language;

  }
