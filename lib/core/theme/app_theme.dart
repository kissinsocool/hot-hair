import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
        displayLarge: TextStyle(
            color: textDark, fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: TextStyle(color: textDark, fontSize: 16),
        bodyMedium: TextStyle(color: textDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPink,
          foregroundColor: white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
      ),
    );
  }
}

class SalonAssets {
  static const String placeholder = 'assets/images/salon_placeholder.svg';
  static const List<Map<String, String>> staffPhotos = [
    {'name': 'Sato 先生', 'img': placeholder},
    {'name': 'Tanaka 女士', 'img': placeholder},
    {'name': 'Ken 先生', 'img': placeholder},
  ];
}

class AppImages {
  static Widget placeholder({
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return SvgPicture.asset(
      SalonAssets.placeholder,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
