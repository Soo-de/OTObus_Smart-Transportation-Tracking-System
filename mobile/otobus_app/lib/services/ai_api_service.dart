import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../models/occupancy_log.dart';

class AiApiService {
  // ⚠️ KENDİ BİLGİSAYARINIZIN IP ADRESİNİ GİRİN
  // Terminal'de: ipconfig (Windows) veya ifconfig (Mac/Linux)
  // Örnek: "http://192.168.1.100:8000/daily-summary"
  static const String _apiHost = "172.20.10.3"; // BU IP'Yİ DEĞİŞTİRİN
  static const int _apiPort = 8000;
  
  final String apiUrl = "http://$_apiHost:$_apiPort/daily-summary";

  // Artık dışarıdan 'selectedDate' (Örn: "2025-12-17") alıyor
  Future<Map<String, dynamic>> fetchAndAnalyze(String selectedDate) async {
    try {
      // 1. Firebase'den SADECE seçilen tarihe ait verileri filtreleyerek çek
      // .orderByChild('date') ve .equalTo(selectedDate) kullanarak sorgu yapıyoruz
      final query = FirebaseDatabase.instance
          .ref('logs') // Veritabanı yolunun 'logs' olduğundan emin ol
          .orderByChild('date')
          .equalTo(selectedDate);

      final snapshot = await query.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        throw "Seçilen tarihe ($selectedDate) ait herhangi bir veri bulunamadı.";
      }

      List<OccupancyLog> logs = [];
      final data = snapshot.value as Map<dynamic, dynamic>;
      
      data.forEach((key, value) {
        logs.add(OccupancyLog.fromRTDB(value));
      });

      // 2. Filtrelenmiş listeyi FastAPI'ye gönder
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(logs.map((e) => e.toJson()).toList()),
      );

      // 3. Yanıtı Kontrol Et
      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        print("Sunucu Hata Kodu: ${response.statusCode}");
        throw "Sunucu Hatası: ${response.statusCode}";
      }
    } catch (e) {
      print("İşlem Hatası: $e");
      // Hata mesajını kullanıcıya göstermek üzere fırlatıyoruz
      throw e.toString();
    }
  }
}