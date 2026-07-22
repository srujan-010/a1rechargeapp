import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';
import '../../../services/plan_api_service.dart';
import '../../../models/operator_circle_response.dart';
import '../../../models/plan_category.dart';
import '../domain/models/dth_customer_info.dart';

class DthPlanRepository {
  final PlanApiService _apiService;

  DthPlanRepository(this._apiService);

  Future<Result<OperatorCircleResponse, AppException>> fetchDthOperator(String subscriberId) async {
    try {
      final response = await _apiService.fetchDthOperator(subscriberId);
      return Success(response);
    } on PlanApiException catch (e) {
      return Failure(ServerException(message: e.message));
    } catch (e) {
      return Failure(ServerException(message: 'An unexpected error occurred while fetching DTH operator'));
    }
  }

  Future<Result<DthCustomerInfo, AppException>> fetchDthBasicDetails(String subscriberId, String operatorCode) async {
    try {
      final response = await _apiService.fetchDthBasicDetails(subscriberId, operatorCode);
      return Success(response);
    } on PlanApiException catch (e) {
      return Failure(ServerException(message: e.message));
    } catch (e) {
      return Failure(ServerException(message: 'An unexpected error occurred while fetching DTH customer info'));
    }
  }

  Future<Result<List<PlanCategory>, AppException>> fetchDthPlans(String operatorCode) async {
    try {
      final response = await _apiService.fetchDthPlans(operatorCode);
      return Success(response);
    } on PlanApiException catch (e) {
      return Failure(ServerException(message: e.message));
    } catch (e) {
      return Failure(ServerException(message: 'An unexpected error occurred while fetching DTH plans'));
    }
  }
}
