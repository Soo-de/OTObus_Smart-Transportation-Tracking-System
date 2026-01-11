import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart'; // Firebase paketi
import 'package:google_fonts/google_fonts.dart'; // Font paketi
import '../constants.dart'; // Renkler ve sabitler
import '../widgets/mjpeg_view.dart'; // <-- YENİ OLUŞTURDUĞUMUZ WIDGET BURADA

// DİKKAT: Buraya Raspberry Pi'nin GÜNCEL IP adresini yazmalısın.
// Telefonun ve Raspberry Pi aynı internete bağlı olmalı.
const String streamUrl = 'http://172.20.10.2:5000/video_feed'; 

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // 1. Veritabanı referansını tanımlıyoruz.
  final DatabaseReference _doorRef = FirebaseDatabase.instance.ref(
    'home/door_status',
  );

  // Kapı durumunu değiştiren fonksiyon
  void toggleDoor(bool currentStatus) {
    _doorRef.set(!currentStatus).catchError((error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: $error")));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Kontrol Paneli",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: kPrimaryColor, // constants.dart dosyasından gelir
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: kBackgroundColor, // constants.dart dosyasından gelir
      // 2. StreamBuilder ile veritabanını dinliyoruz
      body: StreamBuilder<DatabaseEvent>(
        stream: _doorRef.onValue,
        builder: (context, snapshot) {
          // A. Veri yükleniyor mu?
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            );
          }

          // B. Hata var mı?
          if (snapshot.hasError) {
            return Center(child: Text("Bağlantı Hatası: ${snapshot.error}"));
          }

          // C. Veriyi al ve bool'a çevir
          final bool isDoorOpen =
              (snapshot.data?.snapshot.value as bool?) ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kDefaultPadding), // constants.dart
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kapı Durumu",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // --- Durum Göstergesi (Kart Tasarımı) ---
                Container(
                  padding: const EdgeInsets.all(kDefaultPadding),
                  decoration: BoxDecoration(
                    color: isDoorOpen
                        ? Colors.green.withValues(alpha:0.1)
                        : Colors.red.withValues(alpha:0.1),
                    border: Border.all(
                      color: isDoorOpen ? Colors.green : Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDoorOpen ? Colors.green : Colors.red)
                                  .withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          isDoorOpen
                              ? Icons.meeting_room
                              : Icons.door_back_door,
                          size: 30,
                          color: isDoorOpen ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        isDoorOpen ? "KAPI AÇIK" : "KAPI KAPALI",
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDoorOpen ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Aç/Kapa Butonu ---
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => toggleDoor(isDoorOpen),
                    icon: Icon(isDoorOpen ? Icons.lock : Icons.lock_open),
                    label: Text(
                      isDoorOpen ? "KAPIYI KAPAT" : "KAPIYI AÇ",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDoorOpen
                          ? Colors.redAccent
                          : Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                Text(
                  "Kamera Görüntüsü",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // --- Kamera Alanı (Monitor Görünümü) ---
                Container(
                  height: 250,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias, // Taşan görüntüleri kırp
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade800, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  // EĞER KAPI AÇIKSA KAMERA GÖSTER, KAPALIYSA PASİF İKONU GÖSTER
                  child: isDoorOpen
                      ? MjpegView(
                          streamUrl: streamUrl, // En üstte tanımladığımız IP
                          loadingWidget: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Görüntüye Bağlanılıyor...",
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          errorWidget: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  "Bağlantı Kurulamadı\nIP: $streamUrl",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_off,
                                color: Colors.grey,
                                size: 50,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Kamera Pasif (Uyku Modu)",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}