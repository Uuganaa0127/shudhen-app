import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final int? status;
  final String message;
  const ApiFailure(this.message, [this.status]);
  @override
  String toString() => message;
}

const hospitalApiBase = 'https://api.oyudent.com/hospital/api/v1';

/// Use the deployed hospital service unless a development URL is explicitly
/// supplied through API_BASE_URL or the injected client configuration.
String resolveApiBase({
  String? explicit,
  String configured = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: hospitalApiBase,
  ),
  bool debug = kDebugMode,
}) {
  var value = (explicit ?? configured).trim();
  if (value.isEmpty) value = hospitalApiBase;
  value = value.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.scheme != 'https' && !(debug && uri.scheme == 'http'))) {
    throw const ApiFailure('Эмнэлэгтэй холбогдох тохиргоо буруу байна.');
  }
  return value;
}

class CareApi {
  final String baseUrl;
  final http.Client client;
  CareApi({String? baseUrl, http.Client? client})
    : baseUrl = resolveApiBase(explicit: baseUrl),
      client = client ?? http.Client();

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, Uri.parse('$baseUrl/shudhen/$path'));
      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = response.statusCode;
        throw ApiFailure(switch (code) {
          401 =>
            'Холбоосын хугацаа дууссан эсвэл эрх цуцлагдсан. Эмнэлгээс шинэ урилга авна уу.',
          409 => 'Бүртгэл зөрчилтэй байна. Эмнэлэгтэйгээ холбогдоно уу.',
          400 => 'Оруулсан мэдээллээ шалгана уу.',
          404 =>
            'Эмнэлгийн сервер дээр энэ үйлчилгээ олдсонгүй. Эмнэлэгтэйгээ холбогдоно уу.',
          429 => 'Түр хүлээгээд дахин оролдоно уу.',
          _ => 'Эмнэлгийн сервертэй холбогдож чадсангүй. Дахин оролдоно уу.',
        }, code);
      }
      if (response.statusCode == 204) return {};
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on ApiFailure {
      rethrow;
    } on FormatException {
      throw const ApiFailure('Серверээс буруу хариу ирлээ. Дахин оролдоно уу.');
    } on TimeoutException {
      throw const ApiFailure(
        'Эмнэлгийн серверийн хариу удаж байна. Дахин оролдоно уу.',
      );
    } catch (_) {
      throw const ApiFailure(
        'Эмнэлгийн сервертэй холбогдож чадсангүй. Сервер ажиллаж байгаа эсэхийг шалгаад дахин оролдоно уу.',
      );
    }
  }

  void close() => client.close();
}
