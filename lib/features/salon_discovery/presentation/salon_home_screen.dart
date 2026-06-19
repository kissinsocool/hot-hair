import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
import '../../auth/data/user_auth_repository.dart';
import '../../auth/data/user_session_store.dart';
import '../../booking/data/booking_message_read_store.dart';
import '../../booking/data/order_repository.dart';
import '../../booking/data/review_repository.dart';
import '../../booking/data/booking_update_stream.dart';
import '../../booking/domain/booking_order.dart';
import '../data/favorite_salon_store.dart';
import '../data/salon_repository.dart';
import 'salon_address_formatter.dart';

class SalonHomeScreen extends StatefulWidget {
  const SalonHomeScreen({super.key});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
}

class _CityLocation {
  final String name;
  final double latitude;
  final double longitude;

  const _CityLocation(this.name, this.latitude, this.longitude);
}

class _SalonHomeScreenState extends State<SalonHomeScreen> {
  static const List<_CityLocation> _knownCities = [
    _CityLocation('上海市', 31.2304, 121.4737),
    _CityLocation('北京市', 39.9042, 116.4074),
    _CityLocation('广州市', 23.1291, 113.2644),
    _CityLocation('深圳市', 22.5431, 114.0579),
    _CityLocation('杭州市', 30.2741, 120.1551),
    _CityLocation('南京市', 32.0603, 118.7969),
    _CityLocation('苏州市', 31.2989, 120.5853),
    _CityLocation('成都市', 30.5728, 104.0668),
    _CityLocation('重庆市', 29.563, 106.5516),
    _CityLocation('武汉市', 30.5928, 114.3055),
    _CityLocation('西安市', 34.3416, 108.9398),
    _CityLocation('天津市', 39.3434, 117.3616),
  ];

  final SalonRepository _salonRepository = SalonRepository();
  final OrderRepository _orderRepository = OrderRepository();
  final ReviewRepository _reviewRepository = ReviewRepository();
  final UserAuthRepository _authRepository = UserAuthRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _hasBookingMessages = false;
  String? _latestBookingMessageKey;
  List<Map<String, dynamic>> _salons = [];
  List<BookingOrder> _bookingOrders = [];
  final Set<String> _reviewedOrderIds = {};
  final Set<String> _complainedOrderIds = {};
  String _errorMessage = '';
  String _searchKeyword = '';
  String? _locatedCity;
  String _locationMessage = '定位后优先展示同城沙龙';
  bool _isLocating = false;
  ClientAuthSession? _profileSession = UserSessionStore.currentSession;
  String _profileGender = '保密';
  String _profileAvatarUrl = '';
  bool _isSavingProfile = false;

  List<Map<String, dynamic>> get _filteredSalons {
    final keyword = _searchKeyword.trim().toLowerCase();
    final source = keyword.isEmpty
        ? List<Map<String, dynamic>>.from(_salons)
        : _salons.where((salon) {
            final name = (salon['name'] ?? '').toString().toLowerCase();
            return name.contains(keyword);
          }).toList();

    if (_locatedCity == null) return source;
    source.sort((left, right) {
      final leftMatch = _isSalonInLocatedCity(left) ? 0 : 1;
      final rightMatch = _isSalonInLocatedCity(right) ? 0 : 1;
      return leftMatch.compareTo(rightMatch);
    });
    return source;
  }

  @override
  void initState() {
    super.initState();
    _syncProfileControllers();
    _loadSalons();
    _loadBookingMessageStatus();
    BookingUpdateStream.instance.start();
    _bookingUpdateSubscription =
        BookingUpdateStream.instance.stream.listen((event) {
      if (event['event'] == 'booking.created' ||
          event['event'] == 'booking.updated') {
        _loadBookingMessageStatus();
      }
    });
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    _searchController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    super.dispose();
  }

  void _syncProfileControllers() {
    final user = _profileSession?.user;
    _profileNameController.text = user?.displayName ?? '';
    _profilePhoneController.text = user?.phone ?? user?.account ?? '';
    _profileGender = user?.gender.isNotEmpty == true ? user!.gender : '保密';
    _profileAvatarUrl = user?.avatarUrl ?? '';
  }

  ImageProvider? _profileAvatarImage() {
    if (_profileAvatarUrl.startsWith('data:image')) {
      final commaIndex = _profileAvatarUrl.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(
            base64Decode(_profileAvatarUrl.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    if (_profileAvatarUrl.isNotEmpty) {
      return NetworkImage(_profileAvatarUrl);
    }
    return null;
  }

  Future<void> _pickProfileAvatar() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 76,
      maxWidth: 512,
    );
    if (pickedImage == null) return;

    final bytes = await pickedImage.readAsBytes();
    final lowerName = pickedImage.name.toLowerCase();
    final mime = lowerName.endsWith('.png') ? 'image/png' : 'image/jpeg';
    setState(() {
      _profileAvatarUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _saveProfile() async {
    final displayName = _profileNameController.text.trim();
    final phone = _profilePhoneController.text.replaceAll(RegExp(r'\D'), '');
    if (displayName.isEmpty) {
      _showSnackBar('请输入昵称');
      return;
    }
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
      _showSnackBar('请输入有效的手机号');
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      final session = await _authRepository.updateProfile(
        displayName: displayName,
        gender: _profileGender,
        phone: phone,
        avatarUrl: _profileAvatarUrl,
      );
      await UserSessionStore.save(session);
      if (!mounted) return;
      setState(() {
        _profileSession = session;
        _syncProfileControllers();
      });
      _showSnackBar('资料已保存');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('保存失败，请稍后再试');
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _locateUser() async {
    setState(() {
      _isLocating = true;
      _locationMessage = '正在获取当前位置...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationMessage = '定位服务未开启';
          _isLocating = false;
        });
        _showSnackBar('请先开启系统定位服务');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationMessage = '未获得定位权限';
          _isLocating = false;
        });
        _showSnackBar('需要定位权限才能按位置推荐沙龙');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final city = _nearestKnownCity(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _locatedCity = city.name;
        _locationMessage = '已定位到${city.name}，同城沙龙优先';
        _isLocating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationMessage = '定位失败，继续展示全部沙龙';
        _isLocating = false;
      });
      _showSnackBar('定位失败，请稍后重试');
    }
  }

  _CityLocation _nearestKnownCity(double latitude, double longitude) {
    var nearest = _knownCities.first;
    var nearestDistance = double.infinity;
    for (final city in _knownCities) {
      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        city.latitude,
        city.longitude,
      );
      if (distance < nearestDistance) {
        nearest = city;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  bool _isSalonInLocatedCity(Map<String, dynamic> salon) {
    final city = _locatedCity;
    if (city == null) return false;
    final region = salon['addressRegion'];
    final values = <String>[
      salon['address']?.toString() ?? '',
      if (region is Map) ...[
        region['cityName']?.toString() ?? '',
        region['provinceName']?.toString() ?? '',
      ],
    ];
    return values.any((value) => value.contains(city));
  }

  Future<void> _loadSalons() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data = await _salonRepository.fetchSalons();
      setState(() {
        _salons = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookingMessageStatus() async {
    try {
      final orders = await _orderRepository.fetchUserBookings();
      if (!mounted) return;
      setState(() {
        _latestBookingMessageKey =
            BookingMessageReadStore.latestMessageKey(orders);
        _hasBookingMessages = BookingMessageReadStore.hasUnreadMessages(orders);
        _bookingOrders = orders;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _latestBookingMessageKey = null;
        _hasBookingMessages = false;
        _bookingOrders = [];
      });
    }
  }

  void _selectTab(int index) {
    if (index == 2) {
      BookingMessageReadStore.markRead(_latestBookingMessageKey);
      setState(() {
        _selectedTabIndex = index;
        _hasBookingMessages = false;
      });
      _loadBookingMessageStatus();
      return;
    }

    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSalons = _filteredSalons;
    final titles = ['探索沙龙', '收藏', '我的订单', '我'];

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        title: Text(titles[_selectedTabIndex],
            style: TextStyle(
                color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '预约消息',
            onPressed: () async {
              BookingMessageReadStore.markRead(_latestBookingMessageKey);
              setState(() => _hasBookingMessages = false);
              await context.push(AppRouter.userMessages);
              if (!mounted) return;
              _loadBookingMessageStatus();
            },
            icon: _buildNotificationIcon(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildExploreTab(filteredSalons),
          _buildFavoritesTab(),
          _buildOrdersTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: _selectTab,
        backgroundColor: AppTheme.white,
        indicatorColor: AppTheme.primaryPink.withOpacity(0.16),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: '探店',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: '收藏',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '我的订单',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab(List<Map<String, dynamic>> filteredSalons) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.accentBeige),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchKeyword = value),
              decoration: InputDecoration(
                icon: Icon(Icons.search, color: Colors.grey),
                hintText: '按名称搜索沙龙...',
                border: InputBorder.none,
                suffixIcon: _searchKeyword.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchKeyword = '');
                        },
                        icon: Icon(Icons.close, color: Colors.grey[500]),
                      ),
              ),
            ),
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentBeige),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.my_location_outlined,
                  color: AppTheme.primaryPink,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _locationMessage,
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _isLocating ? null : _locateUser,
                  icon: _isLocating
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryPink,
                          ),
                        )
                      : Icon(Icons.near_me_outlined, size: 17),
                  label: Text(_locatedCity == null ? '定位' : '重新定位'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryPink,
                    padding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 25),
          Text(_locatedCity == null ? '推荐沙龙' : '附近优先',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark)),
          SizedBox(height: 15),
          if (_isLoading)
            Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPink))
          else if (_errorMessage.isNotEmpty)
            Center(
              child: Column(
                children: [
                  Text('加载失败: $_errorMessage',
                      style: TextStyle(color: Colors.red)),
                  TextButton(onPressed: _loadSalons, child: Text('重新加载'))
                ],
              ),
            )
          else if (filteredSalons.isEmpty)
            _buildEmptySearchResult()
          else
            ...filteredSalons.map((salon) => _buildSalonCard(salon, context)),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_bookingOrders.isEmpty) {
      return _buildEmptyTab(
        Icons.receipt_long_outlined,
        '暂无订单',
        '完成预约后，订单会显示在这里',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryPink,
      onRefresh: _loadBookingMessageStatus,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: _bookingOrders.map(_buildOrderCard).toList(),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: FavoriteSalonStore.favorites,
      builder: (context, favorites, _) {
        if (favorites.isEmpty) {
          return _buildEmptyTab(
            Icons.favorite_border,
            '暂无收藏',
            '遇到喜欢的沙龙后可以先收藏起来',
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: favorites
              .map((salon) => _buildSalonCard(salon, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildOrderCard(BookingOrder order) {
    final color = switch (order.status) {
      'completed' => Colors.green,
      'accepted' => Colors.green,
      'rejected' => Colors.redAccent,
      _ => Colors.orange,
    };
    final canReview = order.status == 'completed';
    final canCancel = order.status == 'pending' || order.status == 'accepted';
    final isReviewed = order.reviewed || _reviewedOrderIds.contains(order.id);
    final isComplained =
        order.complained || _complainedOrderIds.contains(order.id);

    return InkWell(
      onTap: order.salonId.isEmpty
          ? null
          : () => context.pushNamed(
                'salon_detail',
                pathParameters: {'id': order.salonId},
              ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentBeige),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.serviceName,
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  order.statusLabel,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildOrderInfoRow(Icons.storefront, order.salonName),
            SizedBox(height: 6),
            _buildOrderInfoRow(Icons.person, order.staffName),
            SizedBox(height: 6),
            _buildOrderInfoRow(
                Icons.schedule, _dateFormat.format(order.startTime)),
            if (canReview || canCancel) ...[
              SizedBox(height: 14),
              if (canReview)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            isReviewed ? null : () => _showReviewSheet(order),
                        icon: Icon(
                          isReviewed
                              ? Icons.check_circle_outline
                              : Icons.rate_review_outlined,
                          size: 18,
                        ),
                        label: Text(isReviewed ? '已评价' : '评价晒单'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryPink,
                          side: BorderSide(color: AppTheme.primaryPink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isComplained
                            ? null
                            : () => _showComplaintSheet(order),
                        icon: Icon(
                          isComplained
                              ? Icons.check_circle_outline
                              : Icons.report_problem_outlined,
                          size: 18,
                        ),
                        label: Text(isComplained ? '已投诉' : '投诉'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancelOrder(order),
                    icon: Icon(Icons.event_busy_outlined, size: 18),
                    label: Text('取消订单'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancelOrder(BookingOrder order) async {
    final canCancelOnline = order.status == 'pending' ||
        order.startTime.difference(DateTime.now()) >= Duration(hours: 3);

    if (!canCancelOnline) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('无法直接取消'),
          content: Text(
            '距离预约开始不足3小时，请给商家打电话协商，由商家为您取消。\n\n如果直接爽约累计3次，账号将被拉黑。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('取消订单'),
        content: Text(
          order.status == 'pending'
              ? '当前订单还在等待商家确认，可以随时取消。确定要取消这次预约吗？'
              : '当前距离预约开始超过3小时，可以直接取消。确定要取消这次预约吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('再想想'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('确认取消', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orderRepository.cancelBooking(order.id);
      await _loadBookingMessageStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('订单已取消')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消失败，请稍后重试')),
      );
    }
  }

  Future<void> _showReviewSheet(BookingOrder order) async {
    final reviewController = TextEditingController();
    int rating = 0;
    List<XFile> images = [];
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImages() async {
              final remainCount = 5 - images.length;
              if (remainCount <= 0) return;

              final picked = await ImagePicker().pickMultiImage();
              if (picked.isEmpty) return;

              setSheetState(() {
                images = [
                  ...images,
                  ...picked.take(remainCount),
                ];
              });
            }

            Future<void> submitReview() async {
              if (isSubmitting) return;
              if (rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请先选择星级')),
                );
                return;
              }

              if (reviewController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入具体评价')),
                );
                return;
              }

              setSheetState(() => isSubmitting = true);
              try {
                await _reviewRepository.submitReview(
                  bookingId: order.id,
                  rating: rating,
                  comment: reviewController.text.trim(),
                  images: images,
                );
                if (!mounted) return;
                setState(() => _reviewedOrderIds.add(order.id));
                await _loadBookingMessageStatus();
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('评价晒单已提交')),
                );
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('提交失败，请稍后重试')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '评价晒单',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildOrderInfoRow(Icons.storefront, order.salonName),
                    SizedBox(height: 6),
                    _buildOrderInfoRow(Icons.content_cut, order.serviceName),
                    SizedBox(height: 18),
                    Text(
                      '选择星级',
                      style: TextStyle(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final selected = starValue <= rating;
                        return IconButton(
                          tooltip: '$starValue 星',
                          onPressed: () =>
                              setSheetState(() => rating = starValue),
                          icon: Icon(
                            selected ? Icons.star : Icons.star_border,
                            color: selected ? Colors.amber : Colors.grey[400],
                            size: 32,
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 14),
                    TextField(
                      controller: reviewController,
                      maxLines: 4,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: '分享这次服务体验...',
                        filled: true,
                        fillColor: AppTheme.bgCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.accentBeige),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.accentBeige),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.primaryPink, width: 1.4),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '上传图片 ${images.length}/5',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: images.length >= 5 ? null : pickImages,
                          icon: Icon(Icons.add_photo_alternate_outlined),
                          label: Text('选择图片'),
                        ),
                      ],
                    ),
                    if (images.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: images
                            .map(
                              (image) => _buildPickedImageTile(
                                image,
                                () => setSheetState(() => images.remove(image)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : submitReview,
                        icon: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.white,
                                ),
                              )
                            : Icon(Icons.send),
                        label: Text(isSubmitting ? '提交中...' : '提交评价'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    reviewController.dispose();
  }

  Future<void> _showComplaintSheet(BookingOrder order) async {
    final complaintController = TextEditingController();
    List<XFile> images = [];
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImages() async {
              final remainCount = 5 - images.length;
              if (remainCount <= 0) return;

              final picked = await ImagePicker().pickMultiImage();
              if (picked.isEmpty) return;

              setSheetState(() {
                images = [
                  ...images,
                  ...picked.take(remainCount),
                ];
              });
            }

            Future<void> submitComplaint() async {
              if (isSubmitting) return;
              if (complaintController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('请输入问题描述')),
                );
                return;
              }

              setSheetState(() => isSubmitting = true);
              try {
                await _reviewRepository.submitComplaint(
                  bookingId: order.id,
                  description: complaintController.text.trim(),
                  images: images,
                );
                if (!mounted) return;
                setState(() => _complainedOrderIds.add(order.id));
                await _loadBookingMessageStatus();
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('投诉已提交')),
                );
              } catch (_) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('提交失败，请稍后重试')),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '投诉',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _buildOrderInfoRow(Icons.storefront, order.salonName),
                    SizedBox(height: 6),
                    _buildOrderInfoRow(Icons.content_cut, order.serviceName),
                    SizedBox(height: 18),
                    TextField(
                      controller: complaintController,
                      maxLines: 5,
                      maxLength: 300,
                      decoration: InputDecoration(
                        hintText: '请描述遇到的问题...',
                        filled: true,
                        fillColor: AppTheme.bgCream,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.accentBeige),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.accentBeige),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: AppTheme.primaryPink, width: 1.4),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '上传图片 ${images.length}/5',
                            style: TextStyle(
                              color: AppTheme.textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: images.length >= 5 ? null : pickImages,
                          icon: Icon(Icons.add_photo_alternate_outlined),
                          label: Text('选择图片'),
                        ),
                      ],
                    ),
                    if (images.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: images
                            .map(
                              (image) => _buildPickedImageTile(
                                image,
                                () => setSheetState(() => images.remove(image)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : submitComplaint,
                        icon: isSubmitting
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.white,
                                ),
                              )
                            : Icon(Icons.send),
                        label: Text(isSubmitting ? '提交中...' : '提交投诉'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPink,
                          foregroundColor: AppTheme.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    complaintController.dispose();
  }

  Widget _buildPickedImageTile(XFile image, VoidCallback onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: image.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  width: 72,
                  height: 72,
                  color: AppTheme.bgCream,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 15, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        SizedBox(width: 7),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey[700])),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final avatarImage = _profileAvatarImage();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 28, 20, 112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primaryPink.withOpacity(0.18),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Icon(
                          Icons.person,
                          color: AppTheme.primaryPink,
                          size: 46,
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: AppTheme.primaryPink,
                    shape: CircleBorder(),
                    child: InkWell(
                      customBorder: CircleBorder(),
                      onTap: _pickProfileAvatar,
                      child: Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          color: AppTheme.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Text(
            _profileNameController.text.trim().isEmpty
                ? '完善个人资料'
                : _profileNameController.text.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '管理预约、收藏和个人资料',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accentBeige),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  controller: _profileNameController,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '昵称',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _profileGender,
                  items: const ['保密', '男', '女', '其他']
                      .map(
                        (gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _profileGender = value);
                  },
                  decoration: InputDecoration(
                    labelText: '性别',
                    prefixIcon: Icon(Icons.wc_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                TextField(
                  controller: _profilePhoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '电话号码',
                    prefixIcon: Icon(Icons.phone_iphone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingProfile ? null : _saveProfile,
                    icon: _isSavingProfile
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.white,
                            ),
                          )
                        : Icon(Icons.save_outlined),
                    label: Text(_isSavingProfile ? '保存中' : '保存资料'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPink,
                      foregroundColor: AppTheme.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_none, color: AppTheme.textDark),
        if (_hasBookingMessages)
          Positioned(
            top: -1,
            right: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySearchResult() {
    return Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              '没有找到匹配的沙龙',
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '换个名称试试看',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _salonCoverImageUrl(Map<String, dynamic> salon) {
    final image = salon['image']?.toString().trim() ?? '';
    return image.isNotEmpty ? image : 'https://via.placeholder.com/400x180';
  }

  Widget _buildSalonImage(Map<String, dynamic> salon) {
    return Image.network(
      _salonCoverImageUrl(salon),
      height: 180,
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 180,
        color: Colors.grey,
        child: Icon(Icons.broken_image),
      ),
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon, BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed(
        'salon_detail',
        pathParameters: {'id': salon['id'].toString()},
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              child: _buildSalonImage(salon),
            ),
            Padding(
              padding: EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(salon['name'] ?? '未知沙龙',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark)),
                      Text('⭐ ${salon['rating']}',
                          style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text(formatSalonCityAddress(salon['address']),
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  SizedBox(height: 10),
                  Text(
                    salon['description'] ?? '暂无描述',
                    style: TextStyle(
                        color: Colors.black87, fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
