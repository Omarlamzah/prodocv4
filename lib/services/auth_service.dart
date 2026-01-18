// lib/services/auth_service.dart - Complete Updated Version
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/user_model.dart';

class AuthService {
  final ApiClient apiClient;

  AuthService({required this.apiClient});

  // Check if user is authenticated
  Future<Result<UserModel>> checkAuth() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.getUser,
        requireAuth: true,
      );

      final user = UserModel.fromJson(responseData['user'] ?? responseData);
      return Success(user);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Authentication check failed: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    try {
      print('🔐 Auth Service Login:');
      print('  - Email: $email');
      print('  - Phone: $phone');
      print('  - Password: ${password.isNotEmpty ? "***" : "empty"}');

      // Build payload with whichever identifier is provided
      // Note: Backend requires email field even when using phone login
      // So we send empty string for email when phone is provided
      final Map<String, dynamic> body = {
        'password': password,
        if (email != null && email.isNotEmpty)
          'email': email
        else if (phone != null && phone.isNotEmpty)
          'email':
              '', // Send empty email when using phone (backend requirement)
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      };

      print('  - Request Body: $body');

      if (!body.containsKey('phone') && (email == null || email.isEmpty)) {
        print('  - ❌ Error: Neither email nor phone provided');
        return Failure('Email or phone is required');
      }

      print('  - ✅ Sending login request...');
      final responseData = await apiClient.post(
        ApiConstants.login,
        body: body,
        requireAuth: false,
      );

      print('  - ✅ Login successful');
      return Success(responseData);
    } on ApiException catch (e) {
      print('  - ❌ API Exception: ${e.message}');
      print('  - ❌ API Exception Data: ${e.data}');
      return Failure(e.message);
    } catch (e) {
      print('  - ❌ General Exception: $e');
      return Failure('Login failed: $e');
    }
  }

  Future<Result<Map<String, dynamic>>> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? phone,
    String? address,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final body = {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (phone != null) 'phone': phone,
        if (address != null) 'address': address,
        ...?additionalData,
      };

      final responseData = await apiClient.post(
        ApiConstants.register,
        body: body,
        requireAuth: false,
      );

      return Success(responseData);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Registration failed: $e');
    }
  }

  Future<Result<String>> forgotPassword(String email) async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.forgotPassword,
        body: {'email': email},
        requireAuth: false,
      );

      final message = responseData['message'] ?? 'Password reset email sent';
      return Success(message);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to send reset email: $e');
    }
  }

  Future<Result<UserModel>> getUser() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.getUser,
        requireAuth: true,
      );

      final user = UserModel.fromJson(responseData['user'] ?? responseData);
      return Success(user);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to get user: $e');
    }
  }

  Future<Result<String>> logout() async {
    try {
      final responseData = await apiClient.post(
        ApiConstants.logout,
        requireAuth: true,
      );

      return Success(responseData['message'] ?? 'Logged out successfully');
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Logout failed: $e');
    }
  }
}
