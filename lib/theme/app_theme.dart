import 'package:flutter/material.dart';

class AppTheme {
  // 定义一套日系温润的配色方案 (Warm & Minimalist)
  static const Color primaryPink = Color(0xFFE8A2B0); // 柔和的樱花粉
  static const Color bgCream = Color(0xFFFDFBF9);      // 奶油白背景
  static const Color textDark = Color(0xFF5A5A5A);     // 深灰而非纯黑，减轻视觉压力
  static const Color accentBeige = Color(0xFFE8DCD0);  // 浅米色点缀
  static const Color white = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryPink,
      scaffoldBackgroundColor: bgCream,
      fontFamily: 'Noto Sans JP', // 建议在 pubspec.yaml 中配置
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
  // 视觉风格指南：统一使用高质量、低饱和度的摄影图
  // 模拟一套符合“日式沙龙”气质的图片库
  static const String mainCover = 'https://images.unsplash.com/photo-1560066973-96f-8a32-655232396848?q=80&w=1000'; 
  static const String interiorShot = 'https://images.unsplash.com/photo-1521590835244-37e753695d44?q=80&w=1000';
  static const String serviceIcon = 'https://images.unsplash.com/photo-1562322140-87cc55772557?q=80&w=200';

  static const List<Map<String, String>> staffPhotos = [
    {'name': 'Sato 先生', 'img': 'https://images.unsplash.com/photo-1500648767791-ced8051cb34c?q=80&w=200'}, // 沉稳专业
    {'name': 'Tanaka 女士', 'img': 'https://images.unsplash.com/photo-1438761681033-d1230ff0a285?q=80&w=200'}, // 亲切优雅
    {'name': 'Ken 先生', 'img': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200'}, // 现代时尚
  ];
}
