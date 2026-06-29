import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
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

class SalonHomeScreen extends StatefulWidget {
  const SalonHomeScreen({super.key});

  @override
  State<SalonHomeScreen> createState() => _SalonHomeScreenState();
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
  final TextEditingController _profileNameController = TextEditingController();
  final TextEditingController _profilePhoneController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  OverlayEntry? _searchSuggestionsOverlay;
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  bool _hasBookingMessages = false;
  String? _latestBookingMessageKey;
  List<Map<String, dynamic>> _salons = [];
  int _visibleSalonCount = _salonPageSize;
  bool _salonsLoadedWithPosition = false;
  List<BookingOrder> _bookingOrders = [];
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

    return source;
  }

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChanged);
    _syncProfileControllers();
    _restoreCachedLocation();
    if (_userPosition != null) _loadSalons();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateUserOnceOnOpen();
    });
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
    _searchSuggestionDebounce?.cancel();
    _removeSearchSuggestionsOverlay();
    _searchFocusNode.dispose();
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
      _cachedUserPosition = null;
      _cachedLocationMessage = '定位失败，请开启定位后查看附近店铺';
      if (!mounted) return;
      setState(() {
        _locationMessage = '定位失败，请开启定位后查看附近店铺';
        _isLoading = false;
        _salons = [];
        _salonsLoadedWithPosition = false;
      });
      if (showFailureSnackBar) _showSnackBar(error.toString());
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
    } catch (e) {
      if (!mounted || requestId != _salonRequestId) return;
      setState(() {
        _errorMessage = e.toString();
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
    if (index != 0) {
      _removeSearchSuggestionsOverlay();
      _searchFocusNode.unfocus();
    }

    if (index == 2) {
      unawaited(BookingMessageReadStore.markRead(_latestBookingMessageKey));
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
    final titles = ['', '收藏', '我的订单', '我'];

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
            label: '我',
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab(List<Map<String, dynamic>> filteredSalons) {
    final visibleSalons = filteredSalons.take(_visibleSalonCount).toList();
    final headerCount =
        _isLoading || _errorMessage.isNotEmpty || visibleSalons.isEmpty ? 1 : 0;
    final itemCount = 2 + headerCount + visibleSalons.length;

    return Column(
      children: [
        Expanded(
          child: NotificationListener<ScrollEndNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter == 0 &&
                  _visibleSalonCount < filteredSalons.length) {
                setState(() => _visibleSalonCount += _salonPageSize);
              }
              return false;
            },
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(10, 10, 10, 14),
              cacheExtent: 420,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(_salonsLoadedWithPosition ? '附近的店铺' : '推荐沙龙',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark));
                }
                if (index == 1) return SizedBox(height: 15);

                final contentIndex = index - 2;
                if (_isLoading) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryPink));
                }
                if (_errorMessage.isNotEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Text('加载失败: $_errorMessage',
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
                _showSnackBar('评价晒单已提交');
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
                _showSnackBar('投诉已提交');
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
      padding: EdgeInsets.fromLTRB(10, 14, 10, 56),
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
                        padding: EdgeInsets.all(4.5),
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
            padding: EdgeInsets.all(9),
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
