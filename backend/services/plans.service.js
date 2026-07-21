const plansInfoProvider = require('../providers/plansInfo.provider');
const ProviderOperator = require('../models/ProviderOperator');
const ProviderCircle = require('../models/ProviderCircle');
const PlanCache = require('../models/PlanCache');
const { getPlansInfoCircle } = require('../utils/plansMapper');

class PlansService {
  _inferCategory(plan) {
    if (plan.category && plan.category !== '') return plan.category;
    
    const desc = (plan.benefit || plan.description || '').toLowerCase();
    if (desc.includes('unlimited') || desc.includes('ul')) return 'Unlimited';
    if (desc.includes('data') || desc.includes('gb/day') || desc.includes('gb') || desc.includes('mb')) return 'Data';
    if (desc.includes('topup') || desc.includes('talktime') || desc.includes('tt')) return 'Top Up';
    if (desc.includes('sms')) return 'SMS';
    if (desc.includes('isd') || desc.includes('international')) return 'International';
    if (desc.includes('roam')) return 'Roaming';
    if (desc.includes('hotstar') || desc.includes('prime') || desc.includes('netflix') || desc.includes('ott')) return 'OTT';
    
    return 'Others';
  }

  _sortPlans(plans) {
    const categoryOrder = {
      'Popular': 1,
      'Unlimited': 2,
      'Data': 3,
      'Top Up': 4,
      'Talktime': 5,
      'SMS': 6,
      'OTT': 7,
      'Roaming': 8,
      'International': 9,
      'Others': 10
    };

    return plans.sort((a, b) => {
      const catA = categoryOrder[a.category] || 99;
      const catB = categoryOrder[b.category] || 99;
      
      if (catA !== catB) return catA - catB;
      if (a.amount !== b.amount) return a.amount - b.amount;
      return String(a.validity).localeCompare(String(b.validity));
    });
  }

  _filterPlans(plans, query) {
    if (!query || query.trim() === '') return plans;
    const lowerQuery = query.toLowerCase().trim();
    return plans.filter(p => {
      return (p.amount && p.amount.toString().includes(lowerQuery)) ||
             (p.category && p.category.toLowerCase().includes(lowerQuery)) ||
             (p.benefit && p.benefit.toLowerCase().includes(lowerQuery)) ||
             (p.validity && p.validity.toLowerCase().includes(lowerQuery)) ||
             (p.data && p.data.toLowerCase().includes(lowerQuery)) ||
             (p.calls && p.calls.toLowerCase().includes(lowerQuery));
    });
  }

  async _resolveOperatorAndCircle(operatorId, circleId = null) {
    const operator = await ProviderOperator.findById(operatorId);
    if (!operator) throw new Error('Invalid Operator ID');
    
    let circle = null;
    if (circleId) {
      circle = await ProviderCircle.findById(circleId);
      if (!circle) throw new Error('Invalid Circle ID');
    }
    return { operator, circle };
  }

  async _fetchFromCache(cacheQuery) {
    const cachedData = await PlanCache.findOne(cacheQuery);
    if (cachedData && cachedData.expiresAt > new Date()) {
      return cachedData.plans;
    }
    return null;
  }

  async _saveToCache(cacheQuery, plans) {
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 Hours
    await PlanCache.findOneAndUpdate(
      cacheQuery,
      {
        ...cacheQuery,
        plans,
        lastSynced: new Date(),
        expiresAt
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }

  _parseV5Categories(data) {
    const normalizedPlans = [];
    if (data && data.status === 'OK' && Array.isArray(data.categories)) {
      for (const cat of data.categories) {
        if (!Array.isArray(cat.plans)) continue;
        for (const p of cat.plans) {
          normalizedPlans.push({
            id: p.id ? p.id.toString() : null,
            amount: parseFloat(p.amount) || 0,
            name: p.name || cat.name,
            category: cat.name || this._inferCategory(p),
            validity: p.validity || 'N/A',
            benefit: p.benefit || p.description || p.detail || '',
            calls: p.calls || '',
            data: p.data || '',
            sms: p.sms || '',
            subscriptions: (p.subscriptions || []).map(s => typeof s === 'object' ? (s.name || s.code) : s)
          });
        }
      }
    } else if (data && data.status === 'OK' && Array.isArray(data.data)) {
        // Fallback if data is a flat array
        for (const p of data.data) {
            normalizedPlans.push({
                id: p.id ? p.id.toString() : null,
                amount: parseFloat(p.amount) || parseFloat(p.price) || 0,
                name: p.name || p.plan_name || '',
                category: p.category || this._inferCategory(p),
                validity: p.validity || 'N/A',
                benefit: p.benefit || p.description || p.detail || '',
                calls: p.calls || '',
                data: p.data || '',
                sms: p.sms || '',
                subscriptions: (p.subscriptions || []).map(s => typeof s === 'object' ? (s.name || s.code) : s)
            });
        }
    }
    return normalizedPlans;
  }

  // 1. Mobile Prepaid
  async getMobilePrepaid(operatorId, circleId, search) {
    const { operator, circle } = await this._resolveOperatorAndCircle(operatorId, circleId);
    const cacheQuery = { provider: 'PlansInfo', service: 'mobile', type: 'prepaid', operatorId, circleId };
    
    let plans = await this._fetchFromCache(cacheQuery);
    
    if (plans) {
      console.log(`[PlansInfo] CACHE HIT - Prepaid: ${operator.name} | ${circle.state}`);
    } else {
      const opCode = operator.plansInfoCode;
      const circleCode = getPlansInfoCircle(circle.code);
      
      console.log('\n===== PLANS REQUEST =====');
      console.log({
        operatorId: operator._id,
        operatorName: operator.name,
        plansOperatorCode: opCode,
        circleId: circle._id,
        circleName: circle.state,
        plansCircleCode: circleCode
      });

      if (!opCode || !circleCode) return []; // Missing mapping

      const startTime = Date.now();
      console.log(`Exact Request URL: /v4/mobile-plans.php?operator=${opCode}&circle=${circleCode}`);
      
      const rawData = await plansInfoProvider.getMobilePrepaid(opCode, circleCode);
      console.log('RAW RESPONSE DATA:', JSON.stringify(rawData, null, 2));
      
      console.log('Plans before normalization (raw length):', rawData?.data?.length || rawData?.categories?.length || 'Unknown');
      const normalized = this._parseV5Categories(rawData);
      console.log('Plans after normalization:', normalized.length);
      
      plans = this._sortPlans(normalized);
      console.log('Plans after category mapping (sorting):', plans.length);
      await this._saveToCache(cacheQuery, plans);
    }
    
    const finalPlans = this._filterPlans(plans, search);
    console.log('Plans returned to Flutter:', finalPlans.length);
    console.log('------------------------\n');
    return finalPlans;
  }

  // 2. Mobile Postpaid
  async getMobilePostpaid(operatorId, circleId, search) {
    const { operator, circle } = await this._resolveOperatorAndCircle(operatorId, circleId);
    const cacheQuery = { provider: 'PlansInfo', service: 'mobile', type: 'postpaid', operatorId, circleId };
    
    let plans = await this._fetchFromCache(cacheQuery);
    
    if (plans) {
      console.log(`[PlansInfo] CACHE HIT - Postpaid: ${operator.name} | ${circle.state}`);
    } else {
      const opCode = operator.plansInfoCode;
      const circleCode = getPlansInfoCircle(circle.code);
      if (!opCode || !circleCode) return [];

      const startTime = Date.now();
      console.log(`[PlansInfo] CACHE MISS - Postpaid: ${opCode} | ${circleCode}`);
      
      const rawData = await plansInfoProvider.getMobilePostpaid(opCode, circleCode);
      console.log(`[PlansInfo] API TIME - ${Date.now() - startTime}ms`);
      
      const normalized = this._parseV5Categories(rawData);
      plans = this._sortPlans(normalized);
      await this._saveToCache(cacheQuery, plans);
    }
    
    return this._filterPlans(plans, search);
  }

  // 3. DTH Packs
  async getDthPacks(operatorId, search) {
    const { operator } = await this._resolveOperatorAndCircle(operatorId);
    const cacheQuery = { provider: 'PlansInfo', service: 'dth', type: 'packs', operatorId };
    
    let plans = await this._fetchFromCache(cacheQuery);
    
    if (plans) {
      console.log(`[PlansInfo] CACHE HIT - DTH Packs: ${operator.name}`);
    } else {
      const opCode = operator.plansInfoCode;
      if (!opCode) return [];

      const startTime = Date.now();
      console.log(`[PlansInfo] CACHE MISS - DTH Packs: ${opCode}`);
      
      const rawData = await plansInfoProvider.getDthPacks(opCode);
      console.log(`[PlansInfo] API TIME - ${Date.now() - startTime}ms`);
      
      const normalized = this._parseV5Categories(rawData);
      plans = this._sortPlans(normalized);
      await this._saveToCache(cacheQuery, plans);
    }
    
    return this._filterPlans(plans, search);
  }

  // 4. DTH Pack Details
  async getDthPackDetails(operatorId, packId) {
    const { operator } = await this._resolveOperatorAndCircle(operatorId);
    const cacheQuery = { provider: 'PlansInfo', service: 'dth', type: 'pack_details', operatorId, packId };
    
    let plans = await this._fetchFromCache(cacheQuery);
    
    if (plans) {
      console.log(`[PlansInfo] CACHE HIT - DTH Pack Details: ${operator.name} | ${packId}`);
    } else {
      const opCode = operator.plansInfoCode;
      if (!opCode) return [];

      const startTime = Date.now();
      console.log(`[PlansInfo] CACHE MISS - DTH Pack Details: ${opCode} | ${packId}`);
      
      const rawData = await plansInfoProvider.getDthPackDetails(opCode, packId);
      console.log(`[PlansInfo] API TIME - ${Date.now() - startTime}ms`);
      
      // DTH Pack details might not have "categories", it might just have data arrays. Let's parse both.
      let normalized = [];
      if (rawData && rawData.status === 'OK') {
          if (Array.isArray(rawData.data)) {
              normalized = this._parseV5Categories({ status: 'OK', categories: [{ name: 'Channels', plans: rawData.data }]});
          } else if (rawData.categories) {
              normalized = this._parseV5Categories(rawData);
          } else if (rawData.channels) {
              normalized = this._parseV5Categories({ status: 'OK', categories: [{ name: 'Channels', plans: rawData.channels }]});
          }
      }

      plans = normalized;
      await this._saveToCache(cacheQuery, plans);
    }
    
    return plans; // No search needed usually for a single pack details, but can be added if needed
  }

  // 5. DTH Ala Carte
  async getDthAlacarte(operatorId, search) {
    const { operator } = await this._resolveOperatorAndCircle(operatorId);
    const cacheQuery = { provider: 'PlansInfo', service: 'dth', type: 'alacarte', operatorId };
    
    let plans = await this._fetchFromCache(cacheQuery);
    
    if (plans) {
      console.log(`[PlansInfo] CACHE HIT - DTH Ala Carte: ${operator.name}`);
    } else {
      const opCode = operator.plansInfoCode;
      if (!opCode) return [];

      const startTime = Date.now();
      console.log(`[PlansInfo] CACHE MISS - DTH Ala Carte: ${opCode}`);
      
      const rawData = await plansInfoProvider.getDthAlacarte(opCode);
      console.log(`[PlansInfo] API TIME - ${Date.now() - startTime}ms`);
      
      const normalized = this._parseV5Categories(rawData);
      plans = this._sortPlans(normalized);
      await this._saveToCache(cacheQuery, plans);
    }
    
    return this._filterPlans(plans, search);
  }
}

module.exports = new PlansService();
