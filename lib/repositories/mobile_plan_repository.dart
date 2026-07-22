import '../models/operator_circle_response.dart';
import '../models/mobile_plan.dart';
import '../models/plan_category.dart';
import '../services/plan_api_service.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/utils/result.dart';

class MobilePlanRepository {
  final PlanApiService _apiService;

  MobilePlanRepository(this._apiService);

  Future<Result<OperatorCircleResponse, AppException>> detectOperator(String mobile) async {
    try {
      final response = await _apiService.detectOperator(mobile);
      return Success(response);
    } on PlanApiException catch (e) {
      return Failure(ServerException(message: e.message));
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }

  Future<Result<List<PlanCategory>, AppException>> fetchMobilePlans(String operatorCode, String circleCode) async {
    print("ENTERED: mobile_plan_repository.dart fetchMobilePlans");
    try {
      final categories = await _apiService.fetchMobilePlans(operatorCode, circleCode);
      return Success(categories);
    } on PlanApiException catch (e) {
      return Failure(ServerException(message: e.message));
    } catch (e) {
      return Failure(UnknownException.from(e));
    }
  }
}
