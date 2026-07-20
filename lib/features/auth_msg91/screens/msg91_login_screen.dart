import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../providers/msg91_auth_provider.dart';

// --- Color Tokens ---
const Color bannerBlueStart = Color(0xFF2F6BFF);
const Color bannerBlueEnd = Color(0xFF1747C4);
const Color textBlue = Color(0xFF1E56E8);
const Color accentGreen = Color(0xFF4CAF50);
const Color bodyBg = Color(0xFFFFFFFF);
const Color subtextGrey = Color(0xFF6B7280);
const Color inputBorder = Color(0xFFE2E5EA);

class Msg91LoginScreen extends ConsumerStatefulWidget {
  const Msg91LoginScreen({super.key});

  @override
  ConsumerState<Msg91LoginScreen> createState() => _Msg91LoginScreenState();
}

class _Msg91LoginScreenState extends ConsumerState<Msg91LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isPhoneValid = false;
  bool _isFocused = false;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) {
    final isValid = val.length == 10;
    if (_isPhoneValid != isValid) {
      setState(() => _isPhoneValid = isValid);
      if (isValid) HapticFeedback.lightImpact();
    }
  }

  void _submit() {
    if (_isPhoneValid) {
      HapticFeedback.mediumImpact();
      _focusNode.unfocus();
      final phone = _phoneController.text.trim();
      ref.read(msg91AuthProvider.notifier).sendOtp(phone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(msg91AuthProvider);
    final isLoading = authState.isLoading;

    ref.listen(msg91AuthProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!), 
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.isOtpSent && !(previous?.isOtpSent ?? false)) {
        // Go router sub-route for MSG91
        context.push('${RouteNames.otpLogin}/verify', extra: {
          'phone': _phoneController.text.trim(),
        });
      }
    });

    return Scaffold(
      backgroundColor: bodyBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bannerHeight = constraints.maxHeight * 0.22;
          
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  children: [
                    SizedBox(
                      height: bannerHeight + 40,
                      child: Stack(
                        children: [
                          ClipPath(
                            clipper: _WaveClipper(),
                            child: Container(
                              height: bannerHeight,
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [bannerBlueStart, bannerBlueEnd],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 48,
                            left: 24,
                            child: Text(
                              'MSG91',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: ClipPath(
                              clipper: _TriangleClipper(),
                              child: Container(
                                width: 40,
                                height: 40,
                                color: accentGreen,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                height: 80,
                                width: 80,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(40),
                                  child: Image.network(
                                    'https://res.cloudinary.com/dixbhnqnf/image/upload/v1783948537/ChatGPT_Image_Jul_13_2026_06_44_20_PM-Photoroom_crnosm.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.bolt, size: 40, color: textBlue),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: const [
                          Text(
                            'Welcome Retailer',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textBlue),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'One app for all your recharge\nand payment needs.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: subtextGrey, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _isFocused ? textBlue : inputBorder,
                                width: _isFocused ? 1.5 : 1,
                              ),
                              boxShadow: _isFocused ? [
                                BoxShadow(color: textBlue.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))
                              ] : [],
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Image.network('https://flagcdn.com/w40/in.png', width: 20),
                                      const SizedBox(width: 8),
                                      const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 24, color: inputBorder),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF111827), letterSpacing: 1.0),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged: _onPhoneChanged,
                                    enabled: !isLoading,
                                    decoration: InputDecoration(
                                      hintText: 'Mobile Number',
                                      hintStyle: const TextStyle(fontSize: 15, color: subtextGrey, fontWeight: FontWeight.normal, letterSpacing: 0),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      suffixIcon: _phoneController.text.isNotEmpty && !isLoading
                                          ? IconButton(
                                              icon: const Icon(Icons.cancel, color: Color(0xFFD1D5DB), size: 20),
                                              onPressed: () {
                                                HapticFeedback.selectionClick();
                                                _phoneController.clear();
                                                _onPhoneChanged('');
                                              },
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          GestureDetector(
                            onTapDown: (_) => setState(() => _isButtonPressed = true),
                            onTapUp: (_) {
                              setState(() => _isButtonPressed = false);
                              if (_isPhoneValid && !isLoading) _submit();
                            },
                            onTapCancel: () => setState(() => _isButtonPressed = false),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: _isPhoneValid && !isLoading ? 1.0 : 0.4,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  gradient: const LinearGradient(colors: [bannerBlueStart, bannerBlueEnd]),
                                  boxShadow: _isPhoneValid ? [
                                    BoxShadow(color: bannerBlueEnd.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                                  ] : [],
                                ),
                                child: Center(
                                  child: isLoading
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('Get OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                            const SizedBox(width: 8),
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              curve: Curves.easeOut,
                                              transform: Matrix4.translationValues(_isButtonPressed ? 4.0 : 0.0, 0, 0),
                                              child: const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Column(
                            children: const [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.lock, size: 14, color: accentGreen),
                                  SizedBox(width: 6),
                                  Text('Secure OTP Login', style: TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.bold)),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text('Bank-grade security', style: TextStyle(fontSize: 12, color: subtextGrey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(flex: 2),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: const [
                          _IconLabel(icon: Icons.bolt_outlined, label: 'Recharge'),
                          _IconLabel(icon: Icons.receipt_long_outlined, label: 'Pay Bills'),
                          _IconLabel(icon: Icons.workspace_premium_outlined, label: 'Earn More'),
                        ],
                      ),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  
  const _IconLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: textBlue.withValues(alpha: 0.15), width: 1.5),
          ),
          child: Icon(icon, size: 24, color: textBlue),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: subtextGrey, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    
    final controlPoint = Offset(size.width * 0.7, size.height);
    final endPoint = Offset(size.width, size.height - 40);
    
    path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
    path.lineTo(size.width, 0);
    path.close();
    
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
