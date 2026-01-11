// lib/models/current_data.dart

class CurrentData {
  final int co2; // Karbon Dioksit (PPM)
  final double humidity; // Nem (%)
  final double temperature; // Sıcaklık (°C)
  final int vocQuality; // Hava Kalitesi (VOC Index)
  final int lastUpdate; // Son güncelleme zamanı (Epoch/Milisaniye)

  CurrentData({
    required this.co2,
    required this.humidity,
    required this.temperature,
    required this.vocQuality,
    required this.lastUpdate,
  });

  // Firebase'den gelen Map verisini Dart nesnesine çeviren fabrika
  factory CurrentData.fromRTDB(Map<dynamic, dynamic> data) {
    return CurrentData(
      co2: (data['co2'] as int?) ?? 0,
      humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      vocQuality: (data['voc_quality'] as int?) ?? 0,
      lastUpdate: (data['last_update'] as int?) ?? 0,
    );
  }

  // Boş veya başlangıç verisi (Ekran açıldığında hata vermemesi için)
  static CurrentData empty() {
    return CurrentData(
      co2: 0,
      humidity: 0.0,
      temperature: 0.0,
      vocQuality: 0,
      lastUpdate: 0,
    );
  }
}
