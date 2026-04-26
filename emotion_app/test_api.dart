import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final baseUrl = 'https://emotion-detection.runasp.net/api';
  
  // 1. Login
  final loginRes = await http.post(
    Uri.parse('$baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'test@example.com', // guess
      'password': 'password123'
    }),
  );
  print('Login: ${loginRes.statusCode} ${loginRes.body}');
}
