import 'package:dio/dio.dart';
import '../config/app_version.dart';
import '../security/secure_session.dart';

class ApiClient {
  static const String appEnv = String.fromEnvironment(
    'MEDICARE_ENV',
    defaultValue: 'dev',
  );

  // En QA/Producción se inyecta con --dart-define=MEDICARE_API_URL=...
  static const String baseUrl = String.fromEnvironment(
    'MEDICARE_API_URL',
    defaultValue: 'http://84.247.178.194:5189/api',
  );

  static void Function()? onUnauthorized;

  final Dio _dio;

  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureSession.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          if (status == 401 && !path.startsWith('/auth/login')) {
            await SecureSession.clearSession();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final clean = identifier.trim();
    final res = await _dio.post('/auth/login', data: {
      'username': clean,
      'email': clean,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<dynamic>> getAppointments({String? date}) async {
    final res = await _dio.get('/appointments', queryParameters: date != null ? {'date': date} : null);
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createAppointment(Map<String, dynamic> payload) async {
    final res = await _dio.post('/appointments', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> updateAppointmentStage(String appointmentId, String stage) async {
    await _dio.patch('/appointments/$appointmentId/stage', data: {'stage': stage});
  }

  Future<void> rescheduleAppointment(
    String appointmentId, {
    required String date,
    required String time,
  }) async {
    await _dio.patch('/appointments/$appointmentId/reschedule', data: {
      'date': date,
      'time': time,
    });
  }

  Future<void> deleteAppointment(String appointmentId) async {
    await _dio.delete('/appointments/$appointmentId');
  }

  Future<List<dynamic>> getPatients({String? q}) async {
    final res = await _dio.get('/patients', queryParameters: q != null ? {'q': q} : null);
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createPatient(Map<String, dynamic> payload) async {
    final res = await _dio.post('/patients', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getPatient360(String patientId, {int? viewerSpecialtyId}) async {
    final res = await _dio.get(
      '/patients/$patientId',
      queryParameters: viewerSpecialtyId != null ? {'viewerSpecialtyId': viewerSpecialtyId} : null,
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> completeConsultation(Map<String, dynamic> payload) async {
    final res = await _dio.post('/consultations', data: payload);
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> grantDiagnosisPermission({
    required String patientId,
    String? consultationId,
    required int grantedBySpecialtyId,
    required int targetSpecialtyId,
    required String reason,
  }) async {
    await _dio.post(
      '/patients/$patientId/diagnosis-permissions',
      data: {
        'consultationId': consultationId,
        'grantedBySpecialtyId': grantedBySpecialtyId,
        'targetSpecialtyId': targetSpecialtyId,
        'reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> processConsultationAi({
    required String transcript,
    String? patientName,
    double? weightKg,
    String? specialty,
  }) async {
    final res = await _dio.post('/ai/process-consultation', data: {
      'transcript': transcript,
      'patientName': patientName,
      'weightKg': weightKg,
      'specialty': specialty ?? 'Pediatría',
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> checkAppUpdate() async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    final res = await dio.get(
      kVersionManifestUrl,
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
    );
    return Map<String, dynamic>.from(res.data);
  }
}
