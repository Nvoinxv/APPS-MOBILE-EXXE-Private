// hooks/execute_hook.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ExecuteHook {
  static Future<Map<String, dynamic>> runCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'stdout': '',
          'stderr': 'Server error: ${response.statusCode}',
          'exit_code': -1,
        };
      }
    } catch (e) {
      return {
        'stdout': '',
        'stderr': 'Connection failed: $e',
        'exit_code': -1,
      };
    }
  }
}