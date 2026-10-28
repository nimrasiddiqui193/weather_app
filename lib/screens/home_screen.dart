import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/weather.dart';
import '../models/forecast.dart';
import '../services/weather_service.dart';
import '../services/recent_search_service.dart';
import '../secrets.dart';
import 'hourly_forecast_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onThemeToggle;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeToggle,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _CitySuggestion {
  final String name;
  final String? state;
  final String country;

  const _CitySuggestion({
    required this.name,
    required this.country,
    this.state,
  });

  factory _CitySuggestion.fromJson(Map<String, dynamic> json) {
    return _CitySuggestion(
      name: json['name'] as String? ?? '',
      state: json['state'] as String?,
      country: json['country'] as String? ?? '',
    );
  }

  String get searchQuery => '$name,$country';
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _service = WeatherService();
  final _focusNode = FocusNode();
  final _recentSearchService = RecentSearchService();

  Timer? _suggestionTimer;

  Weather? _weather;
  List<ForecastDay> _forecast = [];
  List<_CitySuggestion> _suggestions = [];
  List<String> _recentCities = [];

  bool _isLoading = false;
  bool _isLoadingForecast = false;
  bool _isLoadingSuggestions = false;
  bool _showSuggestions = false;
  bool _useFahrenheit = false;

  String? _error;
  int _requestId = 0;

  static const Color _primaryBlue = Color(0xFF246BFD);
  static const Color _textDark = Color(0xFF172B4D);
  static const Color _textMuted = Color(0xFF718096);

  bool get _isDark => widget.isDarkMode;

  Color get _background =>
      _isDark ? const Color(0xFF101827) : const Color(0xFFF0F6FF);

  Color get _surface => _isDark ? const Color(0xFF1C293B) : Colors.white;

  Color get _textPrimary => _isDark ? const Color(0xFFE8EEF8) : _textDark;

  Color get _textSecondary => _isDark ? const Color(0xFFB0BDD0) : _textMuted;

  Color get _softBlue =>
      _isDark ? const Color(0xFF263B57) : const Color(0xFFEAF2FF);

  Color get _borderColor =>
      _isDark ? const Color(0xFF34445A) : const Color(0xFFDCE8FA);

  double _displayTemperature(double celsius) {
    return _useFahrenheit ? (celsius * 9 / 5) + 32 : celsius;
  }

  String _temperatureLabel(double celsius) {
    final temperature = _displayTemperature(celsius).round();
    final unit = _useFahrenheit ? 'F' : 'C';
    return '$temperature°$unit';
  }

  void _setTemperatureUnit(bool useFahrenheit) {
    if (_useFahrenheit == useFahrenheit) return;
    setState(() => _useFahrenheit = useFahrenheit);
  }

  @override
  void initState() {
    super.initState();
    _loadRecentCities();
  }

  Future<void> _loadRecentCities() async {
    try {
      final cities = await _recentSearchService.getRecentCities();
      if (!mounted) return;
      setState(() => _recentCities = cities);
    } catch (_) {
      // Weather search remains available if local storage fails.
    }
  }

  Future<void> _saveRecentCity(String city) async {
    try {
      await _recentSearchService.saveCity(city);
      await _loadRecentCities();
    } catch (_) {
      // Do not interrupt weather results if saving fails.
    }
  }

  Future<void> _removeRecentCity(String city) async {
    try {
      await _recentSearchService.removeCity(city);
      await _loadRecentCities();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove this recent search.')),
      );
    }
  }

  Future<void> _clearRecentCities() async {
    try {
      await _recentSearchService.clearRecentCities();
      if (!mounted) return;

      setState(() => _recentCities = []);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recent searches cleared.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear recent searches.')),
      );
    }
  }

  Future<void> _searchRecentCity(String city) async {
    _suggestionTimer?.cancel();

    setState(() {
      _controller.text = city;
      _suggestions = [];
      _showSuggestions = false;
      _isLoadingSuggestions = false;
    });

    await _search();
  }

  @override
  void dispose() {
    _suggestionTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCityChanged(String value) {
    _suggestionTimer?.cancel();

    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _showSuggestions = true;
      _isLoadingSuggestions = true;
      _suggestions = [];
    });

    _suggestionTimer = Timer(
      const Duration(milliseconds: 300),
      () => _fetchCitySuggestions(value.trim()),
    );
  }

  Future<void> _fetchCitySuggestions(String query) async {
    try {
      final uri = Uri.https('api.openweathermap.org', '/geo/1.0/direct', {
        'q': query,
        'limit': '6',
        'appid': weatherApiKey,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 7));

      if (!mounted || _controller.text.trim() != query) return;

      if (response.statusCode == 200) {
        final List<dynamic> results =
            jsonDecode(response.body) as List<dynamic>;

        final suggestions =
            results
                .whereType<Map<String, dynamic>>()
                .map(_CitySuggestion.fromJson)
                .where((city) => city.name.isNotEmpty)
                .toList();

        setState(() {
          _suggestions = suggestions;
          _isLoadingSuggestions = false;
          _showSuggestions = true;
        });
      } else {
        setState(() {
          _suggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    } catch (_) {
      if (!mounted || _controller.text.trim() != query) return;

      setState(() {
        _suggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  Future<void> _selectCity(_CitySuggestion city) async {
    _suggestionTimer?.cancel();

    setState(() {
      _controller.text = city.searchQuery;
      _suggestions = [];
      _showSuggestions = false;
      _isLoadingSuggestions = false;
    });

    await _search();
  }

  Future<void> _search() async {
    final city = _controller.text.trim();

    if (city.isEmpty) {
      setState(() {
        _error = 'Please enter a city name.';
        _weather = null;
        _forecast = [];
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingForecast = false;
      });
      return;
    }

    _suggestionTimer?.cancel();
    FocusScope.of(context).unfocus();

    final requestId = ++_requestId;

    setState(() {
      _isLoading = true;
      _isLoadingForecast = false;
      _error = null;
      _forecast = [];
      _suggestions = [];
      _showSuggestions = false;
      _isLoadingSuggestions = false;
    });

    try {
      final weather = await _service.fetchWeather(city);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _weather = weather;
        _controller.text = weather.city;
        _isLoading = false;
        _isLoadingForecast = true;
      });

      unawaited(_saveRecentCity(weather.city));
      unawaited(_loadForecast(weather.city, requestId));
    } catch (e) {
      if (!mounted || requestId != _requestId) return;

      final message = e.toString();

      setState(() {
        _weather = null;
        _forecast = [];
        _isLoading = false;
        _isLoadingForecast = false;
        _error =
            message.startsWith('Exception: ')
                ? message.replaceFirst('Exception: ', '')
                : 'Could not load weather. Check your internet connection.';
      });
    }
  }

  Future<void> _loadForecast(String city, int requestId) async {
    try {
      final forecast = await _service.fetchForecast(city);

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _forecast = forecast;
        _isLoadingForecast = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _forecast = [];
        _isLoadingForecast = false;
      });
    }
  }

  Widget _buildHourlyForecastButton() {
    if (_weather == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: OutlinedButton.icon(
        onPressed: () {
          final city = _weather!.city;

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => HourlyForecastScreen(
                    city: city,
                    useFahrenheit: _useFahrenheit,
                    onTemperatureUnitChanged: _setTemperatureUnit,
                    onThemeToggle: widget.onThemeToggle,
                  ),
            ),
          );
        },
        icon: const Icon(Icons.schedule_rounded),
        label: const Text('View 3-Hour Forecast'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _isDark ? const Color(0xFF8DB8FF) : _primaryBlue,
          side: BorderSide(
            color: _isDark ? const Color(0xFF49658B) : const Color(0xFFC7D9F8),
          ),
          backgroundColor: _surface,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _weatherIcon(String iconCode, {double size = 100}) {
    return WeatherIllustration(iconCode: iconCode, size: size);
  }

  Widget _buildUnitToggle() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption(
            label: '°C',
            selected: !_useFahrenheit,
            onTap: () => _setTemperatureUnit(false),
          ),
          _buildUnitOption(
            label: '°F',
            selected: _useFahrenheit,
            onTap: () => _setTemperatureUnit(true),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentCities.isEmpty ||
        _controller.text.trim().isNotEmpty ||
        _showSuggestions) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: _primaryBlue, size: 21),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent searches',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearRecentCities,
                style: TextButton.styleFrom(
                  foregroundColor:
                      _isDark ? const Color(0xFF8DB8FF) : _primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Clear all', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._recentCities.map(
            (city) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: _primaryBlue,
                  size: 21,
                ),
              ),
              title: Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Remove $city',
                onPressed: () => _removeRecentCity(city),
                icon: Icon(
                  Icons.close_rounded,
                  color: _textSecondary,
                  size: 19,
                ),
              ),
              onTap: () => _searchRecentCity(city),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitySuggestions() {
    if (!_showSuggestions) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.14 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          _isLoadingSuggestions
              ? Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Finding cities...',
                      style: TextStyle(color: _textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              )
              : _suggestions.isEmpty
              ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No matching cities found. Try another spelling.',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
              )
              : Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    _suggestions.map((city) {
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _softBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.location_city_rounded,
                            color: _primaryBlue,
                          ),
                        ),
                        title: Text(
                          city.name,
                          style: TextStyle(
                            color: _textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          [
                            if (city.state != null && city.state!.isNotEmpty)
                              city.state!,
                            city.country,
                          ].join(', '),
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(
                          Icons.north_west_rounded,
                          size: 17,
                          color: _textSecondary,
                        ),
                        onTap: () => _selectCity(city),
                      );
                    }).toList(),
              ),
    );
  }

  Widget _buildWeatherStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 23),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResult() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primaryBlue),
            const SizedBox(height: 16),
            Text(
              'Checking the weather...',
              style: TextStyle(color: _textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF3A242B) : Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: _isDark ? Colors.red.shade200 : Colors.red.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isDark ? Colors.red.shade100 : Colors.red.shade700,
                fontSize: 15,
              ),
            ),
            TextButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_weather == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WeatherIllustration(iconCode: '02d', size: 100),
            const SizedBox(height: 16),
            Text(
              'How is the weather?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a city to see its current weather and five-day forecast.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    final w = _weather!;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Container(
        key: ValueKey('${w.city}_${w.temp}_$_useFahrenheit'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF75B8FF), Color(0xFF4789F5), Color(0xFF3565DC)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 21,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    w.city,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _weatherIcon(w.iconCode, size: 128),
            Text(
              _temperatureLabel(w.temp),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w300,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              w.description.isEmpty
                  ? 'Weather unavailable'
                  : '${w.description[0].toUpperCase()}${w.description.substring(1)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildWeatherStat(
                    icon: Icons.water_drop_rounded,
                    label: 'Humidity',
                    value: '${w.humidity}%',
                  ),
                ),
                Container(height: 45, width: 1, color: Colors.white38),
                Expanded(
                  child: _buildWeatherStat(
                    icon: Icons.air_rounded,
                    label: 'Wind speed',
                    value: '${w.windSpeed.toStringAsFixed(1)} m/s',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // New section: feels-like temperature, humidity, wind, pressure,
  // visibility, sunrise and sunset.
  Widget _buildAdditionalWeatherDetails() {
    final weather = _weather;

    if (weather == null || _isLoading) {
      return const SizedBox.shrink();
    }

    final details = [
      (
        icon: Icons.thermostat_rounded,
        label: 'Feels like',
        value: _temperatureLabel(weather.feelsLike),
      ),
      (
        icon: Icons.water_drop_rounded,
        label: 'Humidity',
        value: '${weather.humidity}%',
      ),
      (
        icon: Icons.air_rounded,
        label: 'Wind speed',
        value: '${weather.windSpeed.toStringAsFixed(1)} m/s',
      ),
      (
        icon: Icons.speed_rounded,
        label: 'Pressure',
        value: '${weather.pressure} hPa',
      ),
      (
        icon: Icons.visibility_rounded,
        label: 'Visibility',
        value: '${weather.visibilityKm.toStringAsFixed(1)} km',
      ),
      (
        icon: Icons.wb_twilight_rounded,
        label: 'Sunrise',
        value: weather.sunrise,
      ),
      (icon: Icons.wb_sunny_outlined, label: 'Sunset', value: weather.sunset),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weather Details',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'More information about ${weather.city}',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: details.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 100,
            ),
            itemBuilder: (context, index) {
              final detail = details[index];

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(detail.icon, color: _primaryBlue, size: 19),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            detail.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      detail.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForecast() {
    if (_weather == null) return const SizedBox.shrink();

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Text(
          '5-Day Forecast',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'A little look at the days ahead',
          style: TextStyle(fontSize: 14, color: _textSecondary),
        ),
        const SizedBox(height: 14),
        if (_isLoadingForecast)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading forecast...',
                  style: TextStyle(color: _textSecondary, fontSize: 14),
                ),
              ],
            ),
          )
        else if (_forecast.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'The forecast is unavailable right now. Current weather is still available.',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children:
                  _forecast.asMap().entries.map((entry) {
                    final index = entry.key;
                    final day = entry.value;
                    final date = day.date;
                    final weekday = dayNames[date.weekday - 1];

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border:
                            index == _forecast.length - 1
                                ? null
                                : Border(
                                  bottom: BorderSide(
                                    color: _borderColor,
                                    width: 0.7,
                                  ),
                                ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              index == 0 ? 'Today' : weekday,
                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 48,
                            height: 42,
                            child: WeatherIllustration(
                              iconCode: day.iconCode,
                              size: 42,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              day.description.isEmpty
                                  ? 'Weather'
                                  : '${day.description[0].toUpperCase()}${day.description.substring(1)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _temperatureLabel(day.temp),
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF75B8FF), Color(0xFF3565DC)],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.cloud_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 11),
            Text(
              'Weatherly',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: widget.onThemeToggle,
            icon: Icon(
              _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _isDark ? const Color(0xFFFFD166) : _primaryBlue,
            ),
          ),
          _buildUnitToggle(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weather at a glance',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Find current conditions and the forecast for any city.',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDark ? 0.10 : 0.035,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(Icons.search_rounded, color: _textSecondary, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onCityChanged,
                        onSubmitted: (_) => _search(),
                        textInputAction: TextInputAction.search,
                        style: TextStyle(color: _textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Enter city name...',
                          hintStyle: TextStyle(
                            color: _textSecondary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _suggestionTimer?.cancel();
                          setState(() {
                            _controller.clear();
                            _suggestions = [];
                            _showSuggestions = false;
                            _isLoadingSuggestions = false;
                            _error = null;
                          });
                          _focusNode.requestFocus();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: _textSecondary,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 3),
                    Material(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: _search,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _buildCitySuggestions(),
              _buildRecentSearches(),
              _buildResult(),
              _buildAdditionalWeatherDetails(),
              _buildHourlyForecastButton(),
              _buildForecast(),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Weatherly  •  Your weather, simplified',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom weather illustrations used by the weather cards.
class WeatherIllustration extends StatelessWidget {
  final String iconCode;
  final double size;

  const WeatherIllustration({
    super.key,
    required this.iconCode,
    this.size = 100,
  });

  @override
  Widget build(BuildContext context) {
    final isNight = iconCode.endsWith('n');
    final condition = iconCode.length >= 2 ? iconCode.substring(0, 2) : '01';

    switch (condition) {
      case '01':
        return _sunny(isNight);
      case '02':
        return _partlyCloudy(isNight);
      case '03':
      case '04':
        return _cloudy();
      case '09':
      case '10':
        return _rainy();
      case '11':
        return _stormy();
      case '13':
        return _snowy();
      case '50':
        return _foggy();
      default:
        return _partlyCloudy(isNight);
    }
  }

  Widget _sunny(bool isNight) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isNight)
            Icon(
              Icons.nightlight_round,
              size: size * 0.75,
              color: const Color(0xFFFFD166),
            )
          else ...[
            ...List.generate(8, (index) {
              final angle = index * 3.1415926535 / 4;
              return Transform.translate(
                offset: Offset(
                  size * 0.32 * _cos(angle),
                  size * 0.32 * _sin(angle),
                ),
                child: Container(
                  width: size * 0.045,
                  height: size * 0.14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
            Container(
              width: size * 0.46,
              height: size * 0.46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE082), Color(0xFFFFA726)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _partlyCloudy(bool isNight) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.08,
            right: size * 0.08,
            child: Icon(
              isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              color:
                  isNight ? const Color(0xFFFFD166) : const Color(0xFFFFC857),
              size: size * 0.43,
            ),
          ),
          Positioned(
            left: size * 0.02,
            bottom: size * 0.14,
            child: Icon(
              Icons.cloud_rounded,
              color: const Color(0xFFEAF4FF),
              size: size * 0.83,
              shadows: const [
                Shadow(
                  color: Color(0x223565DC),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloudy() {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.18,
            right: size * 0.08,
            child: Icon(
              Icons.cloud_rounded,
              size: size * 0.65,
              color: const Color(0xFFB8D4F5),
            ),
          ),
          Positioned(
            left: size * 0.02,
            bottom: size * 0.10,
            child: Icon(
              Icons.cloud_rounded,
              size: size * 0.86,
              color: const Color(0xFFEAF4FF),
              shadows: const [
                Shadow(
                  color: Color(0x223565DC),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rainy() {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.02,
            child: Icon(
              Icons.cloud_rounded,
              size: size * 0.80,
              color: const Color(0xFFB8D4F5),
            ),
          ),
          ...List.generate(4, (index) {
            return Positioned(
              left: size * (0.20 + index * 0.17),
              bottom: size * 0.03,
              child: Transform.rotate(
                angle: -0.3,
                child: Container(
                  width: size * 0.055,
                  height: size * 0.21,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4789F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stormy() {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.02,
            child: Icon(
              Icons.cloud_rounded,
              size: size * 0.80,
              color: const Color(0xFF8297B8),
            ),
          ),
          Positioned(
            bottom: size * 0.02,
            child: Icon(
              Icons.bolt_rounded,
              size: size * 0.50,
              color: const Color(0xFFFFC857),
            ),
          ),
        ],
      ),
    );
  }

  Widget _snowy() {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.02,
            child: Icon(
              Icons.cloud_rounded,
              size: size * 0.80,
              color: const Color(0xFFB8D4F5),
            ),
          ),
          ...List.generate(4, (index) {
            return Positioned(
              left: size * (0.15 + index * 0.19),
              bottom: size * 0.03,
              child: Icon(
                Icons.ac_unit_rounded,
                size: size * 0.15,
                color: const Color(0xFF4789F5),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _foggy() {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.cloud_rounded,
            size: size * 0.78,
            color: const Color(0xFFB8D4F5),
          ),
          Positioned(
            bottom: size * 0.17,
            child: Container(
              width: size * 0.75,
              height: size * 0.045,
              decoration: BoxDecoration(
                color: const Color(0xFF8297B8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned(
            bottom: size * 0.06,
            child: Container(
              width: size * 0.60,
              height: size * 0.045,
              decoration: BoxDecoration(
                color: const Color(0xFF8297B8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _sin(double angle) => _trig(angle, true);

  double _cos(double angle) => _trig(angle, false);

  double _trig(double angle, bool sine) {
    if (sine) {
      if (angle == 0) return 0;
      if (angle == 3.1415926535 / 2) return 1;
      if (angle == 3.1415926535) return 0;
      if (angle == 3 * 3.1415926535 / 2) return -1;
    } else {
      if (angle == 0) return 1;
      if (angle == 3.1415926535 / 2) return 0;
      if (angle == 3.1415926535) return -1;
      if (angle == 3 * 3.1415926535 / 2) return 0;
    }

    return sine ? _approximateSin(angle) : _approximateCos(angle);
  }

  double _approximateSin(double angle) {
    final x = angle % (2 * 3.1415926535);
    final sign = x > 3.1415926535 ? -1.0 : 1.0;
    final a = x > 3.1415926535 ? x - 3.1415926535 : x;

    return sign * (4 * a * (3.1415926535 - a)) / (3.1415926535 * 3.1415926535);
  }

  double _approximateCos(double angle) {
    return _approximateSin(angle + 3.1415926535 / 2);
  }
}
