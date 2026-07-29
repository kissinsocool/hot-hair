import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
import '../../../core/widgets/coupon_ticket.dart';
import '../../../core/widgets/top_snack_bar.dart';
import '../../auth/data/user_auth_repository.dart';
import '../../auth/data/user_session_store.dart';
import '../../booking/data/booking_message_read_store.dart';
import '../../booking/data/order_repository.dart';
import '../../booking/data/review_repository.dart';
import '../../booking/data/booking_update_stream.dart';
import '../../booking/domain/booking_order.dart';
import '../data/favorite_salon_store.dart';
import '../data/location_position_service.dart';
import '../data/location_reverse_geocode_repository.dart';
import '../data/salon_repository.dart';
import 'location_address_formatter.dart';
import 'salon_address_formatter.dart';
import 'ad_campaign_screen.dart';

class SalonHomeScreen extends StatefulWidget {
  const SalonHomeScreen({super.key});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
}

class _NoticeMarquee extends StatefulWidget {
  const _NoticeMarquee();

  static const message = '在服务过程中如果遇到强迫购买产品、升级项目、充值或办理会员卡等问题请第一时间向平台客服举报反馈！';

  @override
  State<_NoticeMarquee> createState() => _NoticeMarqueeState();
}

class _NoticeMarqueeState extends State<_NoticeMarquee> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scroll());
  }

  Future<void> _scroll() async {
    while (mounted) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted ||
          !_controller.hasClients ||
          MediaQuery.disableAnimationsOf(context)) {
        return;
      }

      final distance = _controller.position.maxScrollExtent;
      if (distance <= 0) return;
      await _controller.animateTo(
        distance,
        duration: Duration(milliseconds: (distance * 24).round()),
        curve: Curves.linear,
      );
      if (_controller.hasClients) _controller.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _NoticeMarquee.message,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryPink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const ExcludeSemantics(
              child:
                  Icon(Icons.campaign, color: AppTheme.primaryPink, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ExcludeSemantics(
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: const Center(
                    child: Text(
                      _NoticeMarquee.message,
                      maxLines: 1,
                      style: TextStyle(
                        color: Color(0xFFD06884),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonHomeScreenState extends State<SalonHomeScreen> {
  static bool _hasRequestedInitialLocationForSession = false;
  static Position? _cachedUserPosition;
  static String? _cachedLocationMessage;
  static const int _salonPageSize = 10;

  final SalonRepository _salonRepository = SalonRepository();
  final LocationReverseGeocodeRepository _locationRepository =
      LocationReverseGeocodeRepository();
  final OrderRepository _orderRepository = OrderRepository();
  final ReviewRepository _reviewRepository = ReviewRepository();
  final UserAuthRepository _authRepository = UserAuthRepository();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _searchFieldLayerLink = LayerLink();
  final GlobalKey _searchFieldKey = GlobalKey();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  OverlayEntry? _searchSuggestionsOverlay;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _isExploreScrolling = false;
  bool _hasBookingMessages = false;
  bool _ordersLoadFailed = false;
  String? _bookingMessageStateKey;
  List<Map<String, dynamic>> _salons = [];
  int _visibleSalonCount = _salonPageSize;
  bool _salonsLoadedWithPosition = false;
  List<BookingOrder> _bookingOrders = [];
  List<Map<String, dynamic>> _myReviews = [];
  List<Map<String, dynamic>> _coupons = [];
  bool _couponsLoading = true;
  bool _couponsLoadFailed = false;
  List<Map<String, dynamic>> _searchSuggestionSalons = [];
  final Set<String> _reviewedOrderIds = {};
  final Set<String> _complainedOrderIds = {};
  String _errorMessage = '';
  String _searchKeyword = '';
  String _searchDraft = '';
  bool _isLoadingSearchSuggestions = false;
  Timer? _searchSuggestionDebounce;
  int _salonRequestId = 0;
  int _searchSuggestionRequestId = 0;
  double _searchFieldWidth = 0;
  Position? _userPosition;
  String _locationMessage = '定位后按距离展示附近沙龙';
  bool _adEnabled = true;
  String _adImageUrl = '';

  List<Map<String, dynamic>> get _filteredSalons {
    final keyword = _searchKeyword.trim().toLowerCase();
    final source = keyword.isEmpty
        ? List<Map<String, dynamic>>.from(_salons)
        : _salons.where((salon) {
            final name = (salon['name'] ?? '').toString().toLowerCase();
            return name.contains(keyword);
          }).toList();

    return source;
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _restoreCachedLocation();
    if (_userPosition != null) _loadSalons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateUserOnceOnOpen();
    });
    _loadBookingMessageStatus();
    _loadMyReviews();
    _loadCoupons();
    _loadAdCampaign();
    BookingUpdateStream.instance.start();
    _bookingUpdateSubscription =
        BookingUpdateStream.instance.stream.listen((event) {
      if (event['event'] == 'booking.created' ||
          event['event'] == 'booking.updated') {
        _loadBookingMessageStatus();
      }
    });
  }

  Future<void> _loadAdCampaign() async {
    final ad = await _salonRepository.fetchAdCampaign();
    if (!mounted) return;
    setState(() {
      _adEnabled = ad['enabled'] == true;
      _adImageUrl = ad['imageUrl']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    _searchSuggestionDebounce?.cancel();
    _removeSearchSuggestionsOverlay();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  ImageProvider? _profileAvatarImage() {
    final avatarUrl = UserSessionStore.currentSession?.user.avatarUrl ?? '';
    if (avatarUrl.startsWith('data:image')) {
      final commaIndex = avatarUrl.indexOf(',');
      if (commaIndex == -1) return null;
      try {
        return MemoryImage(base64Decode(avatarUrl.substring(commaIndex + 1)));
      } catch (_) {
        return null;
      }
    }
    if (avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }
    return null;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      topSnackBar(context, message),
    );
  }

  void _handleSearchFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      if (_searchController.text.trim().isNotEmpty) {
        _scheduleSearchSuggestions(_searchController.text);
      } else {
        _syncSearchSuggestionsOverlay();
      }
    } else {
      _removeSearchSuggestionsOverlay();
    }
  }

  void _restoreCachedLocation() {
    final cachedMessage = _cachedLocationMessage;
    if (cachedMessage == null) return;

    _userPosition = _cachedUserPosition;
    _locationMessage = cachedMessage;
  }

  void _cacheCurrentLocationState() {
    _cachedUserPosition = _userPosition;
    _cachedLocationMessage = _locationMessage;
  }

  void _locateUserOnceOnOpen() {
    if (!mounted || _hasRequestedInitialLocationForSession) return;
    _hasRequestedInitialLocationForSession = true;
    _locateUser(showFailureSnackBar: false);
  }

  Future<void> _locateUser({bool showFailureSnackBar = true}) async {
    setState(() {
      _locationMessage = '正在获取当前位置...';
      _cacheCurrentLocationState();
    });

    try {
      final position = await LocationPositionService.currentPosition();
      final accuracyLabel = _formatLocationAccuracy(position.accuracy);
      final locationMessage = '已获取当前位置$accuracyLabel，附近沙龙优先';
      _cachedUserPosition = position;
      _cachedLocationMessage = locationMessage;
      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _locationMessage = locationMessage;
        _visibleSalonCount = _salonPageSize;
      });
      unawaited(_loadSalons());
      unawaited(_refreshCurrentAddress(position));
    } catch (error) {
      debugPrint('首页定位失败: $error');
      const message = '定位失败，请重试';
      _cachedUserPosition = null;
      _cachedLocationMessage = message;
      if (!mounted) return;
      setState(() {
        _locationMessage = message;
        _isLoading = false;
        _salons = [];
        _salonsLoadedWithPosition = false;
      });
      if (showFailureSnackBar) _showSnackBar(message);
    }
  }

  Future<void> _refreshCurrentAddress(Position position) async {
    final addressLabel = await _formatCurrentAddress(position);
    if (addressLabel == null || !mounted) return;
    final currentPosition = _userPosition;
    if (currentPosition == null ||
        currentPosition.latitude != position.latitude ||
        currentPosition.longitude != position.longitude) {
      return;
    }

    final locationMessage = formatLocationLeafAddress(addressLabel);
    setState(() {
      _locationMessage = locationMessage;
      _cacheCurrentLocationState();
    });
  }

  Future<String?> _formatCurrentAddress(Position position) async {
    try {
      final address = await _locationRepository.reverseGeocode(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (address != null && address.isNotEmpty) return address;
    } catch (_) {
      // Fall back to the platform geocoder below.
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;

      final address = formatPlacemarkAddress(placemarks.first);
      return address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openLocationPicker() async {
    final selection = await context.pushNamed<Map<String, dynamic>>(
      'location_picker',
      queryParameters: {
        'current': _locationMessage,
        if (_userPosition != null) ...{
          'latitude': _userPosition!.latitude.toString(),
          'longitude': _userPosition!.longitude.toString(),
        },
      },
    );
    final address = selection?['address']?.toString().trim();
    if (!mounted || address == null || address.isEmpty) return;
    setState(() {
      _locationMessage = formatLocationLeafAddress(address);
      _visibleSalonCount = _salonPageSize;
      final latitude =
          double.tryParse(selection?['latitude']?.toString() ?? '');
      final longitude =
          double.tryParse(selection?['longitude']?.toString() ?? '');
      if (latitude != null && longitude != null) {
        _userPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy:
              double.tryParse(selection?['accuracy']?.toString() ?? '') ?? 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      _cacheCurrentLocationState();
    });
    unawaited(_loadSalons());
  }

  double? _salonDistanceMeters(Map<String, dynamic> salon) {
    if (!_salonsLoadedWithPosition) return null;

    final serverDistanceKm =
        double.tryParse(salon['distanceKm']?.toString() ?? '');
    if (serverDistanceKm != null) return serverDistanceKm * 1000;

    final position = _userPosition;
    if (position == null) return null;

    final location = salon['location'];
    if (location is! Map) return null;
    final latitude = double.tryParse(location['latitude']?.toString() ?? '');
    final longitude = double.tryParse(location['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;

    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }

  String? _formatSalonDistance(Map<String, dynamic> salon) {
    final distanceMeters = _salonDistanceMeters(salon);
    if (distanceMeters == null) return null;

    if (distanceMeters < 1000) {
      final roundedMeters = (distanceMeters / 10).round() * 10;
      return '距离你 ${roundedMeters.clamp(10, 990)} m';
    }

    return '距离你 ${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String _formatLocationAccuracy(double accuracyMeters) {
    if (!accuracyMeters.isFinite || accuracyMeters <= 0) return '';
    if (accuracyMeters >= 1000) {
      return '（精度约${(accuracyMeters / 1000).toStringAsFixed(1)}km，请开启精确位置）';
    }
    return '（精度约${accuracyMeters.round()}m）';
  }

  Future<void> _loadSalons() async {
    final requestId = ++_salonRequestId;
    final position = _userPosition;
    if (position == null) {
      setState(() {
        _isLoading = false;
        _salons = [];
        _salonsLoadedWithPosition = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final data = await _salonRepository.fetchSalons(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted || requestId != _salonRequestId) return;
      setState(() {
        _salons = data;
        _salonsLoadedWithPosition = true;
        _visibleSalonCount = _salonPageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _salonRequestId) return;
      setState(() {
        _errorMessage = '糟糕，网络好像有点问题，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _scheduleSearchSuggestions(String value) {
    _searchSuggestionDebounce?.cancel();
    final keyword = value.trim();
    _searchDraft = keyword;

    if (keyword.isEmpty) {
      setState(() {
        _isLoadingSearchSuggestions = false;
        _searchSuggestionSalons = [];
      });
      _removeSearchSuggestionsOverlay();
      return;
    }

    setState(() {
      _isLoadingSearchSuggestions = true;
      _searchSuggestionSalons = [];
    });
    _syncSearchSuggestionsOverlay();
    _searchSuggestionDebounce = Timer(
      Duration(milliseconds: 250),
      () => _loadSearchSuggestions(keyword),
    );
  }

  Future<void> _loadSearchSuggestions(String keyword) async {
    final requestId = ++_searchSuggestionRequestId;

    try {
      final remoteSuggestions = await _salonRepository.fetchSalonSuggestions(
        keyword: keyword,
        latitude: _userPosition?.latitude,
        longitude: _userPosition?.longitude,
      );
      final suggestions = remoteSuggestions.isEmpty
          ? _localSalonSuggestions(keyword)
          : remoteSuggestions;

      if (!mounted || requestId != _searchSuggestionRequestId) return;
      if (_searchDraft != keyword) return;

      setState(() {
        _isLoadingSearchSuggestions = false;
        _searchSuggestionSalons = suggestions;
      });
      _syncSearchSuggestionsOverlay();
    } catch (_) {
      if (!mounted || requestId != _searchSuggestionRequestId) return;
      if (_searchDraft != keyword) return;

      setState(() {
        _isLoadingSearchSuggestions = false;
        _searchSuggestionSalons = _localSalonSuggestions(keyword);
      });
      _syncSearchSuggestionsOverlay();
    }
  }

  List<Map<String, dynamic>> _localSalonSuggestions(String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) return [];

    final matches = _salons.where((salon) {
      final name = (salon['name'] ?? '').toString().toLowerCase();
      return name.contains(normalizedKeyword);
    }).toList();

    return matches.take(5).toList();
  }

  bool get _shouldShowSearchSuggestionsOverlay {
    if (!_searchFocusNode.hasFocus) return false;
    if (_selectedTabIndex != 0) return false;
    if (_searchDraft.isEmpty) return false;
    return _isLoadingSearchSuggestions || _searchSuggestionSalons.isNotEmpty;
  }

  void _syncSearchSuggestionsOverlay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _searchFieldKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        _searchFieldWidth = renderBox.size.width;
      }

      if (!_shouldShowSearchSuggestionsOverlay) {
        _removeSearchSuggestionsOverlay();
        return;
      }

      if (_searchSuggestionsOverlay == null) {
        _searchSuggestionsOverlay = OverlayEntry(
          builder: (context) => _buildSearchSuggestionsOverlay(),
        );
        Overlay.of(context).insert(_searchSuggestionsOverlay!);
      } else {
        _searchSuggestionsOverlay!.markNeedsBuild();
      }
    });
  }

  void _removeSearchSuggestionsOverlay() {
    _searchSuggestionsOverlay?.remove();
    _searchSuggestionsOverlay = null;
  }

  Widget _buildSearchSuggestionsOverlay() {
    final fallbackWidth = (MediaQuery.sizeOf(context).width - 20) * 0.98;
    final panelWidth =
        _searchFieldWidth > 0 ? _searchFieldWidth : fallbackWidth;

    return Positioned.fill(
      child: CompositedTransformFollower(
        link: _searchFieldLayerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomCenter,
        followerAnchor: Alignment.topCenter,
        offset: const Offset(0, 6),
        child: Material(
          color: Colors.transparent,
          child: UnconstrainedBox(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: panelWidth,
              child: _buildSearchSuggestionPanel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestionPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.accentBeige),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _isLoadingSearchSuggestions
          ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryPink,
                      ),
                    ),
                    SizedBox(width: 7),
                    Text('加载中', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: _searchSuggestionSalons
                  .map((salon) => _buildSearchSuggestionItem(salon))
                  .toList(),
            ),
    );
  }

  Widget _buildSearchSuggestionItem(Map<String, dynamic> salon) {
    final name = salon['name']?.toString() ?? '';
    final distanceLabel = _formatSalonDistance(salon);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _selectSearchSuggestion(name),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? '未知沙龙' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    formatSalonCityAddress(salon),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                if (distanceLabel != null) ...[
                  SizedBox(width: 8),
                  Text(
                    distanceLabel,
                    style: TextStyle(
                      color: AppTheme.primaryPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectSearchSuggestion(String name) {
    _searchController.text = name;
    _searchController.selection = TextSelection.collapsed(offset: name.length);
    _submitSalonSearch();
  }

  Future<void> _loadBookingMessageStatus() async {
    try {
      final orders = await _orderRepository.fetchUserBookings();
      if (!mounted) return;
      setState(() {
        _bookingMessageStateKey =
            BookingMessageReadStore.messageStateKey(orders);
        _hasBookingMessages = BookingMessageReadStore.hasUnreadMessages(orders);
        _bookingOrders = orders;
        _ordersLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bookingMessageStateKey = null;
        _hasBookingMessages = false;
        _bookingOrders = [];
        _ordersLoadFailed = true;
      });
    }
  }

  Future<void> _loadMyReviews() async {
    try {
      final reviews = await _reviewRepository.fetchMyReviews();
      if (mounted) setState(() => _myReviews = reviews);
    } catch (_) {
      if (mounted) setState(() => _myReviews = []);
    }
  }

  void _selectTab(int index) {
    if (index != 0) {
      _removeSearchSuggestionsOverlay();
      _searchFocusNode.unfocus();
    }

    if (index == 2) {
      unawaited(BookingMessageReadStore.markRead(_bookingMessageStateKey));
      setState(() {
        _selectedTabIndex = index;
        _hasBookingMessages = false;
      });
      _loadBookingMessageStatus();
      return;
    }

    if (index == 3) unawaited(_loadCoupons());

    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final filteredSalons = _filteredSalons;
    final titles = ['', '收藏', '我的订单', '我的'];

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryPink,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.white),
        title: _selectedTabIndex == 0
            ? _buildLocationModule()
            : Text(titles[_selectedTabIndex],
                style: TextStyle(
                    color: AppTheme.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '预约消息',
            onPressed: () async {
              await context.push(AppRouter.userMessages);
              if (!mounted) return;
              _loadBookingMessageStatus();
            },
            icon: _buildNotificationIcon(),
          ),
        ],
        bottom: _selectedTabIndex == 0
            ? PreferredSize(
                preferredSize: Size.fromHeight(58),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 10, 5),
                  child: Transform.translate(
                    offset: const Offset(0, -8),
                    child: FractionallySizedBox(
                      widthFactor: 0.98,
                      child: _buildSearchField(),
                    ),
                  ),
                ),
              )
            : null,
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
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab(List<Map<String, dynamic>> filteredSalons) {
    final visibleSalons = filteredSalons.take(_visibleSalonCount).toList();
    final headerCount =
        _isLoading || _errorMessage.isNotEmpty || visibleSalons.isEmpty ? 1 : 0;
    final adCount = _adEnabled ? 1 : 0;
    final itemCount = 3 + adCount + headerCount + visibleSalons.length;

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.axis != Axis.vertical) return false;

              if (notification is ScrollStartNotification &&
                  !_isExploreScrolling) {
                setState(() => _isExploreScrolling = true);
              } else if (notification is ScrollEndNotification) {
                final loadMore = notification.metrics.extentAfter == 0 &&
                    _visibleSalonCount < filteredSalons.length;
                if (_isExploreScrolling || loadMore) {
                  setState(() {
                    _isExploreScrolling = false;
                    if (loadMore) _visibleSalonCount += _salonPageSize;
                  });
                }
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 14),
              cacheExtent: 420,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (_adEnabled && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: AdCampaignBanner(imageUrl: _adImageUrl),
                  );
                }
                index -= adCount;
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: 11),
                    child: _NoticeMarquee(),
                  );
                }
                if (index == 1) {
                  return Text(_salonsLoadedWithPosition ? '附近的店铺' : '推荐沙龙',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark));
                }
                if (index == 2) return SizedBox(height: 15);

                final contentIndex = index - 3;
                if (_isLoading) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryPink));
                }
                if (_errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Text(_errorMessage,
                            style: TextStyle(color: Colors.red)),
                        TextButton(onPressed: _loadSalons, child: Text('重新加载'))
                      ],
                    ),
                  );
                }
                if (visibleSalons.isEmpty) return _buildEmptySearchResult();

                return _buildSalonCard(visibleSalons[contentIndex], context);
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: AnimatedSlide(
            offset: _isExploreScrolling ? const Offset(2 / 3, 0) : Offset.zero,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _isExploreScrolling ? 1 / 3 : 0.8,
              duration: const Duration(milliseconds: 240),
              child: IgnorePointer(
                ignoring: _isExploreScrolling,
                child: Semantics(
                  label: '平台客服',
                  button: true,
                  child: Material(
                    elevation: 4,
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(AppRouter.support),
                      child: const SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          Icons.support_agent,
                          color: AppTheme.primaryPink,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return CompositedTransformTarget(
      link: _searchFieldLayerLink,
      child: Container(
        key: _searchFieldKey,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textAlignVertical: TextAlignVertical.center,
                onChanged: _scheduleSearchSuggestions,
                onSubmitted: (_) => _submitSalonSearch(),
                decoration: InputDecoration(
                  hintText: '按名称搜索沙龙...',
                  hintStyle: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.only(
                    left: MediaQuery.sizeOf(context).width * 0.04,
                    top: 5,
                    bottom: 5,
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 58,
                    minHeight: 38,
                  ),
                  suffixIcon: Padding(
                    padding: EdgeInsets.fromLTRB(0, 4, 4, 4),
                    child: TextButton(
                      onPressed: _submitSalonSearch,
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.primaryPink,
                        foregroundColor: AppTheme.white,
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size(55, 31),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        '搜索',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitSalonSearch() {
    _searchSuggestionDebounce?.cancel();
    _removeSearchSuggestionsOverlay();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchKeyword = _searchController.text.trim();
      _searchDraft = _searchKeyword;
      _visibleSalonCount = _salonPageSize;
      _isLoadingSearchSuggestions = false;
      _searchSuggestionSalons = [];
    });
  }

  Widget _buildLocationModule() {
    final locationLabel = formatLocationLeafAddress(_locationMessage);
    final pickerButton = IconButton(
      tooltip: '选择地址',
      onPressed: _openLocationPicker,
      icon: const Icon(Icons.keyboard_arrow_down, size: 24),
      color: AppTheme.white,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    );

    final message = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          color: AppTheme.white,
          size: 20,
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            locationLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
            child: IntrinsicWidth(
              child: InkWell(
                onTap: _openLocationPicker,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: message),
                      SizedBox(width: 4),
                      pickerButton,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_ordersLoadFailed) {
      return _buildRequestError(_loadBookingMessageStatus);
    }
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
        padding: EdgeInsets.fromLTRB(10, 10, 10, 14),
        children: _bookingOrders.map(_buildOrderCard).toList(),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: FavoriteSalonStore.favorites,
      builder: (context, favorites, _) {
        if (FavoriteSalonStore.loadFailed) {
          return _buildRequestError(FavoriteSalonStore.load);
        }
        if (favorites.isEmpty) {
          return _buildEmptyTab(
            Icons.favorite_border,
            '暂无收藏',
            '遇到喜欢的沙龙后可以先收藏起来',
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 14),
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
        margin: EdgeInsets.only(bottom: 7),
        padding: EdgeInsets.all(8),
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
            _buildOrderInfoRow(
                Icons.confirmation_number, '订单号 ${order.orderNo}'),
            SizedBox(height: 6),
            _buildOrderInfoRow(Icons.storefront, order.salonName),
            SizedBox(height: 6),
            _buildOrderInfoRow(Icons.person, order.staffName),
            SizedBox(height: 6),
            _buildOrderInfoRow(
                Icons.schedule, _dateFormat.format(order.startTime)),
            if (order.couponDiscountFen > 0) ...[
              SizedBox(height: 6),
              _buildOrderInfoRow(
                Icons.local_activity_outlined,
                '${order.couponTitle}，优惠'
                ' ¥${(order.couponDiscountFen / 100).toStringAsFixed(2)}，'
                '到店支付 ¥${(order.payableAmountFen / 100).toStringAsFixed(2)}',
              ),
            ],
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
      _showSnackBar('订单已取消');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消失败，请稍后重试')),
      );
    }
  }

  Future<void> _showReviewSheet(BookingOrder order) => _showReviewEditor(
        bookingId: order.id,
        salonName: order.salonName,
        serviceName: order.serviceName,
        onSubmit: (rating, comment, retainedImageUrls, images) =>
            _reviewRepository.submitReview(
          bookingId: order.id,
          rating: rating,
          comment: comment,
          images: images,
        ),
      );

  Future<void> _showEditReviewSheet(Map<String, dynamic> review) {
    final imageUrls = ((review['imageUrls'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();
    final imageKeys = ((review['imageKeys'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();
    return _showReviewEditor(
      bookingId: review['bookingId']?.toString() ?? '',
      salonName: review['salonName']?.toString() ?? '',
      serviceName: review['serviceName']?.toString() ?? '',
      initialRating: (review['rating'] as num?)?.toInt() ?? 0,
      initialComment: review['comment']?.toString() ?? '',
      initialImageUrls: imageUrls,
      initialImageKeys: imageKeys,
      isEditing: true,
      onSubmit: (rating, comment, retainedImageUrls, images) =>
          _reviewRepository.updateReview(
        bookingId: review['bookingId']?.toString() ?? '',
        rating: rating,
        comment: comment,
        retainedImageUrls: retainedImageUrls,
        images: images,
      ),
    );
  }

  Future<void> _showReviewEditor({
    required String bookingId,
    required String salonName,
    required String serviceName,
    required Future<void> Function(
      int rating,
      String comment,
      List<String> retainedImageUrls,
      List<XFile> images,
    ) onSubmit,
    int initialRating = 0,
    String initialComment = '',
    List<String> initialImageUrls = const [],
    List<String> initialImageKeys = const [],
    bool isEditing = false,
  }) async {
    final reviewController = TextEditingController(text: initialComment);
    int rating = initialRating;
    List<XFile> images = [];
    final retainedImages = List.generate(
      initialImageUrls.length.clamp(0, initialImageKeys.length),
      (index) => MapEntry(initialImageKeys[index], initialImageUrls[index]),
    );
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
              final remainCount = 5 - retainedImages.length - images.length;
              if (remainCount <= 0) return;

              final picked = await ImagePicker().pickMultiImage(
                maxWidth: 1280,
                maxHeight: 1280,
              );
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
                await onSubmit(
                  rating,
                  reviewController.text.trim(),
                  retainedImages.map((image) => image.key).toList(),
                  images,
                );
                if (!mounted) return;
                setState(() => _reviewedOrderIds.add(bookingId));
                await _loadBookingMessageStatus();
                await _loadMyReviews();
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                _showSnackBar(isEditing ? '评价修改已提交审核' : '评价晒单已提交');
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSubmitting = false);
                await _showReviewSubmitError(sheetContext, e);
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 9,
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
                              isEditing ? '编辑评价' : '评价晒单',
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
                      _buildOrderInfoRow(Icons.storefront, salonName),
                      SizedBox(height: 6),
                      _buildOrderInfoRow(Icons.content_cut, serviceName),
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
                              '上传图片 ${retainedImages.length + images.length}/5',
                              style: TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                retainedImages.length + images.length >= 5
                                    ? null
                                    : pickImages,
                            icon: Icon(Icons.add_photo_alternate_outlined),
                            label: Text('选择图片'),
                          ),
                        ],
                      ),
                      if (retainedImages.isNotEmpty || images.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...retainedImages.map(
                              (image) => _buildExistingReviewImageTile(
                                image.value,
                                () => setSheetState(
                                    () => retainedImages.remove(image)),
                              ),
                            ),
                            ...images.map(
                              (image) => _buildPickedImageTile(
                                image,
                                () => setSheetState(() => images.remove(image)),
                              ),
                            ),
                          ],
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
                          label: Text(
                            isSubmitting
                                ? '提交中...'
                                : isEditing
                                    ? '提交修改'
                                    : '提交评价',
                          ),
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

              final picked = await ImagePicker().pickMultiImage(
                maxWidth: 1280,
                maxHeight: 1280,
              );
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
                _showSnackBar('投诉已提交');
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() => isSubmitting = false);
                await _showReviewSubmitError(sheetContext, e);
              }
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 10,
                  right: 10,
                  top: 9,
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
                                  () =>
                                      setSheetState(() => images.remove(image)),
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

  Widget _buildExistingReviewImageTile(String url, VoidCallback onRemove) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
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

  Future<void> _showReviewSubmitError(BuildContext context, Object error) {
    var message = '提交失败，请稍后重试';
    if (error is ReviewImageSizeException) {
      message = error.message;
    } else if (error is DioException) {
      final data = error.response?.data;
      if (error.response?.statusCode == 401) {
        message = '登录已失效，请退出后重新登录';
      } else if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        message = '图片上传超时，请检查网络后重试';
      }
    }
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('提交失败'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('知道了'),
          ),
        ],
      ),
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
    final displayName =
        UserSessionStore.currentSession?.user.displayName.trim() ?? '';
    final account = UserSessionStore.currentSession?.user.account ?? '';

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.accentBeige),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryPink.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 31,
                      backgroundColor: AppTheme.primaryPink.withOpacity(0.14),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? const Icon(
                              Icons.person,
                              color: AppTheme.primaryPink,
                              size: 32,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty
                              ? displayName
                              : account.isEmpty
                                  ? '未登录账号'
                                  : account,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 7),
                        TextButton.icon(
                          onPressed: () async {
                            await context.push(AppRouter.userProfile);
                            if (mounted) setState(() {});
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right, size: 15),
                          label: const Text('账号设置'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentBeige),
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppTheme.primaryPink.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '优惠券'),
                Tab(text: '我的评价'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              children: [
                _buildCouponsTab(),
                _buildMyReviewsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCoupons() async {
    if (UserSessionStore.currentSession == null) {
      if (mounted) {
        setState(() {
          _coupons = [];
          _couponsLoading = false;
          _couponsLoadFailed = false;
        });
      }
      return;
    }
    try {
      final coupons = await _authRepository.fetchCoupons();
      if (!mounted) return;
      setState(() {
        _coupons = coupons;
        _couponsLoading = false;
        _couponsLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _couponsLoading = false;
        _couponsLoadFailed = true;
      });
    }
  }

  Widget _buildCouponsTab() {
    if (_couponsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryPink),
      );
    }
    if (_couponsLoadFailed) return _buildRequestError(_loadCoupons);
    if (_coupons.isEmpty) {
      return _buildEmptyTab(
        Icons.confirmation_number_outlined,
        '暂无优惠券',
        '活动期间注册后，优惠券会显示在这里',
      );
    }
    return RefreshIndicator(
      color: AppTheme.primaryPink,
      onRefresh: _loadCoupons,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children:
            _coupons.map((coupon) => CouponTicket(coupon: coupon)).toList(),
      ),
    );
  }

  Widget _buildMyReviewsTab() {
    if (_myReviews.isEmpty) {
      return _buildEmptyTab(
        Icons.rate_review_outlined,
        '暂无评价',
        '完成服务并评价后会显示在这里',
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryPink,
      onRefresh: _loadMyReviews,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
        children: _myReviews.map(_buildMyReviewCard).toList(),
      ),
    );
  }

  Widget _buildMyReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final bookingId = review['bookingId']?.toString() ?? '';
    final reviewStatus = review['reviewStatus']?.toString() ?? '';
    final editStatus = review['editStatus']?.toString() ?? '';
    final isAwaitingReview =
        reviewStatus == 'pending' || editStatus == 'pending';
    final imageUrls = ((review['imageUrls'] as List?) ?? const [])
        .map((url) => url.toString())
        .where((url) => url.isNotEmpty)
        .toList();
    final reply = review['merchantReply'];
    final replyText = reply is Map
        ? reply['content']?.toString() ?? ''
        : reply?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentBeige),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review['salonName']?.toString() ?? '',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                review['date']?.toString() ?? '',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [review['serviceName'], review['staffName']]
                .map((value) => value?.toString() ?? '')
                .where((value) => value.isNotEmpty)
                .join(' · '),
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 18,
              ),
            ),
          ),
          if ((review['comment']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review['comment'].toString()),
          ],
          if (imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: imageUrls
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (replyText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.bgCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '商家回复：$replyText',
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bookingId.isEmpty || isAwaitingReview
                      ? null
                      : () => _showEditReviewSheet(review),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: Text(
                    editStatus == 'pending'
                        ? '修改审核中'
                        : reviewStatus == 'pending'
                            ? '评价审核中'
                            : '编辑',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryPink,
                    side: const BorderSide(color: AppTheme.primaryPink),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: bookingId.isEmpty
                      ? null
                      : () => _confirmDeleteReview(review),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('删除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteReview(Map<String, dynamic> review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('删除评价'),
        content: const Text('删除后无法恢复，确定要删除这条评价吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppTheme.white,
            ),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _reviewRepository.deleteReview(review['bookingId'].toString());
      await Future.wait([_loadMyReviews(), _loadBookingMessageStatus()]);
      if (mounted) _showSnackBar('评价已删除');
    } catch (error) {
      if (mounted) await _showReviewSubmitError(context, error);
    }
  }

  Widget _buildEmptyTab(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(14),
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

  Widget _buildRequestError(Future<void> Function() onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('糟糕，网络好像有点问题，请稍后重试'),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_none, color: AppTheme.white),
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
      padding: EdgeInsets.only(top: 24),
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
    return image;
  }

  Widget _buildSalonImage(
    Map<String, dynamic> salon, {
    double height = 180,
    double width = double.infinity,
    int memCacheWidth = 900,
  }) {
    final imageUrl = _salonCoverImageUrl(salon);
    if (imageUrl.isEmpty) {
      return AppImages.placeholder(width: width, height: height);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      memCacheWidth: memCacheWidth,
      filterQuality: FilterQuality.low,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => Container(
        height: height,
        width: width,
        color: Colors.grey[200],
      ),
      errorWidget: (context, url, error) => Container(
        height: height,
        width: width,
        color: Colors.grey,
        child: AppImages.placeholder(width: width, height: height),
      ),
    );
  }

  Widget _buildSalonCard(Map<String, dynamic> salon, BuildContext context) {
    final distanceLabel = _formatSalonDistance(salon);
    final salonId = salon['id'].toString();
    const cardHeight = 132.0;

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final imageWidth = (constraints.maxWidth * 0.45).clamp(150.0, 178.0);

          return GestureDetector(
            onTap: () => context.pushNamed(
              'salon_detail',
              pathParameters: {'id': salonId},
            ),
            child: Container(
              height: cardHeight,
              margin: EdgeInsets.only(bottom: 7),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.accentBeige.withOpacity(0.7)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: imageWidth,
                    child: _buildSalonImage(
                      salon,
                      height: cardHeight,
                      width: imageWidth,
                      memCacheWidth: 430,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(6, 8, 4, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  salon['name'] ?? '未知沙龙',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                '⭐ ${salon['rating']}',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 5),
                          Text(
                            salon['description'] ?? '暂无描述',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.05,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          Spacer(),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: distanceLabel == null
                                    ? SizedBox.shrink()
                                    : Text(
                                        distanceLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.primaryPink,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                              ValueListenableBuilder<
                                  List<Map<String, dynamic>>>(
                                valueListenable: FavoriteSalonStore.favorites,
                                builder: (context, favorites, _) {
                                  final isFavorite =
                                      FavoriteSalonStore.isFavorite(salonId);
                                  return IconButton(
                                    tooltip: isFavorite ? '取消收藏' : '收藏',
                                    onPressed: () async {
                                      try {
                                        await FavoriteSalonStore.toggle(salon);
                                      } catch (_) {
                                        if (!mounted) return;
                                        _showSnackBar('收藏操作失败，请稍后重试');
                                      }
                                    },
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      size: 23,
                                    ),
                                    color: isFavorite
                                        ? AppTheme.primaryPink
                                        : Colors.grey[700],
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 28,
                                      height: 24,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
