const { getAdmin } = require('../config/firebase');

class NotificationService {
  /**
   * Helper to handle FCM errors.
   * If a token is unregistered or invalid, it returns the error object
   * so the caller can remove the token from the database.
   */
  _handleFcmError(error) {
    console.error('FCM Error:', error.message || error);
    if (
      error.code === 'messaging/invalid-registration-token' ||
      error.code === 'messaging/registration-token-not-registered'
    ) {
      return { success: false, isUnregistered: true, error };
    }
    return { success: false, isUnregistered: false, error };
  }

  /**
   * Send a notification to a specific user using their FCM token.
   * @param {String} fcmToken - The device token
   * @param {Object} payload - Notification payload (title, body, data)
   */
  async sendToUser(fcmToken, payload) {
    if (!fcmToken) return { success: false, error: 'No FCM token provided' };

    try {
      const admin = getAdmin();
      const message = {
        token: fcmToken,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
      };

      const response = await admin.messaging().send(message);
      return { success: true, response };
    } catch (error) {
      return this._handleFcmError(error);
    }
  }

  /**
   * Send a notification to multiple users.
   * @param {Array<String>} fcmTokens - Array of device tokens
   * @param {Object} payload - Notification payload (title, body, data)
   */
  async sendToUsers(fcmTokens, payload) {
    if (!fcmTokens || fcmTokens.length === 0) return { success: false, error: 'No FCM tokens provided' };

    try {
      const admin = getAdmin();
      const message = {
        tokens: fcmTokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      
      // Optional: Check for failed tokens
      const failedTokens = [];
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push({
              token: fcmTokens[idx],
              error: resp.error,
            });
          }
        });
      }

      return { success: true, response, failedTokens };
    } catch (error) {
      return this._handleFcmError(error);
    }
  }

  /**
   * Send a notification to a topic.
   * @param {String} topic - The topic name
   * @param {Object} payload - Notification payload (title, body, data)
   */
  async sendToTopic(topic, payload) {
    if (!topic) return { success: false, error: 'No topic provided' };

    try {
      const admin = getAdmin();
      const message = {
        topic: topic,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
      };

      const response = await admin.messaging().send(message);
      return { success: true, response };
    } catch (error) {
      return this._handleFcmError(error);
    }
  }

  /**
   * Broadcast a notification to all users (by sending to an 'all' topic).
   * @param {Object} payload - Notification payload (title, body, data)
   */
  async broadcast(payload) {
    return this.sendToTopic('all', payload);
  }

  /**
   * Send a data-only notification (silent push).
   * @param {String} fcmToken - The device token
   * @param {Object} data - Key-value pair strings
   */
  async sendDataNotification(fcmToken, data) {
    if (!fcmToken) return { success: false, error: 'No FCM token provided' };

    try {
      const admin = getAdmin();
      const message = {
        token: fcmToken,
        data: data || {},
      };

      const response = await admin.messaging().send(message);
      return { success: true, response };
    } catch (error) {
      return this._handleFcmError(error);
    }
  }
}

module.exports = new NotificationService();
