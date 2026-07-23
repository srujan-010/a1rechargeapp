import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/providers/core_providers.dart';
import '../domain/models/kyc_model.dart';

enum KycStatus { loading, idle, error, saving }

class KycState {
  final KycStatus status;
  final KycModel? kycModel;
  final String? errorMessage;
  final int currentStep;
  final Map<String, dynamic> draftData; // In-memory draft for forms

  KycState({
    this.status = KycStatus.loading,
    this.kycModel,
    this.errorMessage,
    this.currentStep = 0,
    this.draftData = const {},
  });

  KycState copyWith({
    KycStatus? status,
    KycModel? kycModel,
    String? errorMessage,
    int? currentStep,
    Map<String, dynamic>? draftData,
  }) {
    return KycState(
      status: status ?? this.status,
      kycModel: kycModel ?? this.kycModel,
      errorMessage: errorMessage,
      currentStep: currentStep ?? this.currentStep,
      draftData: draftData ?? this.draftData,
    );
  }
}

class KycNotifier extends StateNotifier<KycState> {
  final Ref ref;

  KycNotifier(this.ref) : super(KycState()) {
    fetchKycDetails();
  }

  Future<void> fetchKycDetails() async {
    state = state.copyWith(status: KycStatus.loading, errorMessage: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        '/kyc',
        fromJson: (json) => KycModel.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        state = state.copyWith(status: KycStatus.idle, kycModel: response.data);
      } else {
        state = state.copyWith(status: KycStatus.idle);
      }
    } catch (e) {
      if (e is AppException && e.message.contains('404')) {
        state = state.copyWith(status: KycStatus.idle, kycModel: KycModel());
      } else {
        state = state.copyWith(status: KycStatus.error, errorMessage: e.toString());
      }
    }
  }

  void updateDraft(Map<String, dynamic> data) {
    final newDraft = Map<String, dynamic>.from(state.draftData)..addAll(data);
    state = state.copyWith(draftData: newDraft);
  }
  
  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  Future<bool> saveKycDraft({bool isFinalSubmit = false}) async {
    state = state.copyWith(status: KycStatus.saving, errorMessage: null);
    try {
      final apiClient = ref.read(apiClientProvider);
      
      final payload = Map<String, dynamic>.from(state.draftData);
      if (isFinalSubmit) {
        payload['isFinalSubmit'] = true;
      }

      final response = await apiClient.post(
        '/kyc',
        data: payload,
        fromJson: (json) => KycModel.fromJson(json as Map<String, dynamic>),
      );

      if (response.success && response.data != null) {
        state = state.copyWith(
          status: KycStatus.idle,
          kycModel: response.data,
          draftData: {}, // clear draft on successful save
        );
        return true;
      } else {
        state = state.copyWith(status: KycStatus.idle, errorMessage: response.message ?? 'Failed to save KYC');
        return false;
      }
    } catch (e) {
      String msg = 'Failed to save KYC';
      if (e is AppException) {
        msg = e.message;
      }
      state = state.copyWith(status: KycStatus.idle, errorMessage: msg);
      return false;
    }
  }

  // MOCK: Simulate uploading an image and extracting OCR text
  Future<Map<String, String>?> mockOcrExtraction(String docType) async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (docType == 'aadhaar') {
      return {
        'url': 'https://mock.upload.url/aadhaar.jpg',
        'number': '123456789012',
        'name': 'Rahul Kumar',
        'dob': '1990-01-01',
      };
    } else if (docType == 'pan') {
      return {
        'url': 'https://mock.upload.url/pan.jpg',
        'number': 'ABCDE1234F',
        'name': 'Rahul Kumar',
      };
    }
    
    return {'url': 'https://mock.upload.url/image.jpg'};
  }
}

final kycProvider = StateNotifierProvider<KycNotifier, KycState>((ref) {
  return KycNotifier(ref);
});
