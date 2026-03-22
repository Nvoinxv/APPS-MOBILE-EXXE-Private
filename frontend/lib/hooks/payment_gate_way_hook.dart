import 'package:http/http.dart' as http;
import 'dart:convert';

class Payment_Hook {
    // Local host dulu //
    // Belum production //
    static const String baseUrl = "http://127.0.0.1:8080";

    // ======================================
    // CHECKOUT PAYMENT (CREATE TRANSACTION)
    // ======================================
    static Future<Map<String, dynamic>> CheckoutPayment({
        required int amount,               // Optional sebenernya, server yg validasi
        required String customerName,
        required String customerEmail,
        required String planType,           // monthly | semi_annual | annual
    }) async {
        try {
            final response = await http.post(
                Uri.parse("$baseUrl/checkout"),
                headers: {
                    "Content-Type": "application/json",
                },
                body: jsonEncode({
                    "amount": amount,
                    "customer_name": customerName,
                    "customer_email": customerEmail,
                    "plan_type": planType,
                }),
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
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
    // OPTIONAL: CEK STATUS TRANSAKSI (LOCAL)
    // Biasanya jarang dipakai karna webhook
    // ======================================
    static Future<Map<String, dynamic>> CheckTransactionStatus({
        required String orderId,
    }) async {
        try {
            final response = await http.get(
                Uri.parse("$baseUrl/transaction-status?order_id=$orderId"),
            );

            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
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
