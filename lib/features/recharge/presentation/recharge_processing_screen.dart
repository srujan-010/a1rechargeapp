import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/logger.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../domain/models/recharge_result.dart';
import 'recharge_providers.dart';

class RechargeProcessingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const RechargeProcessingScreen({super.key, required this.data});

  @override
  ConsumerState<RechargeProcessingScreen> createState() => _RechargeProcessingScreenState();
}

class _RechargeProcessingScreenState extends ConsumerState<RechargeProcessingScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _orbitController;
  late AnimationController _signalController;
  late AnimationController _pulseController;
  late AnimationController _successController;

  Timer? _messageTimer;
  Timer? _pollingTimer;
  Timer? _timeoutTimer;

  int _messageIndex = 0;
  int _currentStep = 1; // 0: Wallet, 1: Request, 2: Operator, 3: Finalizing
  bool _isNavigated = false;
  bool _isSuccess = false;

  final List<String> _statusMessages = [
    'Verifying Wallet...',
    'Sending Recharge...',
    'Connecting to Operator...',
    'Finalizing Recharge...',
  ];

  RechargeReceipt? _activeReceipt;

  @override
  void initState() {
    super.initState();

    // Orbiting dot controller (2 seconds infinite loop)
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Signal waves expansion controller (1.5 seconds infinite loop)
    _signalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Active step ring pulsing controller (1 second infinite loop)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Success checkmark celebration controller
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startMessageRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initiateRecharge();
      }
    });
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (!mounted || _isSuccess) return;
      setState(() {
        _messageIndex = (_messageIndex + 1) % _statusMessages.length;
        if (_messageIndex == 0) _currentStep = 0;
        if (_messageIndex == 1) _currentStep = 1;
        if (_messageIndex == 2) _currentStep = 2;
        if (_messageIndex == 3) _currentStep = 3;
      });
    });
  }

  Future<void> _initiateRecharge() async {
    final mpin = widget.data['mpin'] as String?;
    final paymentMode = (widget.data['paymentMode'] as String?) ?? 'wallet';

    try {
      debugPrint('[FLOW] Processing State');
      final receipt = await ref.read(rechargeFlowProvider.notifier).processRecharge(
            mpin: mpin,
            paymentMode: paymentMode,
          );

      _activeReceipt = receipt;

      if (!mounted) return;

      if (receipt.isSuccess) {
        _handleSuccess(receipt);
      } else if (receipt.status == RechargeStatus.failed) {
        _handleFailure(receipt);
      } else {
        // Status is PENDING.
        // Start 35-second timeout window & poll every 1.0 second
        _startPendingPolling(receipt.transactionId);
      }
    } catch (e) {
      AppLogger.error('Recharge initiation exception: $e', tag: 'RechargeProcessing');
      if (!mounted) return;
      _handleError(e.toString());
    }
  }

  void _startPendingPolling(String orderId) {
    const timeoutSeconds = 35;
    final startTime = DateTime.now();

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isNavigated || !mounted) return;

      try {
        final repo = ref.read(rechargeRepositoryProvider);
        final result = await repo.checkRechargeStatus(orderId);
        final latestReceipt = result.valueOrNull;

        if (latestReceipt != null) {
          if (latestReceipt.isSuccess) {
            timer.cancel();
            _handleSuccess(latestReceipt);
            return;
          } else if (latestReceipt.status == RechargeStatus.failed) {
            timer.cancel();
            _handleFailure(latestReceipt);
            return;
          }
        }
      } catch (e) {
        AppLogger.warning('Status polling attempt failed: $e', tag: 'RechargeProcessing');
      }

      // Check if 35s elapsed
      if (DateTime.now().difference(startTime).inSeconds >= timeoutSeconds) {
        timer.cancel();
        _handleTimeoutPending();
      }
    });

    _timeoutTimer = Timer(const Duration(seconds: timeoutSeconds), () {
      if (!_isNavigated && mounted) {
        _pollingTimer?.cancel();
        _handleTimeoutPending();
      }
    });
  }

  void _handleSuccess(RechargeReceipt receipt) async {
    if (_isNavigated) return;

    setState(() {
      _isSuccess = true;
      _currentStep = 3;
    });

    _cancelTimers();
    await _successController.forward();
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    _isNavigated = true;

    debugPrint('[FLOW] Provider Update');
    // Invalidate wallet & transaction providers
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(earningsSummaryProvider);

    debugPrint('[FLOW] Navigation');
    context.go(RouteNames.dashboard);
    context.push(
      RouteNames.rechargeReceipt.replaceFirst(':txnId', receipt.transactionId),
      extra: receipt,
    );
  }

  void _handleFailure(RechargeReceipt receipt) {
    if (_isNavigated) return;
    _isNavigated = true;
    _cancelTimers();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[FLOW] Provider Update');
      ref.invalidate(walletBalanceProvider);

      debugPrint('[FLOW] Navigation');
      context.go(RouteNames.rechargeFailed, extra: receipt);
    });
  }

  void _handleError(String errorMsg) {
    if (_isNavigated) return;
    _isNavigated = true;
    _cancelTimers();

    final fallbackReceipt = RechargeReceipt(
      transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      referenceId: 'REF${DateTime.now().millisecondsSinceEpoch}',
      operatorRef: 'N/A',
      status: RechargeStatus.failed,
      amountPaise: widget.data['amountPaise'] as int? ?? 0,
      mobileNumber: widget.data['phoneNumber'] as String? ?? '',
      operatorName: widget.data['operatorName'] as String? ?? 'Operator',
      timestamp: DateTime.now(),
      failureReason: errorMsg,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[FLOW] Navigation');
      context.go(RouteNames.rechargeFailed, extra: fallbackReceipt);
    });
  }

  void _handleTimeoutPending() {
    if (_isNavigated) return;
    _isNavigated = true;
    _cancelTimers();

    final receipt = _activeReceipt ??
        RechargeReceipt(
          transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}',
          referenceId: 'REF${DateTime.now().millisecondsSinceEpoch}',
          operatorRef: 'Processing...',
          status: RechargeStatus.pending,
          amountPaise: widget.data['amountPaise'] as int? ?? 0,
          mobileNumber: widget.data['phoneNumber'] as String? ?? '',
          operatorName: widget.data['operatorName'] as String? ?? 'Operator',
          timestamp: DateTime.now(),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[FLOW] Navigation');
      context.go(RouteNames.rechargePending, extra: receipt);
    });
  }

  void _cancelTimers() {
    _messageTimer?.cancel();
    _pollingTimer?.cancel();
    _timeoutTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelTimers();
    _orbitController.dispose();
    _signalController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amountPaise = widget.data['amountPaise'] as int? ?? 23900;
    final phoneNumber = widget.data['phoneNumber'] as String? ?? '8309628088';
    final operatorName = widget.data['operatorName'] as String? ?? 'Reliance Jio';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF0F6FF),
                Color(0xFFF8FAFC),
                Colors.white,
              ],
              stops: [0.0, 0.4, 1.0],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // ── TOP NAVIGATION & HEADER ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          // Prevent accidental back navigation during processing
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please wait while your recharge is processing...'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Processing Recharge',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 40), // Balances the back button
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── CENTER ANIMATION CIRCLE ──
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Custom Painter for Outer Segmented Ring & Revolving Glowing Dot
                          AnimatedBuilder(
                            animation: _orbitController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(250, 250),
                                painter: _OuterRingPainter(
                                  progress: _orbitController.value,
                                  isSuccess: _isSuccess,
                                  successProgress: _successController.value,
                                ),
                              );
                            },
                          ),

                          // Inner Content: Telecom Tower & Signal Waves OR Success Checkmark
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _isSuccess
                                ? AnimatedBuilder(
                                    animation: _successController,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: CurvedAnimation(
                                          parent: _successController,
                                          curve: Curves.elasticOut,
                                        ).value,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF10B981),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                                blurRadius: 20,
                                                spreadRadius: 4,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : AnimatedBuilder(
                                    animation: _signalController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        size: const Size(190, 190),
                                        painter: _TelecomTowerPainter(
                                          signalValue: _signalController.value,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── AMOUNT & OPERATOR INFO ──
                  Text(
                    CurrencyFormatter.fromPaise(amountPaise),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$operatorName • $phoneNumber',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── STATUS CARD (VERTICAL TIMELINE) ──
                  _StatusTimelineCard(
                    currentStep: _currentStep,
                    pulseAnimation: _pulseController,
                    isSuccess: _isSuccess,
                  ),

                  const SizedBox(height: 16),

                  // ── SAFE & SECURE CARD ──
                  const _SafeCard(),

                  const SizedBox(height: 20),

                  // ── BOTTOM ANIMATED STATUS TEXT & FOOTER ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      _isSuccess ? 'Recharge Successful!' : _statusMessages[_messageIndex],
                      key: ValueKey<String>(_isSuccess ? 'success' : _statusMessages[_messageIndex]),
                      style: TextStyle(
                        color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'This will only take a few seconds',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── CUSTOM PAINTER: OUTER RING WITH REVOLVING GLOWING DOT ──
class _OuterRingPainter extends CustomPainter {
  final double progress;
  final bool isSuccess;
  final double successProgress;

  _OuterRingPainter({
    required this.progress,
    required this.isSuccess,
    required this.successProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 10;

    // 1. Background Track
    final trackPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    if (isSuccess) {
      // Transition whole ring to solid Green
      final successPaint = Paint()
        ..color = Color.lerp(const Color(0xFF2563EB), const Color(0xFF10B981), successProgress)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, successPaint);
      return;
    }

    // Draw background track
    canvas.drawCircle(center, radius, trackPaint);

    // 2. Blue Progress Arcs (Segmented look)
    final arcPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    // Segments: 3 primary active arcs around the circle
    const startAngle1 = -math.pi / 2;
    const sweepAngle1 = math.pi * 0.45;

    const startAngle2 = math.pi * 0.2;
    const sweepAngle2 = math.pi * 0.55;

    const startAngle3 = math.pi * 0.95;
    const sweepAngle3 = math.pi * 0.35;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle1, sweepAngle1, false, arcPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle2, sweepAngle2, false, arcPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle3, sweepAngle3, false, arcPaint);

    // 3. Revolving Glowing Blue Dot
    final currentAngle = (progress * 2 * math.pi) - (math.pi / 2);
    final dotDx = center.dx + radius * math.cos(currentAngle);
    final dotDy = center.dy + radius * math.sin(currentAngle);
    final dotCenter = Offset(dotDx, dotDy);

    // Outer Glow Shadow
    final glowPaint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(dotCenter, 8, glowPaint);

    // Inner Glowing Core Dot
    final dotPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, 5, dotPaint);

    // Highlight Center White Dot
    final innerWhiteDot = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dotCenter, 2, innerWhiteDot);
  }

  @override
  bool shouldRepaint(covariant _OuterRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSuccess != isSuccess ||
        oldDelegate.successProgress != successProgress;
  }
}

// ── CUSTOM PAINTER: TELECOM TOWER & SIGNAL ANIMATION ──
class _TelecomTowerPainter extends CustomPainter {
  final double signalValue;

  _TelecomTowerPainter({required this.signalValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final towerWidth = size.width * 0.38;
    final towerHeight = size.height * 0.48;

    // 1. Subtle Skyline & Cloud Silhouette Background (Creates depth)
    _drawSkylineBackground(canvas, size, center);

    // 2. Modern Vector Telecom Tower Structure
    final towerPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final towerTop = Offset(center.dx, center.dy - towerHeight * 0.48);
    final towerBottomLeft = Offset(center.dx - towerWidth * 0.45, center.dy + towerHeight * 0.42);
    final towerBottomRight = Offset(center.dx + towerWidth * 0.45, center.dy + towerHeight * 0.42);

    // Main Outer Legs
    canvas.drawLine(towerTop, towerBottomLeft, towerPaint);
    canvas.drawLine(towerTop, towerBottomRight, towerPaint);
    canvas.drawLine(towerBottomLeft, towerBottomRight, towerPaint);

    // Horizontal Crossbeams (3 levels)
    for (int i = 1; i <= 3; i++) {
      final ratio = i / 4.0;
      final y = towerTop.dy + (towerHeight * 0.9 * ratio);
      final leftX = towerTop.dx - (towerWidth * 0.45 * ratio);
      final rightX = towerTop.dx + (towerWidth * 0.45 * ratio);
      canvas.drawLine(Offset(leftX, y), Offset(rightX, y), towerPaint);

      // Diagonal Lattice Braces
      if (i > 1) {
        final prevRatio = (i - 1) / 4.0;
        final prevY = towerTop.dy + (towerHeight * 0.9 * prevRatio);
        final prevLeftX = towerTop.dx - (towerWidth * 0.45 * prevRatio);
        final prevRightX = towerTop.dx + (towerWidth * 0.45 * prevRatio);

        canvas.drawLine(Offset(prevLeftX, prevY), Offset(rightX, y), towerPaint..strokeWidth = 1.8);
        canvas.drawLine(Offset(prevRightX, prevY), Offset(leftX, y), towerPaint);
        towerPaint.strokeWidth = 2.8;
      }
    }

    // Top Platform & Tip Antenna
    final tipPoint = Offset(center.dx, towerTop.dy - 12);
    canvas.drawLine(towerTop, tipPoint, towerPaint..strokeWidth = 3.5);

    // Antenna Tip Pulse Glow
    final tipGlow = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tipPoint, 3.5, tipGlow);

    // 3. ANIMATED SIGNAL WAVES (3 Arcs on Left & Right)
    _drawSignalArcs(canvas, tipPoint, signalValue);
  }

  void _drawSkylineBackground(Canvas canvas, Size size, Offset center) {
    final skylinePaint = Paint()
      ..color = const Color(0xFFE2E8F0).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    // Building silhouettes behind tower
    final path = Path();
    final baseY = center.dy + (size.height * 0.38);

    path.moveTo(center.dx - (size.width * 0.42), baseY);

    // Left buildings
    path.lineTo(center.dx - 70, baseY);
    path.lineTo(center.dx - 70, baseY - 22);
    path.lineTo(center.dx - 55, baseY - 22);
    path.lineTo(center.dx - 55, baseY - 35);
    path.lineTo(center.dx - 40, baseY - 35);
    path.lineTo(center.dx - 40, baseY);

    // Center-Right buildings
    path.lineTo(center.dx + 25, baseY);
    path.lineTo(center.dx + 25, baseY - 30);
    path.lineTo(center.dx + 42, baseY - 30);
    path.lineTo(center.dx + 42, baseY - 45);
    path.lineTo(center.dx + 60, baseY - 45);
    path.lineTo(center.dx + 60, baseY - 18);
    path.lineTo(center.dx + 75, baseY - 18);
    path.lineTo(center.dx + 75, baseY);

    path.close();
    canvas.drawPath(path, skylinePaint);

    // Soft cloud curves
    final cloudPaint = Paint()
      ..color = const Color(0xFFDBEAFE).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - 50, baseY - 42), 16, cloudPaint);
    canvas.drawCircle(Offset(center.dx - 35, baseY - 45), 20, cloudPaint);
    canvas.drawCircle(Offset(center.dx + 45, baseY - 50), 14, cloudPaint);
    canvas.drawCircle(Offset(center.dx + 58, baseY - 52), 18, cloudPaint);
  }

  void _drawSignalArcs(Canvas canvas, Offset tipPoint, double value) {
    // 3 Signal Arcs on left & right
    for (int i = 1; i <= 3; i++) {
      final arcRadius = 14.0 * i;
      // Staggered opacity & pulse
      final waveProgress = ((value + (i * 0.25)) % 1.0);
      final opacity = (0.3 + (waveProgress * 0.7)).clamp(0.0, 1.0);
      final strokeWidth = 2.2 + (waveProgress * 0.8);

      final arcPaint = Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Soft glow mask
      final arcGlow = Paint()
        ..color = const Color(0xFF3B82F6).withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final rect = Rect.fromCircle(center: tipPoint, radius: arcRadius);

      // Left Signal Waves (pointing top-left to bottom-left)
      canvas.drawArc(rect, math.pi * 1.15, math.pi * 0.7, false, arcGlow);
      canvas.drawArc(rect, math.pi * 1.15, math.pi * 0.7, false, arcPaint);

      // Right Signal Waves (pointing top-right to bottom-right)
      canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.7, false, arcGlow);
      canvas.drawArc(rect, -math.pi * 0.85, math.pi * 0.7, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TelecomTowerPainter oldDelegate) {
    return oldDelegate.signalValue != signalValue;
  }
}

// ── WIDGET: STATUS TIMELINE CARD (4 STEPS VERTICAL TIMELINE) ──
class _StatusTimelineCard extends StatelessWidget {
  final int currentStep;
  final AnimationController pulseAnimation;
  final bool isSuccess;

  const _StatusTimelineCard({
    required this.currentStep,
    required this.pulseAnimation,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _StepItem(
            stepIndex: 0,
            currentStep: currentStep,
            title: 'Wallet verified',
            subtitle: 'Your wallet balance is verified',
            pulseAnimation: pulseAnimation,
            isLast: false,
            isSuccess: isSuccess,
          ),
          _StepItem(
            stepIndex: 1,
            currentStep: currentStep,
            title: 'Sending request',
            subtitle: 'Connecting securely to operator',
            pulseAnimation: pulseAnimation,
            isLast: false,
            isSuccess: isSuccess,
          ),
          _StepItem(
            stepIndex: 2,
            currentStep: currentStep,
            title: 'Waiting for operator',
            subtitle: 'Confirming your recharge',
            pulseAnimation: pulseAnimation,
            isLast: false,
            isSuccess: isSuccess,
          ),
          _StepItem(
            stepIndex: 3,
            currentStep: currentStep,
            title: 'Finalizing payment',
            subtitle: 'Almost there...',
            pulseAnimation: pulseAnimation,
            isLast: true,
            isSuccess: isSuccess,
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int stepIndex;
  final int currentStep;
  final String title;
  final String subtitle;
  final AnimationController pulseAnimation;
  final bool isLast;
  final bool isSuccess;

  const _StepItem({
    required this.stepIndex,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.pulseAnimation,
    required this.isLast,
    required this.isSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = isSuccess || stepIndex < currentStep;
    final bool isActive = !isSuccess && stepIndex == currentStep;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ICON & CONNECTOR LINE COLUMN ──
          Column(
            children: [
              // Icon representation
              if (isCompleted)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                )
              else if (isActive)
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (context, child) {
                    final scale = 1.0 + (pulseAnimation.value * 0.25);
                    final opacity = (1.0 - pulseAnimation.value).clamp(0.2, 0.8);
                    return SizedBox(
                      width: 26,
                      height: 26,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2563EB).withValues(alpha: opacity * 0.3),
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF2563EB),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                  ),
                ),

              // Vertical Connector Line
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : (isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // ── STEP TITLE & SUBTITLE ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isCompleted || isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      fontSize: 15,
                      fontWeight: isCompleted || isActive ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isCompleted || isActive ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── WIDGET: BANK-GRADE SECURITY SAFE CARD ──
class _SafeCard extends StatelessWidget {
  const _SafeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Safe & Secure',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your transaction is 100% secure. We never store your details.',
                  style: TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
