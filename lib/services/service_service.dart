// lib/services/service_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/service_model.dart';

class ServiceService {
  final ApiClient apiClient;

  ServiceService({required this.apiClient});

  Future<Result<List<ServiceModel>>> fetchServices() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.services,
        requireAuth: true,
      );

      // API returns a direct array: [{...}, {...}]
      List<dynamic> servicesList = [];
      
      if (responseData is List) {
        // Response is directly a list
        servicesList = responseData;
      } else if (responseData is Map<String, dynamic>) {
        // Check for 'services' or 'data' key
        if (responseData.containsKey('services')) {
          servicesList = responseData['services'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          servicesList = data is List ? data : [];
        }
      }

      final services = servicesList
          .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(services);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch services: ${e.toString()}');
    }
  }

  // Public method (no auth required)
  Future<Result<List<ServiceModel>>> fetchPublicServices() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicServices,
        requireAuth: false,
      );

      List<dynamic> servicesList = [];
      
      if (responseData is List) {
        servicesList = responseData;
      } else if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('services')) {
          servicesList = responseData['services'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data')) {
          final data = responseData['data'];
          servicesList = data is List ? data : [];
        }
      }

      final services = servicesList
          .map((json) => ServiceModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(services);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch services: ${e.toString()}');
    }
  }
}

