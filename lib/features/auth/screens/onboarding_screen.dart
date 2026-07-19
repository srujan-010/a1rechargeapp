import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../core/constants/route_names.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      title: 'Welcome to A1 Recharge',
      description: 'Everything your retail business needs to recharge, pay bills and earn commissions from one secure platform.',
      illustration: const _Slide1Illustration(),
    ),
    _OnboardingSlide(
      title: 'One App. Multiple Services.',
      description: 'Recharge mobiles, DTH, postpaid, electricity, broadband, water, gas and many more services.',
      illustration: const _Slide2Illustration(),
    ),
    _OnboardingSlide(
      title: 'Every Transaction Helps You Earn',
      description: 'Earn commission instantly on eligible services and track your earnings in real time.',
      illustration: const _Slide3Illustration(),
    ),
    _OnboardingSlide(
      title: 'Fast, Secure & Trusted',
      description: 'Secure wallet. Instant receipts. Complete transaction history. Dedicated retailer support.',
      illustration: const _Slide4Illustration(),
    ),
  ];

  void _completeOnboarding() {
    LocalCacheService.instance.settingsBox.put('has_seen_onboarding', true);
    context.go(RouteNames.otpLogin);
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar (Skip Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentPage < _slides.length - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48), // Keep spacing
                ],
              ),
            ),

            // Page View
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: slide.illustration,
                        ),
                        const SizedBox(height: 40),
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Text(
                                slide.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                slide.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation & Indicators
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: _currentPage == _slides.length - 1
                  ? SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'Get Started',
                        onPressed: _completeOnboarding,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dots Indicator
                        Row(
                          children: List.generate(
                            _slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              height: 8,
                              width: _currentPage == index ? 24 : 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? AppColors.primaryBlue
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        
                        // Next Button
                        InkWell(
                          onTap: _nextPage,
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String description;
  final Widget illustration;

  _OnboardingSlide({
    required this.title,
    required this.description,
    required this.illustration,
  });
}

// ─── Slide 1: Welcome (Phone with Floating Icons) ───────────────────
class _Slide1Illustration extends StatefulWidget {
  const _Slide1Illustration();
  @override
  State<_Slide1Illustration> createState() => _Slide1IllustrationState();
}
class _Slide1IllustrationState extends State<_Slide1Illustration> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final float1 = math.sin(_ctrl.value * math.pi) * 10;
        final float2 = math.cos(_ctrl.value * math.pi) * 10;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Background Glow
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryBlue.withOpacity(0.08),
              ),
            ),
            // Central Phone
            _buildPhoneMockup(),
            
            // Floating Icons
            Positioned(
              top: 40 + float1,
              left: 20,
              child: _buildFloatingIcon(Icons.phone_android, Colors.blue),
            ),
            Positioned(
              top: 80 - float2,
              right: 20,
              child: _buildFloatingIcon(Icons.tv, Colors.orange),
            ),
            Positioned(
              bottom: 60 - float1,
              left: 40,
              child: _buildFloatingIcon(Icons.account_balance_wallet, Colors.green),
            ),
            Positioned(
              bottom: 80 + float2,
              right: 40,
              child: _buildFloatingIcon(Icons.electric_bolt, Colors.amber),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildFloatingIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

// ─── Slide 2: Services (Phone surrounded by icons) ──────────────────
class _Slide2Illustration extends StatelessWidget {
  const _Slide2Illustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Connecting Lines (simulated with a large faint circle)
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1), width: 2, style: BorderStyle.solid),
          ),
        ),
        _buildPhoneMockup(),
        
        // Circular arranged icons
        ...List.generate(6, (index) {
          final angle = (index * math.pi * 2) / 6;
          final radius = 110.0;
          final icons = [Icons.water_drop, Icons.wifi, Icons.propane_tank, Icons.receipt_long, Icons.directions_car, Icons.phone];
          final colors = [Colors.blue, Colors.purple, Colors.red, Colors.teal, Colors.indigo, Colors.lightBlue];
          return Transform.translate(
            offset: Offset(radius * math.cos(angle), radius * math.sin(angle)),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icons[index], color: colors[index], size: 20),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Slide 3: Commission (Animated Chips) ───────────────────────────
class _Slide3Illustration extends StatefulWidget {
  const _Slide3Illustration();
  @override
  State<_Slide3Illustration> createState() => _Slide3IllustrationState();
}
class _Slide3IllustrationState extends State<_Slide3Illustration> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
            // Central Wallet Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 40),
            ),
            
            // Commission Chips rising up
            _buildCommissionChip('+₹2.99', 0.0),
            _buildCommissionChip('+₹1.60', 0.33),
            _buildCommissionChip('+₹0.40', 0.66),
          ],
        );
      },
    );
  }
  
  Widget _buildCommissionChip(String amount, double delay) {
    final progress = (_ctrl.value + delay) % 1.0;
    // Rise from bottom (y=80) to top (y=-80)
    final yOffset = 80 - (160 * progress);
    final opacity = math.sin(progress * math.pi); // Fade in and out
    
    return Positioned(
      top: 140 + yOffset,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            amount,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// ─── Slide 4: Trust & Security (Shield) ─────────────────────────────
class _Slide4Illustration extends StatelessWidget {
  const _Slide4Illustration();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
        ),
        // Central Shield
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, Color(0xFF003399)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: const Icon(Icons.security, color: Colors.white, size: 50),
        ),
        
        // Corner Icons
        Positioned(top: 20, left: 40, child: _buildSmallIcon(Icons.history, Colors.blue)),
        Positioned(top: 20, right: 40, child: _buildSmallIcon(Icons.receipt_long, Colors.purple)),
        Positioned(bottom: 20, left: 40, child: _buildSmallIcon(Icons.account_balance_wallet, Colors.green)),
        Positioned(bottom: 20, right: 40, child: _buildSmallIcon(Icons.headset_mic, Colors.orange)),
      ],
    );
  }
  
  Widget _buildSmallIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

// ─── Helper for Slides 1 & 2 ────────────────────────────────────────
Widget _buildPhoneMockup() {
  return Container(
    width: 80,
    height: 160,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200, width: 4),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 30, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        const Spacer(),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: const Center(
            child: Icon(Icons.flash_on, color: AppColors.primaryBlue, size: 30),
          ),
        ),
      ],
    ),
  );
}
