import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import 'stats_screen.dart'; 
import 'control_screen.dart'; 
import 'ai_report_screen.dart'; // AI Ekranı importu

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ekran boyutunu alıyoruz (Responsive tasarım için)
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          // --- Üst Kısım (Renkli Alan ve Logo) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.48, // Üçüncü buton için yüksekliği dengeledik
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
              decoration: const BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                  bottomRight: Radius.circular(150),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // İkon Arkasındaki Hafif Daire
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_bus_filled_rounded,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "OTObus",
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "Akıllı Takip Sistemi",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Alt Kısım (Butonlar ve Karşılama Metni) ---
          Positioned(
            top: size.height * 0.48,
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding * 1.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Hoş Geldiniz",
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Analiz ve kontroller için bir işlem seçin.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 35),

                  // 1. BUTON: İstatistikler (Grafik Ekranı)
                  _buildMenuButton(
                    context,
                    "Yolcu İstatistikleri",
                    Icons.bar_chart_rounded,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const StatsScreen()),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 2. BUTON: YENİ - AI Analiz Raporu
                  _buildMenuButton(
                    context,
                    "AI Günlük Analiz",
                    Icons.auto_awesome_rounded,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AiReportScreen()),
                    ),
                    color: Colors.amber.shade800, // AI için dikkat çekici renk
                  ),

                  const SizedBox(height: 15),

                  // 3. BUTON: Kontrol Paneli (Kapı Aç/Kapa)
                  _buildMenuButton(
                    context,
                    "Kapı ve Kontrol",
                    Icons.settings_remote,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ControlScreen()),
                    ),
                    isOutlined: true, // Çerçeveli buton
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Yardımcı Buton Widget'ı (Geliştirilmiş Versiyon) ---
  Widget _buildMenuButton(
    BuildContext context,
    String text,
    IconData icon,
    VoidCallback onPressed, {
    bool isOutlined = false,
    Color? color,
  }) {
    // Eğer özel bir renk verilmediyse kPrimaryColor kullanıyoruz
    final Color activeColor = color ?? kPrimaryColor;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: activeColor),
              label: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: activeColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 0,
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.white),
              label: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                elevation: 5,
                shadowColor: activeColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
    );
  }
}