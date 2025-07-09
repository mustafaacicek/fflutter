import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final T? data;
  final String? error;
  final bool success;

  ApiResponse({this.data, this.error, this.success = false});

  factory ApiResponse.success(T data) {
    return ApiResponse(data: data, success: true);
  }

  factory ApiResponse.error(String error) {
    return ApiResponse(error: error, success: false);
  }
}

class ApiUtils {
  static String handleError(dynamic error) {
    if (error is SocketException) {
      return 'İnternet bağlantınızı kontrol edin.';
    } else if (error is FormatException) {
      return 'Sunucudan geçersiz veri alındı.';
    } else if (error is http.ClientException) {
      return 'Sunucu ile iletişim kurulamadı.';
    } else {
      return error.toString();
    }
  }

  static dynamic parseResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return json.decode(response.body);
      case 400:
        throw Exception('Geçersiz istek: ${response.body}');
      case 401:
        throw Exception('Yetkisiz erişim');
      case 403:
        throw Exception('Erişim reddedildi');
      case 404:
        throw Exception('Kaynak bulunamadı');
      case 500:
        throw Exception('Sunucu hatası');
      default:
        throw Exception('Beklenmeyen hata: ${response.statusCode}');
    }
  }
}
