import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/staff_experience_formatter.dart';
import '../domain/staff_model.dart';
import '../domain/booking_model.dart';
import 'booking_screen.dart';
import '../../../core/network/api_client.dart';

class StaffDetailScreen extends ConsumerStatefulWidget {
  final String staffId;
  final String? salonId;
  final StaffProfile? staffProfile;
  final List<StaffProfile>? allStaffInSalon; // 新增：接收店铺所有理发师
  final List<SalonService>? initialServices;
  final List<String> closedDates;

  const StaffDetailScreen({
    super.key,
    required this.staffId,
    this.salonId,
    this.staffProfile,
    this.allStaffInSalon,
    this.initialServices,
    this.closedDates = const [],
  });

  @override
  ConsumerState<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends ConsumerState<StaffDetailScreen> {
  bool _isLoading = false;
  StaffProfile? _fetchedStaff;
  List<StaffProfile>? _fetchedStaffInSalon;
  List<SalonService>? _fetchedServices;
  String? _fetchedSalonId;
  List<String> _fetchedClosedDates = const [];

  @override
  void initState() {
    super.initState();
    if (widget.staffProfile == null) {
      _loadStaffDetail();
    }
  }

  Future<void> _loadStaffDetail() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient();
      final response = await apiClient.request('/staff/${widget.staffId}');
      final data = response.data as Map<String, dynamic>;

      setState(() {
        _fetchedStaff = StaffProfile(
          id: data['id'].toString(),
          name: data['name'] ?? '',
          role: data['role'] ?? '',
          experience: data['experience'] ?? '',
          extraServiceFee: _parseInt(data['extraServiceFee']),
          imageUrl: ApiClient.mediaUrl(data['imageUrl']?.toString() ?? ''),
          bio: data['bio'] ?? '',
          rating: (data['rating'] ?? 0.0).toDouble(),
          reviews: (data['reviews'] as List?)
                  ?.map((r) => _parseReview(Map<String, dynamic>.from(r)))
                  .toList() ??
              [],
        );
        _fetchedStaffInSalon = (data['salonStaff'] as List?)
            ?.map((item) => _parseStaffProfile(Map<String, dynamic>.from(item)))
            .toList();
        _fetchedServices = (data['salonServices'] as List?)
            ?.map((item) => _parseSalonService(Map<String, dynamic>.from(item)))
            .toList();
        _fetchedSalonId = data['salonId']?.toString();
        _fetchedClosedDates = (data['salonClosedDates'] as List?)
                ?.map((date) => date.toString())
                .toList() ??
            const [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载理发师详情失败')));
    }
  }

  StaffProfile _parseStaffProfile(Map<String, dynamic> data) {
    return StaffProfile(
      id: data['id'].toString(),
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      experience: data['experience'] ?? '',
      extraServiceFee: _parseInt(data['extraServiceFee']),
      imageUrl: ApiClient.mediaUrl(data['imageUrl']?.toString() ?? ''),
      bio: data['bio'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviews: (data['reviews'] as List?)
              ?.map((r) => _parseReview(Map<String, dynamic>.from(r)))
              .toList() ??
          [],
    );
  }

  Review _parseReview(Map<String, dynamic> data) {
    final merchantReply = data['merchantReply'];
    final replyContent = merchantReply is Map
        ? merchantReply['content']?.toString() ?? ''
        : merchantReply?.toString() ?? '';
    final replyDate = merchantReply is Map
        ? merchantReply['repliedAt']?.toString() ?? ''
        : '';

    return Review(
      userName: data['user'] ?? data['userName'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      comment: data['comment'] ?? '',
      date: data['date'] ?? '',
      imageUrls: (data['imageUrls'] as List?)
              ?.map((item) => ApiClient.mediaUrl(item.toString()))
              .toList() ??
          [],
      merchantReply: replyContent,
      merchantReplyDate: replyDate,
    );
  }

  SalonService _parseSalonService(Map<String, dynamic> data) {
    final durationText = data['duration']?.toString() ?? '';
    final durationMinutes =
        int.tryParse(RegExp(r'\d+').firstMatch(durationText)?.group(0) ?? '') ??
            60;
    return SalonService(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      durationMinutes: durationMinutes,
      imageUrl: ApiClient.mediaUrl(data['imageUrl']?.toString() ?? ''),
      note: data['note']?.toString() ?? '',
      priceLabel: data['price']?.toString() ?? '',
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staffProfile ??
        _fetchedStaff ??
        mockStaffList.firstWhere(
          (s) => s.id == widget.staffId,
          orElse: () => mockStaff,
        );
    final displayRating = _displayRating(staff);

    if (_isLoading && widget.staffProfile == null) {
      return Scaffold(
        backgroundColor: AppTheme.bgCream,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.primaryPink)),
      );
    }

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
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.white,
              padding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundImage: staff.imageUrl.startsWith('assets/')
                        ? null
                        : NetworkImage(staff.imageUrl),
                    child: staff.imageUrl.startsWith('assets/')
                        ? ClipOval(
                            child: AppImages.placeholder(
                              width: 140,
                              height: 140,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(height: 20),
                  Text(staff.name,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  SizedBox(height: 8),
                  Chip(
                      label: Text(staff.role,
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: AppTheme.primaryPink),
                  SizedBox(height: 10),
                  Text(formatStaffExperience(staff.experience),
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(displayRating.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRatingStars(displayRating, size: 18),
                      Text('基于 ${staff.reviews.length} 位客户评价',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accentBeige)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('关于我',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark)),
                    SizedBox(height: 10),
                    Text(staff.bio,
                        style: TextStyle(
                            color: AppTheme.textDark,
                            height: 1.6,
                            fontSize: 15)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('客户评价',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark)),
                  SizedBox(height: 15),
                  if (staff.reviews.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child:
                            Text('暂无评价', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...staff.reviews
                        .map((review) => _buildReviewCard(review))
                        .toList(),
                ],
              ),
            ),
            SizedBox(height: 36),
          ],
        ),
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
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BookingScreen(
                            salonId: widget.salonId ?? _fetchedSalonId ?? '',
                            initialStaffList:
                                widget.allStaffInSalon ?? _fetchedStaffInSalon,
                            initialServices:
                                widget.initialServices ?? _fetchedServices,
                            preferredStaffId: staff.id, // 默认选中当前理发师
                            closedDates: widget.closedDates.isNotEmpty
                                ? widget.closedDates
                                : _fetchedClosedDates,
                          )));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              '立即预约',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Container(
      margin: EdgeInsets.only(bottom: 7.5),
      padding: EdgeInsets.all(7.5),
      decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppTheme.accentBeige)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(review.userName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.textDark)),
              Text(review.date,
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          SizedBox(height: 5),
          _buildRatingStars(review.rating, size: 14),
          SizedBox(height: 10),
          Text(review.comment,
              style: TextStyle(color: AppTheme.textDark, height: 1.4)),
          if (review.imageUrls.isNotEmpty) ...[
            SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: review.imageUrls
                  .map(
                    (url) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: Colors.grey[200],
                          child: AppImages.placeholder(width: 72, height: 72),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (review.merchantReply.isNotEmpty) ...[
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
                    review.merchantReply,
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

  double _displayRating(StaffProfile staff) {
    return staff.reviews.isEmpty ? 5.0 : staff.rating;
  }
}
