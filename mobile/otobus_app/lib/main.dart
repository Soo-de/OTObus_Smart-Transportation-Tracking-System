import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Çekirdeği
import 'package:google_fonts/google_fonts.dart'; // Yazı Tipleri
import 'firebase_options.dart'; // Terminalde oluşturduğun ayar dosyası
import 'constants.dart'; // Renkler ve sabitler
import 'screens/wellcome_screen.dart'; // Açılış Ekranı

void main() async {
  // 1. Flutter motorunun asenkron işlemlerden önce hazır olduğundan emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Firebase'i başlatıyoruz (otomatik oluşturulan ayarları kullanarak)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Uygulamayı başlatıyoruz
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Sağ üstteki "Debug" bandını kaldırır
      debugShowCheckedModeBanner: false,

      title: 'OTObus',

      // --- Uygulamanın Genel Teması ---
      theme: ThemeData(
        useMaterial3: true, // Modern Android/iOS görünümü
        // Ana renk paletini constants.dart içindeki rengimizden türetiyoruz
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryColor,
          primary: kPrimaryColor,
        ),

        // Arka plan rengini sabitliyoruz
        scaffoldBackgroundColor: kBackgroundColor,

        // Tüm metinlere varsayılan olarak Poppins fontunu uyguluyoruz
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),

        // AppBar teması (Varsayılan ayarlar)
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0455
        ),
      ),

      // Uygulama açılınca ilk bu ekranı göster
      home: const WelcomeScreen(),
    );
  }
}
