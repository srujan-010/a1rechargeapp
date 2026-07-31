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

class NotificationService {
  /**
   * Internal unified dispatch logic (One Event -> Three Outputs)
   */
  async _dispatch({
    userId,
    title,
    body,
    category = 'INFO',
    source = 'SYSTEM',
    preferenceKey = null,
    deepLink = null,
    data = {},
    priority = 'normal',
    imageUrl = null,
    sentBy = null
  }) {
    setImmediate(async () => {
      try {
        if (!userId) return;

        const user = await User.findById(userId).select('fcmToken notificationEnabled notificationPreferences name');
        if (!user) return;

        if (preferenceKey !== 'securityNotifications') {
          if (user.notificationEnabled === false) return;
          if (preferenceKey && user.notificationPreferences && user.notificationPreferences[preferenceKey] === false) {
            return;
          }
        }

        const action = deepLink || null;
        const actionData = { ...data, deepLink: deepLink || '' };

        if (Notification) {
          await Notification.create({
            userId: user._id,
            title,
            message: body,
            type: 'BOTH',
            category: category.toUpperCase(),
            priority: priority.toUpperCase(),
            action,
            actionData
          });
        }

        let fcmStatus = 'PENDING';
        let fcmResponse = null;
        let fcmError = null;

        if (user.fcmToken) {
          try {
            const messaging = getMessaging(getApp());
            const payload = {
              token: user.fcmToken,
              notification: {
                title,
                body,
                ...(imageUrl && { imageUrl })
              },
              data: {
                ...data,
                ...(deepLink && { deepLink, route: deepLink }),
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
              },
              android: {
                priority: priority === 'high' ? 'high' : 'normal'
              }
            };

            fcmResponse = await messaging.send(payload);
            fcmStatus = 'DELIVERED';
          } catch (err) {
            fcmStatus = 'FAILED';
            fcmError = err.message || 'Firebase Messaging Error';

            if (err.code === 'messaging/registration-token-not-registered' || err.code === 'messaging/invalid-registration-token') {
              await User.findByIdAndUpdate(userId, { fcmToken: null });
            }
          }

          if (NotificationHistory) {
            await NotificationHistory.create({
              userId: user._id,
              fcmToken: user.fcmToken,
              title,
              body,
              imageUrl,
              deepLink,
              priority: priority.toLowerCase() === 'high' ? 'high' : 'normal',
              sentBy: sentBy || null,
              isAutomatic: !sentBy,
              source,
              firebaseMessageId: fcmResponse || null,
              status: fcmStatus,
              errorDetails: fcmError
            });
          }
        }
      } catch (err) {
        console.error('[NotificationEngine] Backend dispatch error:', err.message);
      }
    });
  }

  sendRechargeSuccess({ userId, transactionId, orderId, service, operator, amount, number, isUpdateFromPending = false }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';
    const body = isUpdateFromPending
      ? `Your recharge of ₹${formattedAmount} for ${operator || 'Mobile'} ${number || ''} has now been completed successfully.`
      : `₹${formattedAmount} recharge for ${operator || 'Mobile'} ${number || ''} completed successfully.`;

    this._dispatch({
      userId,
      title: 'Recharge Successful',
      body,
      category: 'SUCCESS',
      source: 'RECHARGE',
      preferenceKey: 'rechargeNotifications',
      deepLink: `/recharge/receipt/${txnId}`,
      data: {
        type: 'recharge_success',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        status: 'SUCCESS',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(number || ''),
        route: `/recharge/receipt/${txnId}`,
      },
      priority: 'high'
    });
  }

  sendRechargeFailed({ userId, transactionId, orderId, operator, amount, number, reason }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';
    const failureMsg = reason ? `Reason: ${reason}` : 'Reason: Operator decline';

    this._dispatch({
      userId,
      title: 'Recharge Failed',
      body: `Recharge of ₹${formattedAmount} failed. ${failureMsg}`,
      category: 'ERROR',
      source: 'RECHARGE',
      preferenceKey: 'rechargeNotifications',
      deepLink: `/recharge/failed`,
      data: {
        type: 'recharge_failed',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        reason: String(reason || 'Recharge failed'),
        status: 'FAILED',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(number || ''),
        route: `/recharge/failed`,
      },
      priority: 'high'
    });
  }

  sendRechargePending({ userId, transactionId, orderId, operator, amount, number }) {
    const formattedAmount = Number(amount || 0).toFixed(2);
    const txnId = transactionId || orderId || '';

    this._dispatch({
      userId,
      title: 'Recharge Processing',
      body: `Your recharge request of ₹${formattedAmount} for ${operator || 'Mobile'} ${number || ''} has been submitted and is currently being processed.`,
      category: 'WARNING',
      source: 'RECHARGE',
      preferenceKey: 'rechargeNotifications',
      deepLink: `/recharge/pending`,
      data: {
        type: 'recharge_processing',
        transactionId: String(txnId),
        orderId: String(orderId || txnId),
        status: 'PENDING',
        amount: String(amount),
        operator: String(operator || ''),
        mobileNumber: String(number || ''),
        route: `/recharge/pending`,
      },
      priority: 'normal'
    });
  }

  sendWalletCredited({ userId, amount, newBalance, reason, referenceId }) {
    const formattedAmount = Number(amount).toFixed(2);
    const formattedBal = newBalance !== undefined && newBalance !== null ? Number(newBalance).toFixed(2) : null;
    const body = formattedBal ? `₹${formattedAmount} has been added to your wallet (${reason || 'Credit'}). Updated Balance: ₹${formattedBal}.` : `₹${formattedAmount} has been added to your wallet (${reason || 'Credit'}).`;

    this._dispatch({
      userId,
      title: 'Wallet Credited 💳',
      body,
      category: 'SUCCESS',
      source: 'WALLET',
      preferenceKey: 'walletNotifications',
      deepLink: 'wallet/history',
      data: { amount: String(amount), newBalance: String(newBalance || ''), reason: String(reason || ''), referenceId: String(referenceId || ''), type: 'WALLET_CREDIT' },
      priority: 'high'
    });
  }

  sendWalletDebited({ userId, amount, newBalance, reason, referenceId }) {
    const formattedAmount = Number(amount).toFixed(2);
    const formattedBal = newBalance !== undefined && newBalance !== null ? Number(newBalance).toFixed(2) : null;
    const body = formattedBal ? `₹${formattedAmount} has been deducted (${reason || 'Debit'}). Remaining Balance: ₹${formattedBal}.` : `₹${formattedAmount} has been deducted from your wallet (${reason || 'Debit'}).`;

    this._dispatch({
      userId,
      title: 'Wallet Debited 💸',
      body,
      category: 'INFO',
      source: 'WALLET',
      preferenceKey: 'walletNotifications',
      deepLink: 'wallet/history',
      data: { amount: String(amount), newBalance: String(newBalance || ''), reason: String(reason || ''), referenceId: String(referenceId || ''), type: 'WALLET_DEBIT' },
      priority: 'normal'
    });
  }

  sendLowBalance({ userId, currentBalance, threshold = 100 }) {
    const formattedBal = Number(currentBalance).toFixed(2);
    this._dispatch({
      userId,
      title: 'Low Wallet Balance ⚠️',
      body: `Your wallet balance is low (Current: ₹${formattedBal}). Please add funds to continue recharging smoothly.`,
      category: 'WARNING',
      source: 'WALLET',
      preferenceKey: 'walletNotifications',
      deepLink: 'wallet/add-money',
      data: { currentBalance: String(currentBalance), threshold: String(threshold), type: 'LOW_BALANCE' },
      priority: 'high'
    });
  }

  sendKycApproved({ userId }) {
    this._dispatch({
      userId,
      title: 'KYC Approved ✅',
      body: 'Congratulations! Your KYC verification has been approved. You now have full access to all services.',
      category: 'SUCCESS',
      source: 'KYC',
      preferenceKey: 'kycNotifications',
      deepLink: 'profile/kyc',
      data: { type: 'KYC_APPROVED' },
      priority: 'high'
    });
  }

  sendKycRejected({ userId, reason }) {
    this._dispatch({
      userId,
      title: 'KYC Rejected ❌',
      body: `Your KYC verification was rejected. Reason: ${reason || 'Invalid documents'}. Please upload valid documents to proceed.`,
      category: 'ERROR',
      source: 'KYC',
      preferenceKey: 'kycNotifications',
      deepLink: 'profile/kyc',
      data: { reason: String(reason || ''), type: 'KYC_REJECTED' },
      priority: 'high'
    });
  }

  sendCommissionCredited({ userId, amount, newBalance }) {
    const formattedAmount = Number(amount).toFixed(2);
    this._dispatch({
      userId,
      title: 'Commission Credited 🎁',
      body: `₹${formattedAmount} commission has been added to your wallet.`,
      category: 'SUCCESS',
      source: 'WALLET',
      preferenceKey: 'walletNotifications',
      deepLink: 'wallet/history',
      data: { amount: String(amount), newBalance: String(newBalance || ''), type: 'COMMISSION_CREDIT' },
      priority: 'normal'
    });
  }

  sendSecurityAlert({ userId, alertType, details }) {
    this._dispatch({
      userId,
      title: 'Security Alert 🔒',
      body: details || 'A security event was detected on your account.',
      category: 'WARNING',
      source: 'SECURITY',
      preferenceKey: 'securityNotifications',
      deepLink: 'security',
      data: { alertType: String(alertType || ''), type: 'SECURITY_ALERT' },
      priority: 'high'
    });
  }

  sendLoginAlert({ userId, ip, device }) {
    this._dispatch({
      userId,
      title: 'New Login Detected 🔑',
      body: `New login to your account from ${device || 'a new device'} (IP: ${ip || 'Unknown'}). If this was not you, please secure your account immediately.`,
      category: 'WARNING',
      source: 'SECURITY',
      preferenceKey: 'securityNotifications',
      deepLink: 'security',
      data: { ip: String(ip || ''), device: String(device || ''), type: 'LOGIN_ALERT' },
      priority: 'high'
    });
  }

  sendPasswordChanged({ userId, type = 'Password' }) {
    this._dispatch({
      userId,
      title: `${type} Changed 🔒`,
      body: `Your account ${type.toLowerCase()} was successfully updated.`,
      category: 'INFO',
      source: 'SECURITY',
      preferenceKey: 'securityNotifications',
      deepLink: 'security',
      data: { type: `${type.toUpperCase()}_CHANGED` },
      priority: 'high'
    });
  }

  sendAccountBlocked({ userId, reason }) {
    this._dispatch({
      userId,
      title: 'Account Suspended 🚫',
      body: `Your account has been suspended by Admin. Reason: ${reason || 'Violation of terms'}. Contact support for assistance.`,
      category: 'ERROR',
      source: 'SECURITY',
      preferenceKey: 'securityNotifications',
      deepLink: 'support',
      data: { reason: String(reason || ''), type: 'ACCOUNT_BLOCKED' },
      priority: 'high'
    });
  }

  sendAccountActivated({ userId }) {
    this._dispatch({
      userId,
      title: 'Account Activated ✅',
      body: 'Your account has been reactivated. You can now resume your transactions.',
      category: 'SUCCESS',
      source: 'SYSTEM',
      preferenceKey: 'systemNotifications',
      deepLink: 'dashboard',
      data: { type: 'ACCOUNT_ACTIVATED' },
      priority: 'high'
    });
  }

  sendAdminAnnouncement({ userId, title, body, imageUrl, deepLink, sentBy }) {
    this._dispatch({
      userId,
      title,
      body,
      category: 'INFO',
      source: 'ADMIN',
      preferenceKey: 'promotionalNotifications',
      deepLink: deepLink || 'notifications',
      imageUrl,
      sentBy,
      data: { type: 'ADMIN_ANNOUNCEMENT' },
      priority: 'normal'
    });
  }
}

module.exports = new NotificationService();
