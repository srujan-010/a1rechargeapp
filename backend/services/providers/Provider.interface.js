/**
 * Abstract interface for Recharge Providers
 * Ensures all providers implement the exact same methods so they can be swapped easily.
 */
class ProviderInterface {
  async health() {
    throw new Error('Method "health()" must be implemented.');
  }

  async balance() {
    throw new Error('Method "balance()" must be implemented.');
  }

  async recharge(options) {
    throw new Error('Method "recharge(options)" must be implemented.');
  }

  async status(providerTransactionId) {
    throw new Error('Method "status(providerTransactionId)" must be implemented.');
  }

  async operators() {
    throw new Error('Method "operators()" must be implemented.');
  }

  async plans(operatorCode, circleCode) {
    throw new Error('Method "plans(operatorCode, circleCode)" must be implemented.');
  }
}

module.exports = ProviderInterface;
