import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Production URL — DDEV local test karna ho to yahan badal do
  // (Android emulator ke liye: 'http://10.0.2.2/hrms/index.php/api')
  // static const String baseUrl = 'http://10.0.2.2:32768/index.php/api';
  static const String baseUrl = 'http://10.0.2.2:32772/index.php/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> isLoggedIn() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  // ---------- Auth ----------

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': email, 'password': password},
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        if (data['employee'] != null) {
          await prefs.setString('employee_name', data['employee']['name'] ?? '');
          await prefs.setString('employee_code', data['employee']['code'] ?? '');
        }
      }
      return data;
    } catch (e) {
      return {'status': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: await _headers(),
      );
    } catch (_) {
      // token clear karna zaroori hai chahe request fail ho jaye
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('employee_name');
    await prefs.remove('employee_code');
  }

  // ---------- Attendance ----------

  static Future<Map<String, dynamic>> clockIn({double? lat, double? lng}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/clock_in'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {
          if (lat != null) 'lat': lat.toString(),
          if (lng != null) 'lng': lng.toString(),
        },
      );
      print('CLOCK_IN RAW RESPONSE: ${response.body}');   // 👈 temporary debug line
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'msg': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> clockOut() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/clock_out'),
        headers: await _headers(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'msg': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> breakOut() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/break_out'),
        headers: await _headers(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'msg': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> breakIn() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/break_in'),
        headers: await _headers(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'msg': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/status'),
        headers: await _headers(),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'state': 'not_logged_in', 'total_break': 0};
    }
  }
}