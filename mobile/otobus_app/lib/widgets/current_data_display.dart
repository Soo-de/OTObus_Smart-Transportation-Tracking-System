import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants.dart';
import '../models/current_data.dart';

class CurrentDataDisplay extends StatelessWidget {
  const CurrentDataDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseReference dataRef = FirebaseDatabase.instance.ref(
      'home/current_data',
    );

    return StreamBuilder<DatabaseEvent>(
      stream: dataRef.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          );
        }
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.snapshot.value == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text("Veri akışı bekleniyor.")),
          );
        }

        CurrentData data = CurrentData.empty();
        String lastUpdateTime = "Veri Yok";

        if (snapshot.data!.snapshot.value is Map) {
          final Map<dynamic, dynamic> map =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          data = CurrentData.fromRTDB(map);

          if (data.lastUpdate > 0) {
            final dateTime = DateTime.fromMillisecondsSinceEpoch(
              data.lastUpdate,
            );
            lastUpdateTime =
                "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Son Güncelleme: $lastUpdateTime",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: kDefaultPadding),
            _buildDataGrid(data),
            const SizedBox(height: kDefaultPadding),
            _buildInfoCard(
              title: "Hava Kalitesi Yorumu",
              content: _getQualityComment(data.vocQuality),
              icon: Icons.lightbulb_outline,
            ),
          ],
        );
      },
    );
  }

  // --- Yardımcı Metodlar (UI ve Logic) ---

  Widget _buildDataGrid(CurrentData data) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: kDefaultPadding,
      mainAxisSpacing: kDefaultPadding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSensorCard(
          "Sıcaklık",
          "${data.temperature.toStringAsFixed(1)} °C",
          Icons.thermostat_outlined,
          Colors.orange,
        ),
        _buildSensorCard(
          "Nem",
          "${data.humidity.toStringAsFixed(1)} %",
          Icons.water_drop_outlined,
          Colors.blue,
        ),
        _buildSensorCard(
          "CO2",
          "${data.co2} PPM",
          Icons.cloud_outlined,
          Colors.grey.shade700,
        ),
        _buildSensorCard(
          "Hava Kalitesi",
          "${data.vocQuality}",
          Icons.air,
          _getQualityColor(data.vocQuality),
        ),
      ],
    );
  }

  Widget _buildSensorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(kDefaultPadding / 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String content,
    required IconData icon,
    String title = "Hava Kalitesi Yorumu",
  }) {
    return Container(
      padding: const EdgeInsets.all(kDefaultPadding),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 30, color: kPrimaryColor),
          const SizedBox(width: kDefaultPadding),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getQualityComment(int voc) {
    if (voc < 100)
      return "Mükemmel. Hava kalitesi çok iyi, ek havalandırmaya gerek yok.";
    if (voc < 300)
      return "İyi. Hava kalitesi normal seviyelerde, yolculuk konforlu.";
    if (voc < 500)
      return "Orta. CO2 seviyesi yükseliyor olabilir. Havalandırma önerilir.";
    return "Kötü. Hava kalitesi düşük, kapıların/havalandırmanın hemen açılması gerekli.";
  }

  Color _getQualityColor(int voc) {
    if (voc < 100) return Colors.green;
    if (voc < 300) return Colors.lightGreen;
    if (voc < 500) return Colors.amber.shade700;
    return Colors.red;
  }
}
