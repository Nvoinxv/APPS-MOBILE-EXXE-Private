import 'package:http/http.dart' as http;
import 'dart:convert';

class Payment_Hook {
  // Local host dulu //
  // Belum production //
  static const String baseUrl = "http://127.0.0.1:8080";

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
      // user_wallet → query param
      // plan_type   → request body (embed: true)
      final uri = Uri.parse("$baseUrl/checkout").replace(
        queryParameters: {
          "user_wallet": userWallet,
        },
      );

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "plan_type": planType,
        }),
      );

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

      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
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
      final response = await http.get(
        Uri.parse("$baseUrl/status/$orderId"),
      );

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
        return {
          "success": false,
          "message": "Order tidak ditemukan",
        };
      }

      return {
        "success": false,
        "message": response.body,
      };
    } catch (e) {
      return {
        "success": false,
        "error": e.toString(),
      };
    }
  }
}