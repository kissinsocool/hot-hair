import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';

class ServiceDetailScreen extends StatelessWidget {
  final String name;
  final String price;
  final String duration;
  final String imageUrl;

  const ServiceDetailScreen({
    super.key,
    required this.name,
    required this.price,
    required this.duration,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 服务大图
            SizedBox(
              width: double.infinity,
              height: 350,
              child: Image.network(imageUrl, fit: BoxFit.cover),
            ),
            
            Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                      Text(price, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryPink)),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 5),
                      Text(duration, style: TextStyle(color: Colors.grey, fontSize: 14)),
                      SizedBox(width: 15),
                      Icon(Icons.star, size: 16, color: Colors.orange),
                      SizedBox(width: 5),
                      Text('人气服务', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 30),
                  
                  Text('服务介绍', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  SizedBox(height: 15),
                  Text(
                    '这是一款精心设计的  服务。我们会根据您的面部轮廓和发质，提供最专业的一对一分析，结合日系极致的剪裁技术，为您打造自然、高级且易于打理的发型。包含头部按摩与基础护理，确保您在享受美发的同时获得身心的放松。',
                    style: TextStyle(color: AppTheme.textDark.withOpacity(0.7), fontSize: 16, height: 1.6),
                  ),
                  
                  SizedBox(height: 30),
                  Text('服务流程', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textDark)),
                  SizedBox(height: 15),
                  _buildStep(1, '面诊咨询', '与发型师沟通需求，分析发质与脸型'),
                  _buildStep(2, '专业操作', '执行核心服务项目，注重细节与质感'),
                  _buildStep(3, '造型打理', '最后一步造型设计，教您日常如何打理'),
                  
                  SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => context.push(AppRouter.booking),
                      child: Text('预约此服务', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step, String title, String desc) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: AppTheme.primaryPink, shape: BoxShape.circle),
            child: Center(child: Text('$step', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textDark)),
                SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
