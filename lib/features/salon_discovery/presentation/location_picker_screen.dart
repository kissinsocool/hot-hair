import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/location_position_service.dart';
import '../data/location_reverse_geocode_repository.dart';
import 'location_address_formatter.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    required this.currentAddress,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String currentAddress;
  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final LocationReverseGeocodeRepository _locationRepository =
      LocationReverseGeocodeRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _isLocating = false;
  bool _isSearching = false;
  late String _selectedAddress = _cleanAddress(widget.currentAddress);
  String _addressSearchError = '';
  String _lastSuccessfulAddressKeyword = '';
  Position? _selectedPosition;
  List<Map<String, dynamic>> _addressSuggestions = [];
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    if (latitude != null && longitude != null) {
      _selectedPosition = _positionFromCoordinates(latitude, longitude);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String _cleanAddress(String value) {
    final text = value.trim();
    return text.startsWith('定位到：') ? text.substring(4).trim() : text;
  }

  Future<void> _relocate() async {
    setState(() => _isLocating = true);
    try {
      final position = await LocationPositionService.currentPosition();
      final address = await _formatPositionAddress(position);

      if (!mounted) return;
      _setSelectedPosition(position, address);
      context.pop({
        'address': address,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<String> _formatPositionAddress(Position position) async {
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
      if (placemarks.isNotEmpty) {
        final address = formatPlacemarkAddress(placemarks.first);
        if (address.isNotEmpty) return address;
      }
    } catch (_) {
      // The coordinate is still useful even when reverse geocoding is unavailable.
    }

    return '当前位置 (${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)})';
  }

  void _scheduleAddressSearch(String value) {
    _searchDebounce?.cancel();
    final keyword = value.trim();

    if (keyword.isEmpty) {
      setState(() {
        _isSearching = false;
        _addressSuggestions = [];
        _addressSearchError = '';
        _lastSuccessfulAddressKeyword = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _addressSearchError = '';
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadAddressSuggestions(keyword),
    );
  }

  Future<void> _loadAddressSuggestions(String keyword) async {
    final requestId = ++_searchRequestId;

    try {
      final suggestions = await _locationRepository.fetchAddressSuggestions(
        keyword: keyword,
        latitude: _selectedPosition?.latitude ?? widget.initialLatitude,
        longitude: _selectedPosition?.longitude ?? widget.initialLongitude,
      );
      if (!mounted || requestId != _searchRequestId) return;
      if (_searchController.text.trim() != keyword) return;

      setState(() {
        _addressSuggestions = suggestions;
        _lastSuccessfulAddressKeyword = keyword;
        _addressSearchError = '';
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) return;
      if (_searchController.text.trim() != keyword) return;

      setState(() {
        if (_lastSuccessfulAddressKeyword != keyword) {
          _addressSuggestions = [];
        }
        _addressSearchError = '搜索失败，请重试';
        _isSearching = false;
      });
    }
  }

  void _selectAddressSuggestion(Map<String, dynamic> suggestion) {
    final address = _suggestionSelectedAddress(suggestion);
    if (address.isEmpty) return;

    final latitude = double.tryParse(suggestion['latitude']?.toString() ?? '');
    final longitude =
        double.tryParse(suggestion['longitude']?.toString() ?? '');

    if (latitude != null && longitude != null) {
      final position = _positionFromCoordinates(latitude, longitude);
      _setSelectedPosition(position, address);
    }

    context.pop({
      'address': address,
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': 0,
      },
    });
  }

  void _setSelectedPosition(Position position, String address) {
    setState(() {
      _selectedPosition = position;
      _selectedAddress = formatLocationLeafAddress(address);
    });
  }

  Position _positionFromCoordinates(double latitude, double longitude) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  void _finish() {
    context.pop({
      'address': _selectedAddress,
      if (_selectedPosition != null) ...{
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        'accuracy': _selectedPosition!.accuracy,
      },
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 62,
              color: AppTheme.white,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: '返回',
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppTheme.textDark,
                        size: 24,
                      ),
                    ),
                  ),
                  const Text(
                    '选择地址',
                    style: TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Offstage(
              offstage: true,
              child: TextField(
                controller: _searchController,
                onChanged: _scheduleAddressSearch,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
                children: [
                  if (_searchController.text.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          '搜索结果',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                        if (_isSearching) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_isSearching && _addressSearchError.isNotEmpty)
                      Text(
                        _addressSearchError,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      )
                    else if (!_isSearching && _addressSuggestions.isEmpty)
                      Text(
                        '暂无匹配地址',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      )
                    else
                      ..._addressSuggestions.map(_buildAddressSuggestionItem),
                    const SizedBox(height: 22),
                  ],
                  Text(
                    '当前选择',
                    style: TextStyle(color: Colors.grey[600], fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentBeige),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _finish,
                            child: Text(
                              _selectedAddress.isEmpty
                                  ? '暂未获取地址'
                                  : _selectedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: _isLocating ? null : _relocate,
                          icon: _isLocating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryPink,
                                  ),
                                )
                              : const Icon(Icons.my_location, size: 20),
                          label: Text(_isLocating ? '定位中' : '重定位'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryPink,
                            backgroundColor:
                                AppTheme.primaryPink.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }

  Widget _buildAddressSuggestionItem(Map<String, dynamic> suggestion) {
    final title = _suggestionTitle(suggestion);
    final subtitle = _suggestionSubtitle(suggestion);

    return InkWell(
      onTap: () => _selectAddressSuggestion(suggestion),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accentBeige),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppTheme.primaryPink,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? subtitle : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty && subtitle != title) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _suggestionTitle(Map<String, dynamic> suggestion) {
    for (final key in [
      'name',
      'title',
      'poiName',
      'placeName',
      'addressName',
      'companyName',
      'enterpriseName',
      'businessName',
      'buildingName',
      'communityName',
      'residentialName',
      'estateName',
      'villageName',
      'neighborhoodName',
      'address',
      'displayAddress',
      'formattedAddress',
      'standardAddress',
    ]) {
      final value = suggestion[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _suggestionSubtitle(Map<String, dynamic> suggestion) {
    final address = (suggestion['address'] ??
            suggestion['displayAddress'] ??
            suggestion['formattedAddress'] ??
            '')
        .toString()
        .trim();
    final district = (suggestion['district'] ?? suggestion['adname'] ?? '')
        .toString()
        .trim();
    final city = suggestion['city']?.toString().trim() ?? '';

    if (address.isNotEmpty) {
      final prefix = [city, district]
          .where((part) => part.isNotEmpty && !address.contains(part))
          .join('');
      return '$prefix$address';
    }

    return [city, district].where((part) => part.isNotEmpty).join('');
  }

  String _suggestionSelectedAddress(Map<String, dynamic> suggestion) {
    final title = _suggestionTitle(suggestion);
    final subtitle = _suggestionSubtitle(suggestion);
    if (title.isEmpty) return subtitle;
    if (subtitle.isEmpty || subtitle == title) return title;
    return '$title $subtitle';
  }
}
