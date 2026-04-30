import 'package:flutter/material.dart';
import '../utils/role_guard.dart'; // ← TAMBAH INI
import '../utils/auth_storage.dart';

// Bagian Autentikasi Import //
import 'screen/register_screen.dart';
import 'screen/login_screen.dart';
import 'screen/otp_screen.dart';
import 'screen/reset_password_screen.dart';

// Bagian Screen Import //
import 'screen/upload_daily_research_screen.dart';
import 'screen/upload_news_screen.dart';
import 'screen/upload_quant_screen.dart';
import 'screen/trade_ideas_screen.dart';
import 'screen/investing_quant_screen.dart';
import 'screen/upload_market_outlook_screen.dart';
import 'screen/upload_trade_ideas_screen.dart';
import 'screen/market_outlook_screen.dart';
import 'screen/research_coin_screen.dart';
import 'screen/the_street_view_screen.dart';
import 'screen/upload_research_coin_screen.dart';

// Khusus trade //
import '../trading_screen/tradeview_screen.dart';

// Bagian Postingan //
import 'postingan/postingan_quant_investing.dart';

// Bagian Home Pages Import //
import 'pages/home_pages.dart';

// Bagian payment pages //
import 'pages/payment_pages.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EXXE.LAB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBEFF00)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),

      initialRoute: '/',
      routes: {
        '/login':          (context) => const LoginScreen(),
        '/register':       (context) => const RegisterScreen(),
        '/otp':            (context) => const OtpScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
      },

      onGenerateRoute: (settings) {

        // ── Home ─────────────────────────────────────────────────────────────
        if (settings.name == '/home') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(builder: (_) => HomeScreen(token: token));
        }

        // ── Trade View (chart) ────────────────────────────────────────────────
        // ⚠️  PROTECTED — hanya ADMIN & EXCLUSIVE
        // Navigate ke sini pakai:
        //   Navigator.pushNamed(context, '/trade-view', arguments: token);
        if (settings.name == '/trade-view') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => RoleGuard(
              token: token,
              child: TradeViewScreen(token: token),
            ),
          );
        }

        // Bagian Payment Pages ───────────────────────────────────────────────────────
        if (settings.name == '/payment') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => PaymentPage(token: token),
          );
        }

        // ── Upload Daily Research ─────────────────────────────────────────────
        if (settings.name == '/upload_daily_research') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => UploadDailyResearch(token: token),
          );
        }

        // ── Upload News ───────────────────────────────────────────────────────
        if (settings.name == '/upload_news') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => UploadNewsScreen(token: token),
          );
        }

        // ── Quant Investing ───────────────────────────────────────────────────
        if (settings.name == '/quant_investing') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => QuantInvestingScreen(token: token),
          );
        }

        // ── Quant Detail (postingan) ───────────────────────────────────────────
        if (settings.name == '/quant_detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => PostinganQuantInvestingScreen(quantData: args),
          );
        }

        // ── Upload Quant ──────────────────────────────────────────────────────
        if (settings.name == '/upload_quant') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => UploadQuantScreen(token: token),
          );
        }

        // ── Trade Ideas ───────────────────────────────────────────────────────
        if (settings.name == '/trade-ideas') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => TradeIdeasScreen(token: token),
          );
        }

        // ── Upload Trade Ideas ────────────────────────────────────────────────
        if (settings.name == '/upload_trade_ideas') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => Upload_trade_ideas(token: token),
          );
        }

        // ── Market Outlook ────────────────────────────────────────────────────
        if (settings.name == '/market-outlook') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => MarketOutlookScreen(token: token),
          );
        }

        // ── Upload Market Outlook ─────────────────────────────────────────────
        if (settings.name == '/upload_market_outlook') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => Upload_Market_Outlook(token: token),
          );
        }

        // ── Research Coin ─────────────────────────────────────────────────────
        if (settings.name == '/research-coin') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => ResearchCoinScreen(token: token),
          );
        }

        // ── Upload Research Coin ──────────────────────────────────────────────
        if (settings.name == '/upload_research_coin') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => UploadResearchCoinScreen(token: token),
          );
        }

        // ── Street View ───────────────────────────────────────────────────────
        // ⚠️  PROTECTED — hanya ADMIN & EXCLUSIVE
        if (settings.name == '/street_view') {
          // Street view tidak terima token via arguments sekarang
          // Tapi kita butuh token untuk guard — ambil dari arguments kalau ada
          final token = settings.arguments;
          if (token == null || token is! String) {
            // Kalau tidak ada token → anggap tidak login
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
          return MaterialPageRoute(
            builder: (_) => RoleGuard(
              token: token,
              child: CryptoStreetViewScreen(),
            ),
          );
        }

        return null;
      },
    );
  }
}

// ✅ SplashScreen — cek token, arahkan ke halaman yang benar
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Ambil token dari SharedPreferences
    final token = await AuthStorage.getToken();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      // ✅ Token ada → langsung ke /home, pass token sebagai arguments
      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: token, // ← HomeScreen butuh token via arguments
      );
    } else {
      // Belum login → ke halaman login
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilan saat loading — bisa diganti logo EXXE.LAB
    return const Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFBEFF00), // warna accent EXXE.LAB
        ),
      ),
    );
  }
}