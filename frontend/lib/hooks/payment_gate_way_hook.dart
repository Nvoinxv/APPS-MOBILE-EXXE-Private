import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

class Payment_Hook {

  // ======================================
  // CHECKOUT PAYMENT (CREATE TRANSACTION)
  // Returns: order_id, wallet_address (tujuan),
  //          user_wallet, amount_usdt,
  //          network, token, expires_in, note
  // ======================================
  static Future<Map<String, dynamic>> CheckoutPayment({
    required String userWallet, // wallet address user (pengirim)
    required String planType,   // monthly | semi_annual | annual
  }) async {
    try {
      final token = await AuthStorage.getToken();

      // user_wallet → query param
      // plan_type   → request body (embed: true)
      final uri = Uri.parse("${AuthStorage.activeBaseUrl}/checkout").replace(
        queryParameters: {"user_wallet": userWallet},
      );

      var response = await http.post(
        uri,
        headers: {
          "Content-Type":  "application/json",
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
        body: jsonEncode({"plan_type": planType}),
      );

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.post(
          uri,
          headers: {
            "Content-Type":  "application/json",
            if (newToken != null && newToken.isNotEmpty)
              "Authorization": "Bearer $newToken",
          },
          body: jsonEncode({"plan_type": planType}),
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "data": {
            "order_id":       data["order_id"],
            "plan":           data["plan"],
            "amount_usdt":    data["amount_usdt"],
            "wallet_address": data["wallet_address"], // tujuan (business wallet)
            "user_wallet":    data["user_wallet"],    // pengirim (user)
            "network":        data["network"],
            "token":          data["token"],
            "expires_in":     data["expires_in"],
            "note":           data["note"],
          },
        };
      }

      // 400 → wallet invalid / paket salah
      if (response.statusCode == 400) {
        final body = jsonDecode(response.body);
        return {
          "success": false,
          "message": body["detail"] ?? response.body,
        };
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }

  // ======================================
  // CEK STATUS TRANSAKSI
  // Response:
  //   pending  → tunggu pembayaran
  //   paid     → tx_hash + discord_link tersedia
  //   expired  → suruh checkout ulang
  // ======================================
  static Future<Map<String, dynamic>> CheckTransactionStatus({
    required String orderId,
  }) async {
    try {
      final token = await AuthStorage.getToken();
      final uri   = Uri.parse("${AuthStorage.activeBaseUrl}/status/$orderId");

      var response = await http.get(
        uri,
        headers: {
          if (token != null && token.isNotEmpty)
            "Authorization": "Bearer $token",
        },
      );

      // Auto-refresh 401
      if (response.statusCode == 401) {
        final refreshed = await AuthStorage.refreshAccessToken();
        if (!refreshed) {
          return {"success": false, "message": "Session expired. Silakan login ulang."};
        }
        final newToken = await AuthStorage.getToken();
        response = await http.get(
          uri,
          headers: {
            if (newToken != null && newToken.isNotEmpty)
              "Authorization": "Bearer $newToken",
          },
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "data": {
            "order_id":    data["order_id"],
            "status":      data["status"],
            "amount_usdt": data["amount_usdt"],
            "plan":        data["plan"],
            "user_wallet": data["user_wallet"],
            "message":     data["message"],
            // Cuma ada kalau status == "paid"
            if (data["status"] == "paid") ...{
              "tx_hash":      data["tx_hash"],
              "tx_explorer":  data["tx_explorer"],
              "discord_link": data["discord_link"],
            },
          },
        };
      }

      if (response.statusCode == 404) {
        return {"success": false, "message": "Order tidak ditemukan"};
      }

      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "error": e.toString()};
    }
  }
}