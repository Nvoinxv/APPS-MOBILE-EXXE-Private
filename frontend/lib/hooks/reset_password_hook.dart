import 'package:http/http.dart' as http;
import 'dart:convert';

class Reset_Password_Hook {
    // Ini gw pakai local host dulu //
    // Belum production mode //
    // Soal nya rada mahal pengembangan nya //
    static const String baseUrl = "http://127.0.0.1:8080";

    static Future<Map<String, dynamic>> ResetPassHook({
        required String email,
        required String password,
    }) async {
        try {
            final response = await http.post(
                Uri.parse("$baseUrl/reset-password"),
                headers: {
                    "Content-Type": "application/json",
                },
                body: jsonEncode({
                    "email": email,
                    "password": password,
                }),
            );

            // Kalau backend balikin status sukses //
            if (response.statusCode == 200) {
                return {
                    "success": true,
                    "data": jsonDecode(response.body),
                };
            } 
            // Kalau gagal (email gak ada / error lain) //
            else {
                return {
                    "success": false,
                    "message": jsonDecode(response.body),
                };
            }
        } 
        // Kalau error koneksi / parsing //
        catch (e) {
            return {
                "success": false,
                "error": e.toString(),
            };
        }
    }
}
