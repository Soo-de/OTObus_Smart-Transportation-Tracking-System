import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için
import '../constants.dart';
import '../services/ai_api_service.dart';

class AiReportScreen extends StatefulWidget {
  const AiReportScreen({super.key});

  @override
  State<AiReportScreen> createState() => _AiReportScreenState();
}

class _AiReportScreenState extends State<AiReportScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;
  
  // Varsayılan olarak bugünün tarihini tutuyoruz
  DateTime _selectedDate = DateTime.now();

  // Tarih seçiciyi açan fonksiyon
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023), // Verilerin başladığı tarih
      lastDate: DateTime.now(),   // Gelecek tarih seçilemesin
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _result = null; // Yeni tarih seçilince eski sonucu temizle
        _error = null;
      });
    }
  }

  void _startAnalysis() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Tarihi YYYY-MM-DD formatına çevirip servise gönderiyoruz
      String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      
      final data = await AiApiService().fetchAndAnalyze(formattedDate);
      
      setState(() {
        _result = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("AI Günlük Analiz", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          children: [
            _buildActionHeader(),
            const SizedBox(height: 20),
            if (_isLoading) 
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            if (_error != null) 
              _buildErrorWidget(),
            if (_result != null) 
              _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, size: 50, color: kPrimaryColor),
          const SizedBox(height: 15),
          Text(
            "Tarih Bazlı Analiz",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          
          // --- TARİH SEÇME ALANI ---
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: kPrimaryColor.withValues(alpha:0.3)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, color: kPrimaryColor),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _startAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text("Analizi Başlat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha:0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: kPrimaryColor),
              const SizedBox(width: 10),
              Text("AI Analiz Raporu", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 30),
          Text(
            _result!['summary'] ?? "Özet oluşturulamadı.",
            style: GoogleFonts.poppins(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          _infoBadge("AI Tahmini: ${_result!['prediction'] ?? 'Veri bekleniyor...'}", kPrimaryColor),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _infoBadge(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }
}