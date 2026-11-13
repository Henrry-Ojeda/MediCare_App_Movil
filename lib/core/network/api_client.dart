import 'package:dio/dio.dart';
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

  Future<List<dynamic>> getPatients({String? q}) async {
    final res = await _dio.get('/patients', queryParameters: q != null ? {'q': q} : null);
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> getPatient360(String patientId, {int? viewerSpecialtyId}) async {
    final res = await _dio.get(
      '/patients/$patientId',
      queryParameters: viewerSpecialtyId != null ? {'viewerSpecialtyId': viewerSpecialtyId} : null,
    );
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
    final res = await _dio.post(
      '/ai/process-consultation',
      data: {
        'transcript': transcript,
        'patientName': patientName,
        'weightKg': weightKg,
        'specialty': specialty,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}

