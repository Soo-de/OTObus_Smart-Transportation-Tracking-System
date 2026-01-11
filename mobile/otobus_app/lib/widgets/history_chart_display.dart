import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../models/environment_history_data.dart';

class HistoryChartDisplay extends StatefulWidget {
  const HistoryChartDisplay({super.key});

  @override
  State<HistoryChartDisplay> createState() => _HistoryChartDisplayState();
}

class _HistoryChartDisplayState extends State<HistoryChartDisplay> {
  // Geçmiş Veri Yolu
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'home/environment_history',
  );
  String _selectedChart = 'temperature'; // Varsayılan

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Geçmiş Veriler (Son 20)",
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // 1. Grafik Seçici Butonlar
        _buildChartSelector(),

        // 2. Grafik Veri Akışı (Bar Chart)
        _buildHistoryDataStream(),
      ],
    );
  }

  // --- Buton Alanı ---
  Widget _buildChartSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPillButton('Sıcaklık', 'temperature'),
          _buildPillButton('CO2', 'co2'),
          _buildPillButton('Nem', 'humidity'),
          _buildPillButton('Hava Kalitesi', 'voc_quality'),
        ],
      ),
    );
  }

  Widget _buildPillButton(String text, String key) {
    final bool isSelected = _selectedChart == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(
          text,
          style: TextStyle(color: isSelected ? Colors.white : kPrimaryColor),
        ),
        onPressed: () => setState(() => _selectedChart = key),
        backgroundColor: isSelected ? kPrimaryColor : Colors.white,
        side: BorderSide(color: kPrimaryColor.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 1,
      ),
    );
  }

  // --- Veri Çekme ---
  Widget _buildHistoryDataStream() {
    // Sütun grafikte barların kalın ve okunabilir olması için son 20 veri idealdir.
    return StreamBuilder<DatabaseEvent>(
      stream: _historyRef.limitToLast(20).onValue, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }

        final dataValue = snapshot.data?.snapshot.value;
        if (dataValue == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text("Grafik için veri bulunamadı.")),
          );
        }

        final Map<dynamic, dynamic> dataMap = dataValue is Map ? dataValue : {};
        List<HistoricalData> historyList = [];

        dataMap.forEach((key, value) {
          if (value is Map) {
            historyList.add(HistoricalData.fromRTDB(key, value));
          }
        });

        // Verileri zaman sırasına göre diz
        historyList.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Hatalı zaman (NTP_Yok) verilerini listeden çıkar
        historyList.removeWhere((element) => element.readableTime == "NTP_Yok");

        if (historyList.isEmpty) {
          return const Center(child: Text("Görüntülenecek veri yok."));
        }

        return Padding(
          padding: const EdgeInsets.only(top: kDefaultPadding),
          // AspectRatio 1.7: Dikdörtgen görünüm (Sütunlar için ideal)
          child: AspectRatio(
            aspectRatio: 1.7, 
            child: BarChart(
              _buildBarChartData(historyList, _selectedChart),
            ),
          ),
        );
      },
    );
  }

  // --- SÜTUN GRAFİK KONFİGÜRASYONU ---
  BarChartData _buildBarChartData(List<HistoricalData> historyList, String key) {
    List<BarChartGroupData> barGroups = [];
    
    // Y ekseninin tavan noktasını bul (En yüksek değer)
    double maxY = 0;
    for (var data in historyList) {
      double val = _getValue(data, key);
      if (val > maxY) maxY = val;
    }
    // Grafik tepeye yapışmasın diye %20 boşluk bırak
    if (maxY == 0) maxY = 10; // Hiç veri yoksa varsayılan tavan
    double backgroundTop = maxY * 1.2;

    for (int i = 0; i < historyList.length; i++) {
      var data = historyList[i];
      double yValue = _getValue(data, key);

      // Her bir çubuğun (Bar) oluşturulması
      barGroups.add(
        BarChartGroupData(
          x: i, // X ekseni 0, 1, 2... diye giden indekslerdir (Zaman aşağıda haritalanır)
          barRods: [
            BarChartRodData(
              toY: yValue,
              color: kPrimaryColor,
              width: 12, // Çubuk kalınlığı
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              // Çubuğun arkasındaki gri gölge (Max kapasiteyi gösterir)
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: backgroundTop, 
                color: Colors.grey.withValues(alpha:0.1),
              ),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      // Çubuklara basınca çıkan bilgi balonu
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.blueGrey.shade900,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final data = historyList[group.x.toInt()];
            final date = _getDateTime(data.timestamp);
            String timeStr = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
            
            return BarTooltipItem(
              "${rod.toY.toStringAsFixed(1)}\n$timeStr",
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        
        // SOL EKSEN (Değerler)
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              // Sadece tam sayıları ve belirli aralıkları göster (Kalabalığı önle)
              if (value == 0) return const SizedBox.shrink();
              return Text(
                value.toInt().toString(),
                style: const TextStyle(color: Colors.black54, fontSize: 10),
              );
            },
          ),
        ),

        // ALT EKSEN (Zaman)
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) {
              int index = value.toInt();
              // Liste sınırlarını kontrol et
              if (index < 0 || index >= historyList.length) return const SizedBox.shrink();
              
              // Yazıların üst üste binmemesi için her 4 veya 5 veride bir saat göster
              // Eğer liste kısaysa (örn 5 veri) hepsini göster
              bool shouldShow = historyList.length < 8 || index % 4 == 0;
              
              if (!shouldShow) return const SizedBox.shrink();

              final data = historyList[index];
              final date = _getDateTime(data.timestamp);
              
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
      
      // Arka plandaki çizgiler
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false, // Dikey çizgi sütun grafikte kafa karıştırır
        horizontalInterval: maxY / 4, // 4 tane yatay çizgi at
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha:0.2),
          strokeWidth: 1,
        ),
      ),
      
      borderData: FlBorderData(show: false), // Dış çerçeveyi kapat
      barGroups: barGroups,
    );
  }

  // --- Yardımcı Metodlar ---

  // Seçilen tipe göre değeri döndürür
  double _getValue(HistoricalData data, String key) {
    switch (key) {
      case 'temperature': return data.temperature;
      case 'humidity': return data.humidity;
      case 'co2': return data.co2.toDouble();
      default: return data.vocQuality.toDouble();
    }
  }

  // Timestamp formatını düzeltir (Saniye -> Milisaniye)
  DateTime _getDateTime(num timestamp) {
    if (timestamp < 10000000000) { 
      return DateTime.fromMillisecondsSinceEpoch((timestamp * 1000).toInt());
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
  }
}