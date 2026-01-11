import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../widgets/current_data_display.dart'; // Anlık Veri Modülü
import '../widgets/history_chart_display.dart'; // Grafik Modülü

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Anlık Çevresel Veriler",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),

      // Kaydırma için SingleChildScrollView kullanılıyor
      // const anahtar kelimesini kaldırdık ki, alt widget'lar doğru renderlansın.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            // const burada kalabilir, child widget'lar zaten const.
            // BÖLÜM 1: Anlık Kartlar (Grid, kendi Stream'ini yönetir)
            CurrentDataDisplay(),

            SizedBox(height: 30),
            Divider(), // Görsel ayırıcı
            SizedBox(height: 30),

            // BÖLÜM 2: Geçmiş Grafik (Kendi Stream'ini ve State'ini yönetir)
            HistoryChartDisplay(),
          ],
        ),
      ),
    );
  }
}
