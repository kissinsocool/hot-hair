import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/router.dart';

const _background = Color(0xFFFDFBF9);
const _ink = Color(0xFF2C2A29);
const _body = Color(0xFF4A4744);
const _muted = Color(0xFF6E6A66);
const _accent = Color(0xFFB5836A);
const _border = Color(0xFFE8E2DC);

class AdCampaignBanner extends StatelessWidget {
  const AdCampaignBanner({super.key, this.imageUrl = ''});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl.isEmpty
        ? Image.asset('assets/images/ad.jpeg', fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => const ColoredBox(color: _border),
            errorWidget: (context, url, error) =>
                Image.asset('assets/images/ad.jpeg', fit: BoxFit.cover),
          );

    return Semantics(
      button: true,
      label: '查看 2026 首尔发型趋势',
      child: InkWell(
        onTap: () => context.push(AppRouter.adCampaign),
        child: SizedBox(width: double.infinity, height: 71, child: image),
      ),
    );
  }
}

class AdCampaignScreen extends StatelessWidget {
  const AdCampaignScreen({super.key});

  static const _sections = [
    (
      title: '1. 酷女孩的清冷滤镜：Hush Cut（轻薄层次剪）',
      image: 'assets/images/ad/hush-cut.jpg',
      ratio: 0.82,
      caption: '轻盈飘逸、自带清冷高级感的 Hush Cut',
      heading: '为什么这款发型正风靡首尔？',
      features: [
        ('极具呼吸感：', '摆脱了厚重发尾的沉闷，走起路来发丝自带灵动的飘逸感。'),
        ('百搭脸型：', '脸颊两侧的碎发可以根据你的脸型进行定制修剪，是方圆脸和高颧骨女孩的“瘦脸神器”。'),
        ('日常好打理：', '只需要一点点发油抓出线条感，就能呈现出一种“我刚起床就这么美”的慵懒随性。'),
      ],
    ),
    (
      title: '2. 财阀千金的温婉：Build Perm（韩式气垫烫）',
      image: 'assets/images/ad/build-perm.jpg',
      ratio: 1.7,
      caption: '充满优雅气质与自然蓬松感的 Build Perm',
      heading: '这款发型的灵魂所在：',
      features: [
        ('头包脸效果：', '发根的蓬松处理能有效修饰扁平的后脑勺，从视觉上打造出完美的头身比。'),
        ('优雅不显老：', '卷度主要集中在耳朵以下，既保留了直发的清纯，又增添了卷发的柔美和女人味。'),
        ('八字刘海绝配：', '搭配经典的外翻八字刘海，不仅能修饰额头，还能让侧颜的线条更加立体。'),
      ],
    ),
    (
      title: '3. 男士的利落与高级：Guile Cut（盖尔剪）',
      image: 'assets/images/ad/guile-cut.jpg',
      ratio: 1.04,
      caption: '干练又不失雅痞细节的 Guile Cut',
      heading: '它的独特魅力：',
      features: [
        ('硬朗与柔情的平衡：', '露出额头显得非常精神、有男人味，但垂下的几缕碎发又打破了传统西装头的死板，多了一份雅痞感。'),
        ('修饰宽额头：', '对于发际线较高或额头较宽的男士非常友好，半遮半掩的设计能完美扬长避短。'),
        ('职场休闲两相宜：', '穿西装时显得专业干练，周末穿T恤又显得时髦有型，实用性满分。'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('2026 首尔发型趋势'),
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        children: [
          const _BrandHeader(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 36, 16, 0),
                child: Column(
                  children: [
                    const Text(
                      'HAIR TRENDS 2026',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '2026 首尔发型风向标：今年一定要尝试的「松弛感」发型',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 24,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      'BY TREND EDITOR  ·  2026.03.15  ·  5 MIN READ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 34),
                    const _IntroText(),
                    const SizedBox(height: 15),
                    const Text(
                      '作为你的线上发型顾问，我为你整理了目前韩国最具话题度、出街率最高的三款发型。无论你是想要清冷酷感，还是温婉优雅，总有一款能直击你的心。',
                      textAlign: TextAlign.justify,
                      style:
                          TextStyle(color: _body, fontSize: 15.5, height: 1.9),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Divider(color: _border, height: 1),
                    ),
                    for (final section in _sections) _ArticleSection(section),
                    const _StylistTip(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _border)),
            ),
            child: const Text(
              '© 2026 SEOUL TREND INSIGHTS. ALL RIGHTS RESERVED.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: const Text(
        'SEOUL HAIR SALON TREND',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

class _IntroText extends StatelessWidget {
  const _IntroText();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
              text:
                  '如果你正在寻找换季的灵感，想要褪去沉闷，那么今年的韩系发型趋势绝对能让你眼前一亮。2026年首尔清潭洞沙龙里最常听到的三个字就是——'),
          TextSpan(
            text: '“松弛感”',
            style: TextStyle(color: _accent, fontWeight: FontWeight.w700),
          ),
          TextSpan(text: '。告别了过去那种刻意、死板的造型，今年的趋势更强调发丝的自然流向、轻盈的空气感以及修饰脸型的巧妙层次。'),
        ],
      ),
      textAlign: TextAlign.justify,
      style: TextStyle(color: _body, fontSize: 15.5, height: 1.9),
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection(this.section);

  final ({
    String title,
    String image,
    double ratio,
    String caption,
    String heading,
    List<(String, String)> features,
  }) section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 3.5, height: 24, color: _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 15,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: section.ratio,
                  child: Image.asset(section.image, fit: BoxFit.cover),
                ),
                const SizedBox(height: 9),
                Text(
                  section.caption,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    letterSpacing: .5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: const BoxDecoration(
              color: Color(0xFFF5EFE9),
              border: Border(left: BorderSide(color: _accent, width: 3)),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.heading,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                for (final feature in section.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2, right: 7),
                          child: Text('✦',
                              style: TextStyle(color: _accent, fontSize: 11)),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: feature.$1,
                                  style: const TextStyle(
                                      color: _ink, fontWeight: FontWeight.w700),
                                ),
                                TextSpan(text: feature.$2),
                              ],
                            ),
                            style: const TextStyle(
                                color: Color(0xFF55514E),
                                fontSize: 14,
                                height: 1.75),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StylistTip extends StatelessWidget {
  const _StylistTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _accent, style: BorderStyle.solid, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✂️ 设计师的小贴士（Stylist\'s Tip）',
            style: TextStyle(
                color: _accent, fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 7),
          Text(
            '再好看的图片，也需要根据你自身的发质（粗硬/细软）、发量以及骨相来做微调。拿着这篇博客去见你的发型师，和他好好沟通你的日常穿搭和打理习惯，才能剪出最适合你的那一款！',
            textAlign: TextAlign.justify,
            style: TextStyle(color: _muted, fontSize: 14, height: 1.8),
          ),
        ],
      ),
    );
  }
}
