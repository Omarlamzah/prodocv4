// lib/services/tenant_website_service.dart
import '../core/network/api_client.dart';
import '../core/config/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import '../core/utils/result.dart';
import '../data/models/tenant_website_model.dart';

class TenantWebsiteService {
  final ApiClient apiClient;

  TenantWebsiteService({required this.apiClient});

  Future<Result<TenantWebsiteModel>> getTenantWebsiteConfig() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.tenantWebsiteConfig,
        requireAuth: true,
      );

      final website = TenantWebsiteModel.fromJson(responseData);
      return Success(website);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch tenant website config: $e');
    }
  }

  // Public method to get default tenant website (no auth required)
  Future<Result<TenantWebsiteModel>> getDefaultTenantWebsite() async {
    try {
      final responseData = await apiClient.get(
        ApiConstants.publicTenantWebsiteGetDefault,
        requireAuth: false,
      );

      final website = TenantWebsiteModel.fromJson(responseData);
      return Success(website);
    } on ApiException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Failed to fetch default tenant website: $e');
    }
  }
}
