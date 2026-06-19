import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryPink = Color(0xFFE8A2B0);
  static const Color bgCream = Color(0xFFFDFBF9);
  static const Color textDark = Color(0xFF5A5A5A);
  static const Color accentBeige = Color(0xFFE8DCD0);
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryPink,
      scaffoldBackgroundColor: bgCream,
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: TextStyle(color: textDark, fontSize: 16),
        bodyMedium: TextStyle(color: textDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      ),
    );
  }
}

class SalonAssets {
  static const String mainCover = 'https://images.unsplash.com/photo-1560066973-96f-8a32-655232396848?q=80&w=1000';
  static const List<Map<String, String>> staffPhotos = [
    {'name': 'Sato 先生', 'img': 'https://images.unsplash.com/photo-1500648767791-ced8051cb34c?q=80&w=200'},
    {'name': 'Tanaka 女士', 'img': 'https://images.unsplash.com/photo-1438761681033-d1230ff0a285?q=80&w=200'},
    {'name': 'Ken 先生', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200'},
  ];
}
