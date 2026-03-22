import 'package:flutter/material.dart';

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
      home: const LoginScreen(),
      
      // ROUTE TANPA ARGUMENT
      initialRoute: '/',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/otp': (context) => const OtpScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
      },
      
      // ROUTE DENGAN ARGUMENT
      onGenerateRoute: (settings) {
        // Home Screen - Combined Daily Research + News
        if (settings.name == '/home') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (_) => HomeScreen(token: token),
          );
        }
        
        // Upload Daily Research
        if (settings.name == '/upload_daily_research') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (_) => UploadDailyResearch(token: token),
          );
        }
        
        // Upload News //
        if (settings.name == '/upload_news') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }
          return MaterialPageRoute(
            builder: (_) => UploadNewsScreen(token: token),
          );
        } 
        
        // Quant Investing //
        if (settings.name == '/quant_investing') {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => QuantInvestingScreen(token: token),
          );
        }

        // ✅ ROUTE DETAIL QUANT INVESTING (POSTINGAN)
        if (settings.name == '/quant_detail') {
          final args = settings.arguments as Map<String, dynamic>?;
          
          if (args == null) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => PostinganQuantInvestingScreen(
              quantData: args,
            ),
          );
        }

        // Upload Quant //
        if (settings.name == "/upload_quant") {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => UploadQuantScreen(token: token),
          );
        }

        // Trade Ideas Screen //
        if (settings.name == "/trade-ideas") {
          final token = settings.arguments as String;
          if (token == null || token is! String) {
            return MaterialPageRoute (
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => TradeIdeasScreen(token:token),
          );
        }

        // Upload Trade Ideas //
        if (settings.name == "/upload_trade_ideas") {
          final token = settings.arguments;
          if (token == null || token is! String) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            }

          return MaterialPageRoute(
            builder: (_) => Upload_trade_ideas(token: token),
          );
        }

        // market outlook screen //
        if (settings.name == "/market-outlook") {
          final token = settings.arguments as String;
          if (token == null || token is! String) {
            return MaterialPageRoute (
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => MarketOutlookScreen(token:token),
          );
        }

        // Upload market outlook //
        if (settings.name == "/upload_market_outlook") {
          final token = settings.arguments;
          if (token == null || token is! String) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            }

          return MaterialPageRoute(
            builder: (_) => Upload_Market_Outlook(token: token),
          );
        }

        // Bagian Research Coin Screen //
        if (settings.name == "/research-coin") {
          final token = settings.arguments;
          if (token == null || token is! String) {
            return MaterialPageRoute (
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => ResearchCoinScreen(token: token),
          );
        }

        // Bagian Upload Research Coin //
        if (settings.name == "/upload_research_coin") {
          final token = settings.arguments;
          if (token == null || token is! String) {
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            }

          return MaterialPageRoute(
            builder: (_) => UploadResearchCoinScreen(token: token),
          );
        }

        // Street View Screen //
        if (settings.name == "/street_view") {
          final token = settings.arguments;

          if (token == null || token is! String) {
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          }

          return MaterialPageRoute(
            builder: (_) => CryptoStreetViewScreen(),
          );
        }

        return null;
      },
    );
  }
}