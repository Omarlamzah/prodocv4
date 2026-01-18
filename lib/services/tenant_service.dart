// lib/services/tenant_service.dart - Add search parameter
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/tenant_model.dart';

class TenantService {
  final ApiClient apiClient;

  TenantService({required this.apiClient});

  Future<Result<List<TenantModel>>> getAllTenants({String? search}) async {
    try {
      // Build query parameters
      final queryParams = search != null && search.isNotEmpty
          ? {'search': search}
          : null;

      // Use requireAuth: false since this is before login
      final responseData = await apiClient.get(
        ApiConstants.getAllTenants,
        requireAuth: false,
        queryParameters: queryParams,
      );

      final List<dynamic> tenantsJson = responseData['data'] ?? responseData['tenants'] ?? [];
      final tenants = tenantsJson
          .map((json) => TenantModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Success(tenants);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to load tenants: $e');
    }
  }
}