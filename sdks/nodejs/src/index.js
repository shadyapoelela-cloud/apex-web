// APEX Node.js SDK — ES-module entry point.
//
// Usage:
//   import { ApexClient } from "@apex/sdk";
//   const apex = new ApexClient({
//     baseUrl: "https://api.apex-app.com",
//     apiKey: "apex_live_...",
//     tenantId: "t_123",
//   });
//   const page = await apex.hr.employees.list({ limit: 25 });
//   for await (const emp of apex.paginate("/hr/employees", { limit: 50 })) {
//     console.log(emp.employee_number, emp.name_ar);
//   }

export class ApexApiError extends Error {
  constructor(statusCode, detail, requestUrl = "") {
    super(`APEX API ${statusCode}: ${JSON.stringify(detail)}`);
    this.name = "ApexApiError";
    this.statusCode = statusCode;
    this.detail = detail;
    this.requestUrl = requestUrl;
  }
}

export class ApexClient {
  constructor({ baseUrl, apiKey = null, tenantId = null, timeoutMs = 30_000, fetchFn = null }) {
    if (!baseUrl) throw new Error("baseUrl is required");
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.apiKey = apiKey;
    this.tenantId = tenantId;
    this.timeoutMs = timeoutMs;
    // Allow dependency-injection for testing
    this._fetch = fetchFn ?? globalThis.fetch;
    if (typeof this._fetch !== "function") {
      throw new Error(
        "No fetch() available. Node >= 18 is required, or pass fetchFn in the constructor.",
      );
    }

    this.hr = new HrNamespace(this);
    this.webhooks = new WebhooksNamespace(this);
    this.savedViews = new SavedViewsNamespace(this);
  }

  _headers(extra = {}) {
    const h = { Accept: "application/json" };
    if (this.apiKey) h["Authorization"] = `Bearer ${this.apiKey}`;
    if (this.tenantId) h["X-Tenant-Id"] = this.tenantId;
    return { ...h, ...extra };
  }

  async request(method, path, { params = null, body = null } = {}) {
    let url = `${this.baseUrl}${path}`;
    if (params) {
      const qs = new URLSearchParams();
      for (const [k, v] of Object.entries(params)) {
        if (v === undefined || v === null) continue;
        qs.append(k, String(v));
      }
      const s = qs.toString();
      if (s) url += `?${s}`;
    }

    const headers = this._headers(
      body !== null ? { "Content-Type": "application/json" } : {},
    );

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    let resp;
    try {
      resp = await this._fetch(url, {
        method,
        headers,
        body: body === null ? undefined : JSON.stringify(body),
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timer);
    }

    if (!resp.ok) {
      let detail;
      try {
        detail = await resp.json();
      } catch {
        detail = await resp.text();
      }
      throw new ApexApiError(resp.status, detail, url);
    }

    const text = await resp.text();
    if (!text) return {};
    try {
      return JSON.parse(text);
    } catch {
      return { raw: text };
    }
  }

  get(path, opts) { return this.request("GET", path, opts); }
  post(path, opts) { return this.request("POST", path, opts); }
  put(path, opts) { return this.request("PUT", path, opts); }
  delete(path, opts) { return this.request("DELETE", path, opts); }

  async *paginate(path, { limit = 25, params = {} } = {}) {
    let cursor = null;
    while (true) {
      const q = { ...params, limit };
      if (cursor) q.cursor = cursor;
      const body = await this.get(path, { params: q });
      const items = body.data ?? [];
      for (const item of items) yield item;
      if (!body.has_more || !body.next_cursor) break;
      cursor = body.next_cursor;
    }
  }
}

// ── Namespaces ────────────────────────────────────────────

class HrNamespace {
  constructor(c) {
    this._c = c;
    this.employees = new HrEmployees(c);
    this.leave = new HrLeave(c);
    this.payroll = new HrPayroll(c);
  }
  async calcGosi(opts) {
    const body = await this._c.post("/hr/calc/gosi", { body: opts });
    return body.data;
  }
  async calcEosb(opts) {
    const body = await this._c.post("/hr/calc/eosb", { body: opts });
    return body.data;
  }
}

class HrEmployees {
  constructor(c) { this._c = c; }
  async list({ limit = 25, cursor = null, status = null } = {}) {
    const params = { limit };
    if (cursor) params.cursor = cursor;
    if (status) params.status = status;
    const body = await this._c.get("/hr/employees", { params });
    return {
      items: body.data ?? [],
      nextCursor: body.next_cursor ?? null,
      hasMore: !!body.has_more,
      limit: body.limit ?? limit,
    };
  }
  async create(fields) {
    return (await this._c.post("/hr/employees", { body: fields })).data;
  }
  async get(id) {
    return (await this._c.get(`/hr/employees/${id}`)).data;
  }
  async update(id, fields) {
    return (await this._c.put(`/hr/employees/${id}`, { body: fields })).data;
  }
  async terminate(id) {
    return (await this._c.delete(`/hr/employees/${id}`)).data;
  }
}

class HrLeave {
  constructor(c) { this._c = c; }
  async create(req) { return (await this._c.post("/hr/leave-requests", { body: req })).data; }
  async list({ status = null } = {}) {
    return (await this._c.get("/hr/leave-requests", { params: status ? { status } : null })).data;
  }
  async approve(id) { return (await this._c.post(`/hr/leave-requests/${id}/approve`)).data; }
  async reject(id, reason) {
    return (await this._c.post(`/hr/leave-requests/${id}/reject`, { params: { reason } })).data;
  }
}

class HrPayroll {
  constructor(c) { this._c = c; }
  async run(period) { return (await this._c.post("/hr/payroll/run", { body: { period } })).data; }
  async get(period) { return (await this._c.get(`/hr/payroll/${period}`)).data; }
  async approve(period) { return (await this._c.post(`/hr/payroll/${period}/approve`)).data; }
}

class WebhooksNamespace {
  constructor(c) { this._c = c; }
  async subscribe({ url, events, name = null }) {
    return (await this._c.post("/api/v1/webhooks/subscriptions",
      { body: { url, events, name } })).data;
  }
  async list() { return (await this._c.get("/api/v1/webhooks/subscriptions")).data; }
  async unsubscribe(id) { return (await this._c.delete(`/api/v1/webhooks/subscriptions/${id}`)).data; }
  async deliveries({ status = null, limit = 50 } = {}) {
    const params = { limit };
    if (status) params.status = status;
    return (await this._c.get("/api/v1/webhooks/deliveries", { params })).data;
  }
  async retryDelivery(id) { return (await this._c.post(`/api/v1/webhooks/deliveries/${id}/retry`)).data; }
}

class SavedViewsNamespace {
  constructor(c) { this._c = c; }
  async list(screen) { return (await this._c.get("/api/v1/saved-views", { params: { screen } })).data; }
  async create({ screen, name, payload, isShared = false }) {
    return (await this._c.post("/api/v1/saved-views",
      { body: { screen, name, payload, is_shared: isShared } })).data;
  }
  async delete(id) { return (await this._c.delete(`/api/v1/saved-views/${id}`)).data; }
}
