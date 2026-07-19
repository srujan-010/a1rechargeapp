import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/models/bank_details.dart';

enum BankDetailsStatus { loading, empty, populated, error }

class BankDetailsState {
  final BankDetailsStatus status;
  final BankDetails? bankDetails;
  final String? errorMessage;
  final bool isSaving;
  final bool isDeleting;

  BankDetailsState({
    this.status = BankDetailsStatus.loading,
    this.bankDetails,
    this.errorMessage,
    this.isSaving = false,
    this.isDeleting = false,
  });

  BankDetailsState copyWith({
    BankDetailsStatus? status,
    BankDetails? bankDetails,
    String? errorMessage,
    bool? isSaving,
    bool? isDeleting,
  }) {
    return BankDetailsState(
      status: status ?? this.status,
      bankDetails: bankDetails ?? this.bankDetails,
      errorMessage: errorMessage, // We want to be able to set it to null implicitly sometimes, but usually we just copy it unless overridden or reset.
      isSaving: isSaving ?? this.isSaving,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

class BankDetailsNotifier extends StateNotifier<BankDetailsState> {
  final Ref ref;

  BankDetailsNotifier(this.ref) : super(BankDetailsState()) {
    fetchBankDetails();
  }

  Future<void> fetchBankDetails() async {
    state = state.copyWith(status: BankDetailsStatus.loading, errorMessage: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/bank',
        fromJson: (json) => BankDetails.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        state = state.copyWith(status: BankDetailsStatus.populated, bankDetails: response.data);
      } else {
        state = state.copyWith(status: BankDetailsStatus.empty);
      }
    } catch (e) {
      // If 404, it means no bank is added yet.
      if (e is DioException && e.response?.statusCode == 404) {
        state = state.copyWith(status: BankDetailsStatus.empty);
      } else {
        state = state.copyWith(status: BankDetailsStatus.error, errorMessage: e.toString());
      }
    }
  }

  Future<bool> saveBankDetails(BankDetails details, {String? mpin}) async {
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      
      final data = details.toJson();
      if (mpin != null) {
        data['mpin'] = mpin;
      }

      final response = await apiClient.post(
        '/bank',
        data: data,
        fromJson: (json) => BankDetails.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          isSaving: false,
          status: BankDetailsStatus.populated,
          bankDetails: response.data,
        );
        return true;
      } else {
        state = state.copyWith(isSaving: false, errorMessage: response.message ?? 'Failed to save bank details');
        return false;
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null && e.response!.data['message'] != null) {
        msg = e.response!.data['message'];
      }
      state = state.copyWith(isSaving: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> deleteBankDetails(String mpin) async {
    state = state.copyWith(isDeleting: true, errorMessage: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.delete(
        '/bank',
        data: {'mpin': mpin},
        fromJson: (json) => json,
      );

      if (response.success) {
        state = state.copyWith(
          isDeleting: false,
          status: BankDetailsStatus.empty,
          bankDetails: null,
        );
        return true;
      } else {
        state = state.copyWith(isDeleting: false, errorMessage: response.message ?? 'Failed to delete bank details');
        return false;
      }
    } catch (e) {
      String msg = e.toString();
      if (e is DioException && e.response?.data != null && e.response!.data['message'] != null) {
        msg = e.response!.data['message'];
      }
      state = state.copyWith(isDeleting: false, errorMessage: msg);
      return false;
    }
  }

  // Helper method for IFSC lookup using razorpay public API
  Future<Map<String, dynamic>?> lookupIfsc(String ifsc) async {
    try {
      final dio = Dio();
      final response = await dio.get('https://ifsc.razorpay.com/$ifsc');
      if (response.statusCode == 200) {
        return response.data; // contains BANK, BRANCH, CITY, STATE, etc.
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

final bankDetailsProvider = StateNotifierProvider<BankDetailsNotifier, BankDetailsState>((ref) {
  return BankDetailsNotifier(ref);
});
