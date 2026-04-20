/// Pilot Data Providers — Riverpod providers for every domain.
/// ═════════════════════════════════════════════════════════════
/// Each provider auto-refreshes when its dependency IDs change.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pilot_session_provider.dart';

// ══════════════════════════════════════════════════════════════
// Tenants / Entities / Branches
// ══════════════════════════════════════════════════════════════

final entitiesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listEntities(tid);
  return r.success ? (r.data as List) : [];
});

final branchesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listBranches(eid);
  return r.success ? (r.data as List) : [];
});

final warehousesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, bid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listWarehouses(bid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// Catalog
// ══════════════════════════════════════════════════════════════

class ProductsQuery {
  final String tenantId;
  final String? status;
  final String? categoryId;
  final String? brandId;
  final String? search;
  const ProductsQuery({
    required this.tenantId,
    this.status,
    this.categoryId,
    this.brandId,
    this.search,
  });

  @override
  bool operator ==(Object other) =>
      other is ProductsQuery &&
      other.tenantId == tenantId &&
      other.status == status &&
      other.categoryId == categoryId &&
      other.brandId == brandId &&
      other.search == search;

  @override
  int get hashCode =>
      Object.hash(tenantId, status, categoryId, brandId, search);
}

final productsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ProductsQuery>((ref, q) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listProducts(
    q.tenantId,
    status: q.status,
    categoryId: q.categoryId,
    brandId: q.brandId,
    search: q.search,
  );
  return r.success ? (r.data as List) : [];
});

final productDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, pid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.getProduct(pid);
  return r.success ? Map<String, dynamic>.from(r.data) : null;
});

final categoriesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listCategories(tid);
  return r.success ? (r.data as List) : [];
});

final brandsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listBrands(tid);
  return r.success ? (r.data as List) : [];
});

final attributesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listAttributes(tid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// POS
// ══════════════════════════════════════════════════════════════

class SessionsQuery {
  final String branchId;
  final String? status;
  const SessionsQuery({required this.branchId, this.status});

  @override
  bool operator ==(Object other) =>
      other is SessionsQuery &&
      other.branchId == branchId &&
      other.status == status;
  @override
  int get hashCode => Object.hash(branchId, status);
}

final posSessionsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, SessionsQuery>((ref, q) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listPosSessions(q.branchId, status: q.status);
  return r.success ? (r.data as List) : [];
});

final posSessionProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, sid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.getPosSession(sid);
  return r.success ? Map<String, dynamic>.from(r.data) : null;
});

final posTransactionsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, sid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listSessionTransactions(sid);
  return r.success ? (r.data as List) : [];
});

final cashMovementsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, sid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listCashMovements(sid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// Pricing
// ══════════════════════════════════════════════════════════════

final priceListsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, tid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listPriceLists(tid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// GL Reports
// ══════════════════════════════════════════════════════════════

class TrialBalanceQuery {
  final String entityId;
  final String asOf;
  const TrialBalanceQuery({required this.entityId, required this.asOf});
  @override
  bool operator ==(Object other) =>
      other is TrialBalanceQuery &&
      other.entityId == entityId &&
      other.asOf == asOf;
  @override
  int get hashCode => Object.hash(entityId, asOf);
}

final trialBalanceProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, TrialBalanceQuery>((ref, q) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.trialBalance(q.entityId, asOf: q.asOf);
  return r.success ? Map<String, dynamic>.from(r.data) : null;
});

class DateRange {
  final String entityId;
  final String start;
  final String end;
  const DateRange(
      {required this.entityId, required this.start, required this.end});
  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.entityId == entityId &&
      other.start == start &&
      other.end == end;
  @override
  int get hashCode => Object.hash(entityId, start, end);
}

final incomeStatementProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, DateRange>((ref, q) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.incomeStatement(q.entityId, q.start, q.end);
  return r.success ? Map<String, dynamic>.from(r.data) : null;
});

final balanceSheetProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, TrialBalanceQuery>((ref, q) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.balanceSheet(q.entityId, asOf: q.asOf);
  return r.success ? Map<String, dynamic>.from(r.data) : null;
});

final journalEntriesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listJournalEntries(eid);
  return r.success ? (r.data as List) : [];
});

final fiscalPeriodsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listFiscalPeriods(eid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// Compliance
// ══════════════════════════════════════════════════════════════

final zatcaSubmissionsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listZatcaSubmissions(eid);
  return r.success ? (r.data as List) : [];
});

final gosiRegistrationsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listGosiRegistrations(eid);
  return r.success ? (r.data as List) : [];
});

final wpsBatchesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listWpsBatches(eid);
  return r.success ? (r.data as List) : [];
});

final vatReturnsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, eid) async {
  final client = ref.watch(pilotClientProvider);
  final r = await client.listVatReturns(eid);
  return r.success ? (r.data as List) : [];
});

// ══════════════════════════════════════════════════════════════
// Dashboard aggregate — يجمع كل المؤشرات الأساسية
// ══════════════════════════════════════════════════════════════

class DashboardData {
  final int entityCount;
  final int branchCount;
  final int productCount;
  final int memberCount;
  final int activePriceLists;
  final int openSessions;
  final Map<String, dynamic>? todayTrialBalance;
  final Map<String, dynamic>? monthIncome;

  const DashboardData({
    this.entityCount = 0,
    this.branchCount = 0,
    this.productCount = 0,
    this.memberCount = 0,
    this.activePriceLists = 0,
    this.openSessions = 0,
    this.todayTrialBalance,
    this.monthIncome,
  });
}

final dashboardProvider =
    FutureProvider.autoDispose<DashboardData>((ref) async {
  final selection = ref.watch(pilotSessionProvider);
  final client = ref.watch(pilotClientProvider);
  if (!selection.hasTenant) return const DashboardData();

  final tid = selection.tenantId!;
  final results = await Future.wait([
    client.listEntities(tid),
    client.listProducts(tid, limit: 1),
    client.listMembers(tid),
    client.listPriceLists(tid, activeOnly: true),
  ]);

  int entityCount = 0, branchCount = 0, productCount = 0, memberCount = 0, activePl = 0;
  if (results[0].success) {
    final entities = results[0].data as List;
    entityCount = entities.length;
    // عدّ الفروع عبر كل كيان (بشكل مُجمّع)
    for (final e in entities) {
      final br = await client.listBranches(e['id']);
      if (br.success) branchCount += (br.data as List).length;
    }
  }
  // For products we need a count; listProducts returns a page — نستخدم limit=1 offset=0 ثم نطلب الكل
  final allProds = await client.listProducts(tid, limit: 500);
  if (allProds.success) productCount = (allProds.data as List).length;

  if (results[2].success) memberCount = (results[2].data as List).length;
  if (results[3].success) activePl = (results[3].data as List).length;

  int openSess = 0;
  Map<String, dynamic>? tb;
  Map<String, dynamic>? incStmt;

  if (selection.hasBranch) {
    final sess = await client.listPosSessions(selection.branchId!, status: 'open');
    if (sess.success) openSess = (sess.data as List).length;
  }
  if (selection.hasEntity) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final tbR = await client.trialBalance(selection.entityId!, asOf: today);
    if (tbR.success) tb = Map<String, dynamic>.from(tbR.data);
    final monthStart = '${today.substring(0, 7)}-01';
    final isR = await client.incomeStatement(selection.entityId!, monthStart, today);
    if (isR.success) incStmt = Map<String, dynamic>.from(isR.data);
  }

  return DashboardData(
    entityCount: entityCount,
    branchCount: branchCount,
    productCount: productCount,
    memberCount: memberCount,
    activePriceLists: activePl,
    openSessions: openSess,
    todayTrialBalance: tb,
    monthIncome: incStmt,
  );
});
