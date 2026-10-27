import 'package:flutter/material.dart';
import '../models/weather.dart';
import '../models/forecast.dart';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _service = WeatherService();

  Weather? _weather;
  List<ForecastDay> _forecast = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final city = _controller.text.trim();
    if (city.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _forecast = [];
    });

    try {
      final weather = await _service.fetchWeather(city);
      final forecast = await _service.fetchForecast(city);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _forecast = forecast;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      setState(() {
        _weather = null;
        _forecast = [];
        _error =
            msg.startsWith('Exception: ')
                ? msg.replaceFirst('Exception: ', '')
                : 'Could not load weather. Check your internet.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildResult() {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    if (_error != null) {
      return Text(
        _error!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.red, fontSize: 16),
      );
    }
    if (_weather == null) {
      return const Text('Search for a city to see its weather');
    }

    final w = _weather!;
    return Column(
      children: [
        Text(
          w.city,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('${w.temp.round()}°C', style: const TextStyle(fontSize: 64)),
        Text(w.description, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Icon(Icons.water_drop),
                Text('${w.humidity}%'),
                const Text('Humidity'),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.air),
                Text('${w.windSpeed} m/s'),
                const Text('Wind'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForecast() {
    if (_forecast.isEmpty) return const SizedBox.shrink();

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          '5-Day Forecast',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._forecast.map(
          (f) => Card(
            child: ListTile(
              leading: Text(
                dayNames[f.date.weekday - 1],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              title: Text(f.description),
              trailing: Text(
                '${f.temp.round()}°C',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Enter city name',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _search,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildResult(),
              _buildForecast(),
            ],
          ),
        ),
      ),
    );
  }
}
