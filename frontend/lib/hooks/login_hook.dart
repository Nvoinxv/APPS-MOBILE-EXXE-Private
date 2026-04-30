import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/auth_storage.dart';

Future<Map<String, dynamic>> LoginHook({
  required String password,
  required String email,
}) async {
  try {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8080/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      await AuthStorage.saveSession(
        token:        data['access_token'],
        refreshToken: data['refresh_token'] ?? '',
        userId:       data['user']['id'].toString(),
        email:        data['user']['email'],
        role:         data['user']['role'],
        name:         data['user']['name'],
      );

      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Gagal login');
    }
  } catch (e) {
    throw Exception('Gagal terhubung ke server: ${e.toString()}');
  }
}