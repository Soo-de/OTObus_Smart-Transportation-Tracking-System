class OccupancyLog {
  final String date;
  final String time;
  final int timestamp;
  final int occupancy;
  final String density;

  OccupancyLog({
    required this.date,
    required this.time,
    required this.timestamp,
    required this.occupancy,
    required this.density,
  });

  // Firebase'den okuma için
  factory OccupancyLog.fromRTDB(Map<dynamic, dynamic> data) {
    return OccupancyLog(
      date: data['date'] ?? "",
      time: data['time'] ?? "",
      timestamp: data['timestamp'] ?? 0,
      occupancy: data['occupancy'] ?? 0,
      density: data['density'] ?? "Bilinmiyor",
    );
  }

  // FastAPI'ye göndermek için JSON formatı
  Map<String, dynamic> toJson() => {
        "date": date,
        "time": time,
        "timestamp": timestamp,
        "occupancy": occupancy,
        "density": density,
      };
}