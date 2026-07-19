import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_theme.dart';
import '../kyc_provider.dart';

class PersonalDetailsForm extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool isReadOnly;

  const PersonalDetailsForm({super.key, required this.onNext, this.isReadOnly = false});

  @override
  ConsumerState<PersonalDetailsForm> createState() => _PersonalDetailsFormState();
}

class _PersonalDetailsFormState extends ConsumerState<PersonalDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dobController;
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(kycProvider);
    final model = state.kycModel;
    final draft = state.draftData;

    _nameController = TextEditingController(text: draft['fullName'] ?? model?.fullName ?? '');
    _dobController = TextEditingController(text: draft['dob'] ?? model?.dob ?? '');
    _addressController = TextEditingController(text: draft['address'] ?? model?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    if (widget.isReadOnly) {
      widget.onNext();
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      ref.read(kycProvider.notifier).updateDraft({
        'fullName': _nameController.text.trim(),
        'dob': _dobController.text.trim(),
        'address': _addressController.text.trim(),
      });
      // Save draft to backend silently (optional, but good for persistence)
      ref.read(kycProvider.notifier).saveKycDraft();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('Full Name', _nameController, widget.isReadOnly),
          _buildTextField('Date of Birth (YYYY-MM-DD)', _dobController, widget.isReadOnly),
          _buildTextField('Complete Address', _addressController, widget.isReadOnly, maxLines: 3),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saveAndNext,
            child: Text(widget.isReadOnly ? 'Next' : 'Save & Continue'),
          ),
        ],
      ),
    );
  }
}

class AadhaarForm extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool isReadOnly;

  const AadhaarForm({super.key, required this.onNext, this.isReadOnly = false});

  @override
  ConsumerState<AadhaarForm> createState() => _AadhaarFormState();
}

class _AadhaarFormState extends ConsumerState<AadhaarForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aadhaarController;
  String? _frontUrl;
  String? _backUrl;
  bool _isUploadingFront = false;
  bool _isUploadingBack = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(kycProvider);
    final model = state.kycModel;
    final draft = state.draftData;

    _aadhaarController = TextEditingController(text: draft['aadhaarNumber'] ?? model?.aadhaarNumber ?? '');
    _frontUrl = draft['aadhaarFront'] ?? model?.aadhaarFront;
    _backUrl = draft['aadhaarBack'] ?? model?.aadhaarBack;
  }

  void _uploadDoc(bool isFront) async {
    if (widget.isReadOnly) return;

    setState(() {
      if (isFront) {
        _isUploadingFront = true;
      } else {
        _isUploadingBack = true;
      }
    });

    final result = await ref.read(kycProvider.notifier).mockOcrExtraction('aadhaar');

    setState(() {
      if (isFront) {
        _isUploadingFront = false;
        _frontUrl = result?['url'];
        if (result?['number'] != null && _aadhaarController.text.isEmpty) {
          _aadhaarController.text = result!['number']!;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aadhaar number auto-filled via OCR')));
        }
      } else {
        _isUploadingBack = false;
        _backUrl = result?['url'];
      }
    });
  }

  void _saveAndNext() {
    if (widget.isReadOnly) {
      widget.onNext();
      return;
    }
    
    if (_frontUrl == null || _backUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload both Front and Back images'), backgroundColor: AppColors.error));
      return;
    }

    if (_formKey.currentState!.validate()) {
      ref.read(kycProvider.notifier).updateDraft({
        'aadhaarNumber': _aadhaarController.text.trim(),
        'aadhaarFront': _frontUrl,
        'aadhaarBack': _backUrl,
      });
      ref.read(kycProvider.notifier).saveKycDraft();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _DocumentUploadBox(
                  title: 'Aadhaar Front',
                  url: _frontUrl,
                  isLoading: _isUploadingFront,
                  onTap: () => _uploadDoc(true),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DocumentUploadBox(
                  title: 'Aadhaar Back',
                  url: _backUrl,
                  isLoading: _isUploadingBack,
                  onTap: () => _uploadDoc(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField('Aadhaar Number', _aadhaarController, widget.isReadOnly),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saveAndNext,
            child: Text(widget.isReadOnly ? 'Next' : 'Save & Continue'),
          ),
        ],
      ),
    );
  }
}

class PanForm extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool isReadOnly;

  const PanForm({super.key, required this.onNext, this.isReadOnly = false});

  @override
  ConsumerState<PanForm> createState() => _PanFormState();
}

class _PanFormState extends ConsumerState<PanForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _panController;
  String? _panUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(kycProvider);
    final model = state.kycModel;
    final draft = state.draftData;

    _panController = TextEditingController(text: draft['panNumber'] ?? model?.panNumber ?? '');
    _panUrl = draft['panImage'] ?? model?.panImage;
  }

  void _uploadDoc() async {
    if (widget.isReadOnly) return;

    setState(() => _isUploading = true);
    final result = await ref.read(kycProvider.notifier).mockOcrExtraction('pan');
    setState(() {
      _isUploading = false;
      _panUrl = result?['url'];
      if (result?['number'] != null && _panController.text.isEmpty) {
        _panController.text = result!['number']!;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PAN number auto-filled via OCR')));
      }
    });
  }

  void _saveAndNext() {
    if (widget.isReadOnly) {
      widget.onNext();
      return;
    }
    
    if (_panUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload PAN image'), backgroundColor: AppColors.error));
      return;
    }

    if (_formKey.currentState!.validate()) {
      ref.read(kycProvider.notifier).updateDraft({
        'panNumber': _panController.text.trim().toUpperCase(),
        'panImage': _panUrl,
      });
      ref.read(kycProvider.notifier).saveKycDraft();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DocumentUploadBox(
            title: 'PAN Image',
            url: _panUrl,
            isLoading: _isUploading,
            onTap: _uploadDoc,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTextField('PAN Number', _panController, widget.isReadOnly),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saveAndNext,
            child: Text(widget.isReadOnly ? 'Next' : 'Save & Continue'),
          ),
        ],
      ),
    );
  }
}

class ShopForm extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final bool isReadOnly;

  const ShopForm({super.key, required this.onNext, this.isReadOnly = false});

  @override
  ConsumerState<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends ConsumerState<ShopForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _shopNameController;
  late TextEditingController _businessTypeController;
  late TextEditingController _gstController;
  String? _shopUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(kycProvider);
    final model = state.kycModel;
    final draft = state.draftData;

    _shopNameController = TextEditingController(text: draft['shopName'] ?? model?.shopName ?? '');
    _businessTypeController = TextEditingController(text: draft['businessType'] ?? model?.businessType ?? '');
    _gstController = TextEditingController(text: draft['gstNumber'] ?? model?.gstNumber ?? '');
    _shopUrl = draft['shopPhoto'] ?? model?.shopPhoto;
  }

  void _uploadDoc() async {
    if (widget.isReadOnly) return;
    setState(() => _isUploading = true);
    final result = await ref.read(kycProvider.notifier).mockOcrExtraction('shop');
    setState(() {
      _isUploading = false;
      _shopUrl = result?['url'];
    });
  }

  void _saveAndNext() {
    if (widget.isReadOnly) {
      widget.onNext();
      return;
    }
    
    if (_shopUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload Shop Photo'), backgroundColor: AppColors.error));
      return;
    }

    if (_formKey.currentState!.validate()) {
      ref.read(kycProvider.notifier).updateDraft({
        'shopName': _shopNameController.text.trim(),
        'businessType': _businessTypeController.text.trim(),
        'gstNumber': _gstController.text.trim().toUpperCase(),
        'shopPhoto': _shopUrl,
      });
      ref.read(kycProvider.notifier).saveKycDraft();
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('Shop Name', _shopNameController, widget.isReadOnly),
          _buildTextField('Business Type', _businessTypeController, widget.isReadOnly),
          _buildTextField('GST Number (Optional)', _gstController, widget.isReadOnly, required: false),
          const SizedBox(height: AppSpacing.md),
          _DocumentUploadBox(
            title: 'Shop Photo',
            url: _shopUrl,
            isLoading: _isUploading,
            onTap: _uploadDoc,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: _saveAndNext,
            child: Text(widget.isReadOnly ? 'Next' : 'Save & Continue'),
          ),
        ],
      ),
    );
  }
}

class SelfieForm extends ConsumerStatefulWidget {
  final VoidCallback onSubmit;
  final bool isReadOnly;

  const SelfieForm({super.key, required this.onSubmit, this.isReadOnly = false});

  @override
  ConsumerState<SelfieForm> createState() => _SelfieFormState();
}

class _SelfieFormState extends ConsumerState<SelfieForm> {
  String? _selfieUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(kycProvider);
    _selfieUrl = state.draftData['selfie'] ?? state.kycModel?.selfie;
  }

  void _uploadDoc() async {
    if (widget.isReadOnly) return;
    setState(() => _isUploading = true);
    final result = await ref.read(kycProvider.notifier).mockOcrExtraction('selfie');
    setState(() {
      _isUploading = false;
      _selfieUrl = result?['url'];
    });
  }

  void _submit() {
    if (widget.isReadOnly) return;
    
    if (_selfieUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please take a selfie'), backgroundColor: AppColors.error));
      return;
    }
    ref.read(kycProvider.notifier).updateDraft({'selfie': _selfieUrl});
    widget.onSubmit(); // This will trigger final submit
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocumentUploadBox(
          title: 'Live Selfie',
          url: _selfieUrl,
          isLoading: _isUploading,
          onTap: _uploadDoc,
          icon: Icons.camera_alt,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!widget.isReadOnly)
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Submit Full KYC', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}


// --- Helpers ---

Widget _buildTextField(String label, TextEditingController controller, bool readOnly, {int maxLines = 1, bool required = true}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : null,
      ),
      validator: required ? (val) {
        if (val == null || val.trim().isEmpty) return 'Required';
        return null;
      } : null,
    ),
  );
}

class _DocumentUploadBox extends StatelessWidget {
  final String title;
  final String? url;
  final bool isLoading;
  final VoidCallback onTap;
  final IconData icon;

  const _DocumentUploadBox({
    required this.title,
    this.url,
    required this.isLoading,
    required this.onTap,
    this.icon = Icons.upload_file,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : url != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const ColoredBox(color: AppColors.primaryBlueLight, child: Center(child: Icon(Icons.image, size: 50, color: AppColors.primaryBlue))),
                  ),
                  const Positioned(
                    top: 8, right: 8,
                    child: Icon(Icons.check_circle, color: AppColors.success),
                  ),
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                      child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    )
                  )
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primaryBlue, size: 32),
                  const SizedBox(height: 8),
                  Text(title, style: AppTextTheme.textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}
