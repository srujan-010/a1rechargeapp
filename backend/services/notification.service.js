const Notification = require('../models/Notification');
let NotificationHistory;
try {
  NotificationHistory = require('../models/NotificationHistory');
} catch (e) {
  NotificationHistory = null;
}
const User = require('../models/User');
const { getApp } = require('../config/firebase');
const { getMessaging } = require('firebase-admin/messaging');

/**
 * Normalizes error/failure reasons into safe, human-readable strings.
 * Filters out raw database cast errors, stack traces, Dio/HTTP codes, JWT details, etc.
 */
function normalizeFailureReason(reason, defaultFallback = 'Transaction declined by operator.') {
  if (!reason || typeof reason !== 'string') return defaultFallback;

  const raw = reason.trim();
  const lower = raw.toLowerCase();

  // Strip technical/framework errors
  if (
    lower.includes('cast to number') ||
    lower.includes('validation failed') ||
    lower.includes('cannot find module') ||
    lower.includes('dioexception') ||
    lower.includes('mongoservererror') ||
    lower.includes('jwt') ||
    lower.includes('syntaxerror') ||
    lower.includes('referenceerror') ||
    lower.includes('typeerror') ||
    lower.includes('internal server error')
  ) {
    return 'Recharge processing failed. If any amount was debited, it will be automatically refunded.';
  }

  // Common user-friendly reason normalizations
  if (lower.includes('mpin')) return 'Invalid MPIN';
  if (lower.includes('balance') || lower.includes('insufficient')) return 'Insufficient wallet balance';
  if (lower.includes('duplicate')) return raw;
  if (lower.includes('timeout')) return 'Recharge request timed out with provider. Please try again.';

  return raw.length > 0 ? raw : defaultFallback;
}

class NotificationService {
  /**
   * Central Event-Driven Dispatch Logic (Backend Source of Truth)
   * 1. Idempotency Check (Prevents duplicate notifications across Webhook/Worker/Poller)
   * 2. In-App Internal Notification Creation (MongoDB)
   * 3. FCM Push Notification Dispatch (Multi-Device Support)
   */
  async _dispatch({
    userId,
    title,
    body,
    category = 'RECHARGE',
    notificationType = 'SYSTEM',
    relatedOrderId = null,
    relatedTransactionId = null,
    deepLink = null,
    data = {},
    priority = 'normal',
    imageUrl = null,
    sentBy = null
  }) {
    // Non-blocking async execution
    setImmediate(async () => {
      try {
        if (!userId) return;

        const txnId = String(relatedTransactionId || relatedOrderId || data.transactionId || data.orderId || '');

        // ── 1. IDEMPOTENCY GUARD ──
        if (txnId && notificationType) {
          const existing = await Notification.findOne({
            userId,
            notificationType,
            $or: [
              { relatedTransactionId: txnId },
              { relatedOrderId: txnId }
            ]
          });
          if (existing) {
            console.log(`[NotificationService] IDEMPOTENCY GUARD: Suppressed duplicate '${notificationType}' for txn: ${txnId}`);
            return;
          }
        }

        // ── 2. FETCH USER ──
        const user = await User.findById(userId).select('fcmToken fcmTokens notificationEnabled notificationPreferences name phone retailerId');
        if (!user) return;

        if (category !== 'SECURITY') {
          if (user.notificationEnabled === false) return;
        }

        const actionRoute = deepLink || data.actionRoute || data.route || null;
        const combinedData = { ...data, actionRoute: actionRoute || '', notificationType };

        // ── 3. CREATE INTERNAL IN-APP NOTIFICATION (MongoDB) ──
        let internalNotif;
        if (Notification) {
          internalNotif = await Notification.create({
            userId: user._id,
            title,
            message: body,
            body,
            type: 'BOTH',
            notificationType,
            category: category.toUpperCase(),
            priority: priority.toUpperCase(),
            actionRoute,
            action: actionRoute,
            actionData: combinedData,
            data: combinedData,
            relatedOrderId: relatedOrderId || data.orderId || null,
            relatedTransactionId: relatedTransactionId || data.transactionId || null,
            isRead: false
          });
        }

        // ── 4. FCM PUSH NOTIFICATION DISPATCH ──
        const tokens = new Set();
        if (user.fcmToken) tokens.add(user.fcmToken);
        if (Array.isArray(user.fcmTokens)) {
          user.fcmTokens.forEach((t) => {
            if (t && t.token && t.isActive !== false) tokens.add(t.token);
          });
        }

        if (tokens.size > 0) {
          try {
            const firebaseApp = getApp();
            if (firebaseApp) {
              const messaging = getMessaging(firebaseApp);
              for (const token of tokens) {
                try {
                  const payload = {
                    token,
                    notification: {
                      title,
                      body,
                      ...(imageUrl && { imageUrl })
                    },
                    data: {
                      ...combinedData,
                      notificationId: internalNotif ? internalNotif._id.toString() : '',
                      click_action: 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    android: {
                      priority: priority.toLowerCase() === 'high' ? 'high' : 'normal',
                      notification: {
                        channelId: 'a1_recharge_notifications',
                        sound: 'default'
                      }
                    }
                  };
                  const fcmResponse = await messaging.send(payload);

                  if (NotificationHistory) {
                    await NotificationHistory.create({
                      userId: user._id,
                      fcmToken: token,
                      title,
                      body,
                      imageUrl,
                      deepLink: actionRoute,
                      priority: priority.toLowerCase() === 'high' ? 'high' : 'normal',
                      sentBy: sentBy || null,
                      isAutomatic: !sentBy,
                      source: category,
                      firebaseMessageId: fcmResponse || null,
                      status: 'DELIVERED'
                    });
                  }
                } catch (fcmErr) {
                  console.error(`[FCM Push Error] Failed for token ${token.substring(0, 10)}...:`, fcmErr.message);

                  if (
                    fcmErr.code === 'messaging/registration-token-not-registered' ||
                    fcmErr.code === 'messaging/invalid-registration-token'
                  ) {
                    if (user.fcmToken === token) {
                      await User.findByIdAndUpdate(userId, { fcmToken: null });
                    }
                    if (Array.isArray(user.fcmTokens)) {
                      await User.findByIdAndUpdate(userId, { $pull: { fcmTokens: { token } } });
                    }
                  }
                }
              }
            }
          } catch (fbErr) {
            console.error('[NotificationService] Firebase App initialization error:', fbErr.message);
          }
        }
      } catch (err) {
        console.error('[NotificationService] Backend dispatch error:', err.message);
      }
    });
  }

  // ============================================================
  // 1. RECHARGE NOTIFICATIONS
  // ============================================================

  notifyRechargeProcessing({ userId, orderId, transactionId, amount, operator, mobileNumber }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';
    const numStr = mobileNumber ? ` for ${mobileNumber}` : '';

    this._dispatch({
      userId,
      title: 'Recharge in Progress',
      body: `Your ₹${formattedAmount} ${operator || 'Mobile'} recharge${numStr} is being processed.`,
      category: 'RECHARGE',
      notificationType: 'RECHARGE_PROCESSING',
      relatedOrderId: orderId,
      relatedTransactionId: txnId,
      deepLink: `/recharge/pending`,
      data: {
        type: 'recharge_processing',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        status: 'PROCESSING',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(mobileNumber || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'normal'
    });
  }

  notifyRechargePending({ userId, orderId, transactionId, providerTransactionId, amount, operator, mobileNumber }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';

    this._dispatch({
      userId,
      title: 'Recharge Pending',
      body: `Your ₹${formattedAmount} ${operator || 'Mobile'} recharge is still pending with the operator. We'll update you once the status is confirmed.`,
      category: 'RECHARGE',
      notificationType: 'RECHARGE_PENDING',
      relatedOrderId: orderId,
      relatedTransactionId: txnId,
      deepLink: `/recharge/pending`,
      data: {
        type: 'recharge_pending',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        providerTransactionId: String(providerTransactionId || ''),
        status: 'PENDING',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(mobileNumber || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'normal'
    });
  }

  notifyRechargeSuccess({ userId, orderId, transactionId, providerTransactionId, amount, operator, mobileNumber, commissionAmount }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';
    const numStr = mobileNumber ? ` for ${mobileNumber}` : '';
    let body = `₹${formattedAmount} ${operator || 'Mobile'} recharge${numStr} was successful.`;

    const commissionVal = Number(commissionAmount || 0);
    if (commissionVal > 0) {
      body += ` You saved ₹${commissionVal.toFixed(2)} on this recharge.`;
    }

    this._dispatch({
      userId,
      title: 'Recharge Successful',
      body,
      category: 'RECHARGE',
      notificationType: 'RECHARGE_SUCCESS',
      relatedOrderId: orderId,
      relatedTransactionId: txnId,
      deepLink: `/recharge/receipt/${txnId}`,
      data: {
        type: 'recharge_success',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        providerTransactionId: String(providerTransactionId || ''),
        status: 'SUCCESS',
        amount: String(amount),
        commissionAmount: String(commissionVal),
        operator: String(operator || ''),
        mobileNumber: String(mobileNumber || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    });
  }

  notifyRechargeFailed({ userId, orderId, transactionId, amount, operator, mobileNumber, reason }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';
    const safeReason = normalizeFailureReason(reason);

    this._dispatch({
      userId,
      title: 'Recharge Failed',
      body: `Your ₹${formattedAmount} ${operator || 'Mobile'} recharge failed. Reason: ${safeReason}`,
      category: 'RECHARGE',
      notificationType: 'RECHARGE_FAILED',
      relatedOrderId: orderId,
      relatedTransactionId: txnId,
      deepLink: `/recharge/failed`,
      data: {
        type: 'recharge_failed',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        reason: safeReason,
        status: 'FAILED',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(mobileNumber || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    });
  }

  // ============================================================
  // 2. WALLET NOTIFICATIONS
  // ============================================================

  notifyWalletTopupSuccess({ userId, amount, razorpayPaymentId, referenceId, transactionId }) {
    const formattedAmount = Number(amount || 0).toFixed(2);

    this._dispatch({
      userId,
      title: 'Wallet Credited',
      body: `₹${formattedAmount} has been added to your A1 Recharge wallet.`,
      category: 'WALLET',
      notificationType: 'WALLET_TOPUP_SUCCESS',
      relatedTransactionId: referenceId || transactionId,
      deepLink: '/wallet',
      data: {
        type: 'wallet_topup_success',
        amount: String(amount),
        paymentReference: String(referenceId || ''),
        razorpayPaymentId: String(razorpayPaymentId || ''),
        transactionId: String(transactionId || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    });
  }

  notifyWalletTopupFailed({ userId, amount, reason }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const safeReason = normalizeFailureReason(reason, 'Payment declined or cancelled.');

    this._dispatch({
      userId,
      title: 'Wallet Top-Up Failed',
      body: `Your ₹${formattedAmount} wallet top-up failed. Reason: ${safeReason}`,
      category: 'WALLET',
      notificationType: 'WALLET_TOPUP_FAILED',
      deepLink: '/wallet',
      data: {
        type: 'wallet_topup_failed',
        amount: String(amount),
        reason: safeReason,
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    });
  }

  notifyWalletTopupPending({ userId, amount }) {
    const formattedAmount = Number(amount || 0).toFixed(2);

    this._dispatch({
      userId,
      title: 'Wallet Top-Up Pending',
      body: `Your ₹${formattedAmount} wallet top-up is being verified.`,
      category: 'WALLET',
      notificationType: 'WALLET_TOPUP_PENDING',
      deepLink: '/wallet',
      data: {
        type: 'wallet_topup_pending',
        amount: String(amount),
        timestamp: new Date().toISOString()
      },
      priority: 'normal'
    });
  }

  notifyAdminWalletCredit({ userId, amount, referenceId }) {
    const formattedAmount = Number(amount || 0).toFixed(2);

    this._dispatch({
      userId,
      title: 'Wallet Credited',
      body: `Your wallet has been credited with ₹${formattedAmount} by the administrator.`,
      category: 'WALLET',
      notificationType: 'ADMIN_WALLET_CREDIT',
      relatedTransactionId: referenceId,
      deepLink: '/wallet',
      data: {
        type: 'admin_wallet_credit',
        amount: String(amount),
        referenceId: String(referenceId || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'high'
    });
  }

  notifyWalletDebit({ userId, amount, payableAmount, reason, referenceId }) {
    const actualDebited = payableAmount !== undefined && payableAmount !== null ? payableAmount : amount;
    const formattedAmount = Number(actualDebited || 0).toFixed(2);

    this._dispatch({
      userId,
      title: 'Wallet Debited',
      body: `₹${formattedAmount} was debited from your wallet for the recharge.`,
      category: 'WALLET',
      notificationType: 'WALLET_DEBIT',
      relatedTransactionId: referenceId,
      deepLink: '/wallet',
      data: {
        type: 'wallet_debit',
        amount: String(actualDebited),
        reason: String(reason || ''),
        referenceId: String(referenceId || ''),
        timestamp: new Date().toISOString()
      },
      priority: 'normal'
    });
  }

  // ============================================================
  // 3. COMMISSION NOTIFICATIONS
  // ============================================================

  notifyCommissionEarned({ userId, commissionAmount }) {
    const formattedVal = Number(commissionAmount || 0).toFixed(2);

    this._dispatch({
      userId,
      title: 'Commission Earned',
      body: `You earned ₹${formattedVal} commission from your recharge.`,
      category: 'COMMISSION',
      notificationType: 'COMMISSION_EARNED',
      deepLink: '/wallet',
      data: {
        type: 'commission_earned',
        commissionAmount: String(formattedVal),
        timestamp: new Date().toISOString()
      },
      priority: 'normal'
    });
  }

  // ============================================================
  // 4. SECURITY PIN & WALLET MPIN NOTIFICATIONS
  // ============================================================

  notifySecurityPinSetSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Security PIN Configured',
      body: 'Your Security PIN has been configured successfully.',
      category: 'SECURITY_PIN',
      notificationType: 'SECURITY_PIN_SET_SUCCESS',
      deepLink: '/profile/security-pin',
      data: { type: 'security_pin_set_success' },
      priority: 'high'
    });
  }

  notifySecurityPinChangedSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Security PIN Changed',
      body: 'Your Security PIN was changed successfully.',
      category: 'SECURITY_PIN',
      notificationType: 'SECURITY_PIN_CHANGED_SUCCESS',
      deepLink: '/profile/security-pin',
      data: { type: 'security_pin_changed_success' },
      priority: 'high'
    });
  }

  notifySecurityPinResetSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Security PIN Reset',
      body: 'Your Security PIN was reset successfully.',
      category: 'SECURITY_PIN',
      notificationType: 'SECURITY_PIN_RESET_SUCCESS',
      deepLink: '/profile/security-pin',
      data: { type: 'security_pin_reset_success' },
      priority: 'high'
    });
  }

  notifyWalletMpinSetSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Wallet MPIN Configured',
      body: 'Your Wallet MPIN has been configured successfully.',
      category: 'WALLET_MPIN',
      notificationType: 'WALLET_MPIN_SET_SUCCESS',
      deepLink: '/profile',
      data: { type: 'wallet_mpin_set_success' },
      priority: 'high'
    });
  }

  notifyWalletMpinChangedSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Wallet MPIN Changed',
      body: 'Your Wallet MPIN was changed successfully.',
      category: 'WALLET_MPIN',
      notificationType: 'WALLET_MPIN_CHANGED_SUCCESS',
      deepLink: '/profile',
      data: { type: 'wallet_mpin_changed_success' },
      priority: 'high'
    });
  }

  notifyWalletMpinResetSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Wallet MPIN Reset',
      body: 'Your Wallet MPIN was reset successfully.',
      category: 'WALLET_MPIN',
      notificationType: 'WALLET_MPIN_RESET_SUCCESS',
      deepLink: '/profile',
      data: { type: 'wallet_mpin_reset_success' },
      priority: 'high'
    });
  }

  notifyMpinSetSuccess({ userId }) {
    this.notifyWalletMpinSetSuccess({ userId });
  }

  notifyMpinResetSuccess({ userId }) {
    this.notifyWalletMpinResetSuccess({ userId });
  }

  notifyMpinUpdateFailed({ userId, reason }) {
    const safeReason = normalizeFailureReason(reason, 'Invalid input or network error.');
    this._dispatch({
      userId,
      title: 'MPIN Update Failed',
      body: `Your MPIN could not be updated. Reason: ${safeReason}`,
      category: 'MPIN',
      notificationType: 'MPIN_UPDATE_FAILED',
      deepLink: '/profile',
      data: { type: 'mpin_update_failed', reason: safeReason },
      priority: 'high'
    });
  }

  // ============================================================
  // 5. ONBOARDING & ACCOUNT NOTIFICATIONS
  // ============================================================

  notifyOnboardingSuccess({ userId }) {
    this._dispatch({
      userId,
      title: 'Welcome to A1 Recharge',
      body: 'Your A1 Recharge onboarding has been completed successfully.',
      category: 'ONBOARDING',
      notificationType: 'ONBOARDING_SUCCESS',
      deepLink: '/dashboard',
      data: { type: 'onboarding_success' },
      priority: 'high'
    });
  }

  notifyOnboardingFailed({ userId, reason }) {
    const safeReason = normalizeFailureReason(reason, 'Onboarding verification failed.');
    this._dispatch({
      userId,
      title: 'Onboarding Failed',
      body: `Your onboarding could not be completed. Reason: ${safeReason}`,
      category: 'ONBOARDING',
      notificationType: 'ONBOARDING_FAILED',
      deepLink: '/profile',
      data: { type: 'onboarding_failed', reason: safeReason },
      priority: 'high'
    });
  }

  notifyProfileUpdated({ userId }) {
    this._dispatch({
      userId,
      title: 'Profile Updated',
      body: 'Your profile has been updated successfully.',
      category: 'ACCOUNT',
      notificationType: 'PROFILE_UPDATED',
      deepLink: '/profile',
      data: { type: 'profile_updated' },
      priority: 'normal'
    });
  }

  // ============================================================
  // 6. SECURITY & LOGIN NOTIFICATIONS
  // ============================================================

  notifyLoginAlert({ userId, ip, device }) {
    this._dispatch({
      userId,
      title: 'New Login',
      body: `Your A1 Recharge account was signed in on a new device (${device || 'Mobile Browser'} / IP: ${ip || 'Unknown'}).`,
      category: 'SECURITY',
      notificationType: 'SECURITY_NEW_LOGIN',
      deepLink: '/profile',
      data: { type: 'security_new_login', ip: String(ip || ''), device: String(device || '') },
      priority: 'high'
    });
  }

  // ============================================================
  // BACKWARDS COMPATIBILITY ALIASES
  // ============================================================

  sendRechargeProcessing(opts) { return this.notifyRechargeProcessing(opts); }
  sendRechargePending(opts) { return this.notifyRechargePending(opts); }
  sendRechargeSuccess(opts) { return this.notifyRechargeSuccess(opts); }
  sendRechargeFailed(opts) { return this.notifyRechargeFailed(opts); }
  sendWalletCredited({ userId, amount, referenceId, razorpayPaymentId }) {
    return this.notifyWalletTopupSuccess({ userId, amount, referenceId, razorpayPaymentId });
  }
  sendWalletDebited({ userId, amount, payableAmount, reason, referenceId }) {
    return this.notifyWalletDebit({ userId, amount, payableAmount, reason, referenceId });
  }
  sendCommissionCredited({ userId, amount }) {
    return this.notifyCommissionEarned({ userId, commissionAmount: amount });
  }
  sendLoginAlert({ userId, ip, device }) {
    return this.notifyLoginAlert({ userId, ip, device });
  }
}

module.exports = new NotificationService();
