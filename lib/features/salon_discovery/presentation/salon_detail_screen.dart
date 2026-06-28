import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../features/booking/presentation/booking_screen.dart';
import '../../../features/booking/domain/booking_model.dart';
import '../data/favorite_salon_store.dart';
import '../data/salon_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/top_snack_bar.dart';
import '../../../features/booking/domain/staff_model.dart';
import '../../../features/booking/domain/staff_experience_formatter.dart';
import '../../../features/booking/presentation/staff_detail_screen.dart';

class SalonDetailScreen extends StatefulWidget {
  final String salonId;

  const SalonDetailScreen({super.key, required this.salonId});

  @override
  State<SalonDetailScreen> createState() => _SalonDetailScreenState();
}

class _SalonDetailScreenState extends State<SalonDetailScreen> {
  final SalonRepository _salonRepository = SalonRepository();
  final ScrollController _staffScrollController = ScrollController();
  bool _isLoading = true;
  Map<String, dynamic>? _salon;
  String _errorMessage = '';
  int _visibleReviewCount = 3;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _staffScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    try {
      final data = await _salonRepository.fetchSalonDetail(widget.salonId);
      setState(() {
        _salon = data;
        _isLoading = false;
        _visibleReviewCount = 3;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bgCream,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryPink),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.bgCream,
        appBar: AppBar(backgroundColor: AppTheme.white, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '加载详情失败: $_errorMessage',
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _loadDetail, child: Text('重新加载')),
            ],
          ),
        ),
      );
    }

    final salon = _salon!;
    final isFavorite = FavoriteSalonStore.isFavorite(widget.salonId);
    final coverImage = _coverImageUrl(salon);

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.white,
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: coverImage,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  memCacheWidth: 1100,
                  filterQuality: FilterQuality.low,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey,
                    child: Icon(Icons.broken_image, size: 50),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.50),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 56,
                  right: 20,
                  bottom: 16,
                  child: Text(
                    salon['name'] ?? '沙龙详情',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black54)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSalonRatingSummary(salon),
                          Text(
                            salon['openingHours']?.toString().isNotEmpty == true
                                ? '营业时间：${salon['openingHours']}'
                                : '暂无营业时间',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: isFavorite ? '取消收藏' : '收藏店铺',
                        onPressed: () async {
                          if (!context.mounted) return;
                          try {
                            await FavoriteSalonStore.toggle(salon);
                            if (!context.mounted) return;
                            setState(() {});
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              topSnackBar(context, '收藏保存失败，请稍后重试'),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            topSnackBar(
                                context, isFavorite ? '已取消收藏' : '已加入收藏'),
                          );
                        },
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite
                              ? AppTheme.primaryPink
                              : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 25),
                  _buildSectionTitle('店铺信息'),
                  SizedBox(height: 15),
                  _buildSalonInfo(salon),
                  _buildPromoImagesSection(salon),
                  SizedBox(height: 30),
                  _buildSectionTitle('关于我们'),
                  SizedBox(height: 10),
                  Text(
                    salon['fullDescription'] ?? '暂无详细描述',
                    style: TextStyle(
                      color: Colors.grey[700],
                      height: 1.6,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 30),
                  _buildSectionTitle('热门套餐'),
                  SizedBox(height: 15),
                  if (salon['services'] != null &&
                      (salon['services'] as List).isNotEmpty)
                    ...((salon['services'] as List)
                        .take(3)
                        .map((service) => _buildServiceItem(service))
                        .toList())
                  else
                    Text('暂无可用套餐', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 30),
                  _buildSectionTitle('我们的理发师'),
                  SizedBox(height: 15),
                  if (salon['staff'] != null &&
                      (salon['staff'] as List).isNotEmpty)
                    _buildStaffList(salon)
                  else
                    Text('暂无发型师信息', style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 30),
                  _buildSectionTitle('客户评价'),
                  SizedBox(height: 15),
                  _buildSalonReviews(salon),
                  SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          10,
          10,
          MediaQuery.paddingOf(context).bottom + 9,
        ),
        color: AppTheme.white,
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () {
              _openBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              '立即预约',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  StaffProfile _parseStaffProfile(dynamic staffData, dynamic allReviews) {
    final String staffId = staffData['id'].toString();
    List<Review> staffReviews = [];

    if (staffData is Map &&
        staffData.containsKey('reviews') &&
        staffData['reviews'] is List) {
      staffReviews = (staffData['reviews'] as List)
          .map(
            (rev) => Review(
              userName: (rev['user'] ?? rev['userName'] ?? '未知用户'),
              rating: (rev['rating'] ?? 0.0).toDouble(),
              comment: rev['comment'] ?? '',
              date: rev['date'] ?? '',
              imageUrls: (rev['imageUrls'] as List?)
                      ?.map((item) => item.toString())
                      .toList() ??
                  [],
            ),
          )
          .toList();
    } else if (allReviews != null && allReviews is List) {
      staffReviews = allReviews
          .where((rev) => rev['staffId']?.toString() == staffId)
          .map(
            (rev) => Review(
              userName: (rev['user'] ?? rev['userName'] ?? '未知用户'),
              rating: (rev['rating'] ?? 0.0).toDouble(),
              comment: rev['comment'] ?? '',
              date: rev['date'] ?? '',
              imageUrls: (rev['imageUrls'] as List?)
                      ?.map((item) => item.toString())
                      .toList() ??
                  [],
            ),
          )
          .toList();
    }

    return StaffProfile(
      id: staffId,
      name: staffData['name'] ?? '未知发型师',
      role: staffData['role'] ?? (staffData['experience'] ?? '发型师'),
      experience: staffData['experience'] ?? '暂无经验描述',
      extraServiceFee: _parseInt(staffData['extraServiceFee']),
      imageUrl: staffData['imageUrl'] ?? 'https://via.placeholder.com/210x280',
      bio: staffData['bio'] ?? '暂无个人简介',
      rating: (staffData['rating'] ?? 0.0).toDouble(),
      reviews: staffReviews,
    );
  }

  SalonService _parseSalonService(dynamic serviceData) {
    final duration = serviceData['duration']?.toString() ?? '';
    final minutes =
        int.tryParse(duration.replaceAll(RegExp(r'[^0-9]'), '')) ?? 60;

    return SalonService(
      id: serviceData['id']?.toString() ?? '',
      name: serviceData['name']?.toString() ?? '未知服务',
      durationMinutes: minutes,
      imageUrl: serviceData['imageUrl']?.toString() ?? '',
      note: serviceData['note']?.toString() ?? '',
      priceLabel: serviceData['price']?.toString() ?? '',
    );
  }

  void _openBooking({String? initialServiceId}) {
    final salon = _salon;
    if (salon == null) return;

    final staffProfiles = (salon['staff'] as List)
        .map((s) => _parseStaffProfile(s, salon['reviews']))
        .toList();
    final services =
        (salon['services'] as List? ?? []).map(_parseSalonService).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingScreen(
          initialStaffList: staffProfiles,
          initialServices: services,
          initialServiceId: initialServiceId,
        ),
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryPink,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSalonInfo(Map<String, dynamic> salon) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.phone,
            '电话',
            salon['phone']?.toString().isNotEmpty == true
                ? salon['phone'].toString()
                : '暂无电话',
          ),
          SizedBox(height: 14),
          _buildInfoRow(
            Icons.location_on,
            '地址',
            salon['address']?.toString().isNotEmpty == true
                ? salon['address'].toString()
                : '地址未知',
          ),
        ],
      ),
    );
  }

  Widget _buildPromoImagesSection(Map<String, dynamic> salon) {
    final promoImages = _promoImageUrls(salon);
    if (promoImages.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _SalonDetailImageCarousel(images: promoImages),
        ),
      ),
    );
  }

  Widget _buildSalonRatingSummary(Map<String, dynamic> salon) {
    final rating = (salon['rating'] ?? 0.0).toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRatingStars(rating, size: 14),
        SizedBox(width: 6),
        Text(
          '${rating.toStringAsFixed(1)} (${_salonReviewCount(salon)}人评分)',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildRatingStars(double rating, {required double size}) {
    final clampedRating = rating.clamp(0, 5).toDouble();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = clampedRating - index;
        final icon = starValue >= 1
            ? Icons.star
            : starValue > 0
                ? Icons.star_half
                : Icons.star_border;

        return Icon(
          icon,
          size: size,
          color: starValue > 0 ? Colors.orange : Colors.grey[300],
        );
      }),
    );
  }

  int _salonReviewCount(Map<String, dynamic> salon) {
    final staffList = salon['staff'];
    if (staffList is! List) return 0;

    return staffList.fold<int>(0, (total, staff) {
      if (staff is! Map || staff['reviews'] is! List) return total;
      return total + (staff['reviews'] as List).length;
    });
  }

  List<Map<String, dynamic>> _salonReviews(Map<String, dynamic> salon) {
    final staffList = salon['staff'];
    if (staffList is! List) return [];

    final reviews = <Map<String, dynamic>>[];
    for (final staff in staffList) {
      if (staff is! Map || staff['reviews'] is! List) continue;
      final staffName = staff['name']?.toString() ?? '理发师';
      final staffId = staff['id']?.toString() ?? '';
      for (final review in staff['reviews'] as List) {
        if (review is! Map) continue;
        reviews.add({
          'id': review['id']?.toString() ?? '',
          'staffId': staffId,
          'staffName': staffName,
          'userName': review['userName'] ?? review['user'] ?? '匿名用户',
          'rating': _parseDouble(review['rating']),
          'comment': review['comment']?.toString() ?? '',
          'date': review['date']?.toString() ?? '',
          'serviceName': review['serviceName']?.toString() ?? '',
          'imageUrls': (review['imageUrls'] as List?)
                  ?.map((item) => item.toString())
                  .toList() ??
              <String>[],
          'merchantReply': review['merchantReply'],
        });
      }
    }

    reviews.sort((left, right) {
      return _reviewSortValue(right).compareTo(_reviewSortValue(left));
    });
    return reviews;
  }

  int _reviewSortValue(Map<String, dynamic> review) {
    final id = review['id']?.toString() ?? '';
    final idTimestamp = RegExp(r'RV(\d+)').firstMatch(id)?.group(1);
    final parsedIdTimestamp = int.tryParse(idTimestamp ?? '');
    if (parsedIdTimestamp != null) return parsedIdTimestamp;

    final date = DateTime.tryParse(review['date']?.toString() ?? '');
    return date?.millisecondsSinceEpoch ?? 0;
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _coverImageUrl(Map<String, dynamic> salon) {
    final image = salon['image']?.toString().trim() ?? '';
    return image.isNotEmpty ? image : 'https://via.placeholder.com/800x400';
  }

  List<String> _promoImageUrls(Map<String, dynamic> salon) {
    final images = <String>[];

    void addImage(dynamic value) {
      if (value is! String || value.trim().isEmpty) return;
      if (!images.contains(value)) images.add(value);
    }

    final promoImages = salon['promoImages'];
    if (promoImages is List) {
      for (final image in promoImages) {
        addImage(image);
      }
    }

    if (images.isEmpty) {
      final imageList = salon['images'];
      if (imageList is List) {
        for (final image in imageList) {
          addImage(image);
        }
      }
    }

    return images;
  }

  Widget _buildSalonReviews(Map<String, dynamic> salon) {
    final reviews = _salonReviews(salon);
    if (reviews.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.accentBeige),
        ),
        child: Text('暂无评价', style: TextStyle(color: Colors.grey[600])),
      );
    }

    final visibleReviews = reviews.take(_visibleReviewCount).toList();
    final hasMore = _visibleReviewCount < reviews.length;

    return Column(
      children: [
        ...visibleReviews.map(_buildSalonReviewCard),
        if (hasMore) ...[
          SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _visibleReviewCount =
                      (_visibleReviewCount + 10).clamp(0, reviews.length);
                });
              },
              icon: Icon(Icons.expand_more),
              label: Text('更多评价'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryPink,
                side: BorderSide(color: AppTheme.primaryPink),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSalonReviewCard(Map<String, dynamic> review) {
    final serviceName = review['serviceName']?.toString() ?? '';
    final staffName = review['staffName']?.toString() ?? '';
    final imageUrls = review['imageUrls'] as List<String>;
    final merchantReply = _merchantReplyText(review['merchantReply']);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppTheme.accentBeige),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryPink.withOpacity(0.14),
                child:
                    Icon(Icons.person, size: 19, color: AppTheme.primaryPink),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName']?.toString() ?? '匿名用户',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      [
                        if (serviceName.isNotEmpty) serviceName,
                        if (staffName.isNotEmpty) staffName,
                      ].join(' · '),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                review['date']?.toString() ?? '',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          SizedBox(height: 10),
          _buildRatingStars(_parseDouble(review['rating']), size: 15),
          if ((review['comment']?.toString() ?? '').isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              review['comment'].toString(),
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (imageUrls.isNotEmpty) ...[
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        memCacheWidth: 180,
                        filterQuality: FilterQuality.low,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        errorWidget: (context, url, error) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey[200],
                          child: Icon(Icons.image_not_supported,
                              color: Colors.grey[500], size: 20),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (merchantReply.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.bgCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storefront,
                          size: 15, color: AppTheme.primaryPink),
                      SizedBox(width: 6),
                      Text(
                        '商家回复',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    merchantReply,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _merchantReplyText(dynamic value) {
    if (value is Map) return value['content']?.toString() ?? '';
    return value?.toString() ?? '';
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryPink),
        SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaffList(Map<String, dynamic> salon) {
    final staffList = salon['staff'] as List;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final listView = ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SizedBox(
            height: 260,
            child: ListView.separated(
              controller: _staffScrollController,
              scrollDirection: Axis.horizontal,
              cacheExtent: 280,
              physics: ClampingScrollPhysics(),
              padding: EdgeInsets.only(bottom: isNarrow ? 4 : 0),
              itemBuilder: (context, index) =>
                  _buildStaffCard(staffList[index], salon['reviews'], salon),
              separatorBuilder: (context, index) => SizedBox(width: 10),
              itemCount: staffList.length,
            ),
          ),
        );

        return listView;
      },
    );
  }

  Widget _buildStaffCard(
    dynamic staff,
    dynamic allReviews,
    Map<String, dynamic> salon,
  ) {
    final profile = _parseStaffProfile(staff, allReviews);
    const cardWidth = 140.0;
    const imageHeight = 187.0;
    const cardRadius = 10.0;
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StaffDetailScreen(
                staffId: profile.id,
                staffProfile: profile,
                allStaffInSalon: (salon['staff'] as List)
                    .map((s) => _parseStaffProfile(s, salon['reviews']))
                    .toList(),
                initialServices: (salon['services'] as List? ?? [])
                    .map(_parseSalonService)
                    .toList(),
              ),
            ),
          );
        },
        child: Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(color: AppTheme.accentBeige.withOpacity(0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(cardRadius)),
                child: CachedNetworkImage(
                  imageUrl: profile.imageUrl,
                  width: cardWidth,
                  height: imageHeight,
                  fit: BoxFit.cover,
                  memCacheWidth: 420,
                  filterQuality: FilterQuality.low,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (context, url) => Container(
                    width: cardWidth,
                    height: imageHeight,
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: cardWidth,
                    height: imageHeight,
                    color: Colors.grey[300],
                    child: Icon(Icons.person, color: Colors.grey, size: 28),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    SizedBox(
                      height: 30,
                      child: Text(
                        formatStaffExperience(profile.experience),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceItem(dynamic service) {
    final note = service['note']?.toString() ?? '';
    final imageUrl = service['imageUrl']?.toString() ?? '';
    final serviceId = service['id']?.toString();

    return GestureDetector(
      onTap: serviceId == null
          ? null
          : () => _openBooking(initialServiceId: serviceId),
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.accentBeige),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildServiceImage(imageUrl),
                SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service['name'] ?? '未知服务',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (note.isNotEmpty) ...[
                              SizedBox(height: 5),
                              Text(
                                note,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service['duration'] ?? '',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          SizedBox(height: 8),
                          Text(
                            service['price'] ?? '免费',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        color: Colors.grey[200],
        child: imageUrl.isEmpty
            ? Icon(Icons.spa, color: Colors.grey[500])
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 240,
                filterQuality: FilterQuality.low,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                errorWidget: (context, url, error) =>
                    Icon(Icons.broken_image, color: Colors.grey[500]),
              ),
      ),
    );
  }
}

class _SalonDetailImageCarousel extends StatefulWidget {
  const _SalonDetailImageCarousel({required this.images});

  final List<String> images;

  @override
  State<_SalonDetailImageCarousel> createState() =>
      _SalonDetailImageCarouselState();
}

class _SalonDetailImageCarouselState extends State<_SalonDetailImageCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant _SalonDetailImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.join('|') == widget.images.join('|')) return;
    _currentIndex = 0;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.length == 1) {
      return _buildImage(widget.images.first);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            physics: BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) => _buildImage(widget.images[index]),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final isActive = index == _currentIndex;
              return AnimatedContainer(
                duration: Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 1.5),
                width: isActive ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isActive ? 0.95 : 0.65,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      memCacheWidth: 1100,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(
        color: Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey,
        child: Icon(Icons.broken_image, size: 50),
      ),
    );
  }
}
