// Ini bagian login hook //
// Lebih menerima api antar backend //
// Biar bisa di akses sama front end //

import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> LoginHook({
  required String password,
  required String email
}) async {
  try {
    // Kita dapatkan url nya - sesuaikan sama backend lu //
    // Ganti dengan URL backend lu yang beneran //
    final response = await http.post(
      // Ini gw pakai url untuk khusus linux/mac os //
      // Kalau android beda lagi pemasangan url nya //
      Uri.parse('http://127.0.0.1:8080/login'), 
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'email': email,
        'password': password,
        // ROLE GAK PERLU DIKIRIM - Backend udah auto set ke GENERAL
        // Role cuma berubah kalau user bayar (upgrade-to-exclusive)
      }),
    );
    
    // Cek kondisi apakah bisa di akses url nya //
    if (response.statusCode == 200) {
      // kalau sukses bongkar isi json nya //
      return json.decode(response.body);
    } else {
      // Kalau gagal tapi dapet response dari server //
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Gagal login');
    }
  } catch (e) {
    // Kalau gagal total (network error dll) //
    throw Exception('Gagal terhubung ke server: ${e.toString()}');
  }
}  