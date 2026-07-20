const axios = require('axios');

class PlansInfoProvider {
  get baseUrl() {
    return process.env.PLANSINFO_BASE_URL || 'https://api2.plansinfo.com';
  }

  get token() {
    return process.env.PLANSINFO_TOKEN;
  }

  _validateToken() {
    if (!this.token) {
      throw new Error('PlansInfo token not configured');
    }
  }

  async _fetch(baseUrl, endpoint, params) {
    this._validateToken();
    const url = `${baseUrl}${endpoint}`;
    try {
      const response = await axios.get(url, {
        params: {
          token: this.token,
          ...params
        }
      });
      return response.data;
    } catch (error) {
      console.error(`[PlansInfoProvider] Error fetching ${url}:`, error.message);
      if (error.response) {
        console.error('[PlansInfoProvider] Response data:', error.response.data);
      }
      throw new Error('PlansInfo API Request Failed');
    }
  }

  async getMobilePrepaid(operator, circle) {
    // V4 Prepaid
    return this._fetch('https://api.plansinfo.com', '/v4/mobile-plans.php', { operator, circle });
  }

  async getMobilePostpaid(operator, circle) {
    // V5 Postpaid
    return this._fetch('https://api2.plansinfo.com', '/v5/mobile/postpaid-plans', { operator, circle });
  }

  async getDthPacks(operator) {
    return this._fetch('https://api2.plansinfo.com', '/v5/dth/packs', { operator });
  }

  async getDthPackDetails(operator, pack_id) {
    return this._fetch('https://api2.plansinfo.com', '/v5/dth/pack', { operator, id: pack_id });
  }

  async getDthAlacarte(operator) {
    return this._fetch('https://api2.plansinfo.com', '/v5/dth/alacarte', { operator });
  }
}

module.exports = new PlansInfoProvider();
