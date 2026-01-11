// lib/models/historical_data.dart

class HistoricalData {
  final String id;
  final int co2;
  final double humidity;
  final double temperature;
  final int vocQuality;
  final int timestamp;
  final String readableTime; 

  HistoricalData({
    required this.id,
    required this.co2,
    required this.humidity,
    required this.temperature,
    required this.vocQuality,
    required this.timestamp,
    required this.readableTime,
  });

  factory HistoricalData.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return HistoricalData(
      id: key,
      co2: (data['co2'] as num?)?.toInt() ?? 0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      vocQuality: (data['voc_quality'] as num?)?.toInt() ?? 0,
      timestamp: (data['timestamp'] as int?) ?? 0,
      
      // Eğer null gelirse boş string '' atıyoruz ki hata vermesin.
      readableTime: data['readable_time']?.toString() ?? '', 
    );
  }
}