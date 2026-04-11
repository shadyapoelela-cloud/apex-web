import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_service.dart';
import '../core/session.dart';

// ── Auth State ──
class AuthState {
  final bool isLoggedIn;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? user;
  const AuthState({this.isLoggedIn = false, this.isLoading = false, this.error, this.user});
  AuthState copyWith({bool? isLoggedIn, bool? isLoading, String? error, Map<String, dynamic>? user}) =>
    AuthState(isLoggedIn: isLoggedIn ?? this.isLoggedIn, isLoading: isLoading ?? this.isLoading,
      error: error, user: user ?? this.user);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final r = await ApiService.login(username, password);
    if (r.success) {
      final tokens = r.data['tokens'] ?? {};
      final user = r.data['user'] ?? {};
      S.token = tokens['access_token'];
      S.uid = user['id'];
      S.uname = user['username'];
      S.dname = user['display_name'];
      S.plan = user['plan'];
      S.email = user['email'];
      S.roles = List<String>.from(user['roles'] ?? []);
      state = state.copyWith(isLoggedIn: true, isLoading: false, user: user);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: r.error);
      return false;
    }
  }

  Future<bool> register({required String username, required String email, required String password, String? displayName}) async {
    state = state.copyWith(isLoading: true, error: null);
    final r = await ApiService.register(username: username, email: email, password: password, displayName: displayName);
    if (r.success) {
      final tokens = r.data['tokens'] ?? {};
      final user = r.data['user'] ?? {};
      S.token = tokens['access_token'];
      S.uid = user['id'];
      S.uname = user['username'];
      S.dname = user['display_name'];
      S.plan = user['plan'];
      S.email = user['email'];
      state = state.copyWith(isLoggedIn: true, isLoading: false, user: user);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: r.error);
      return false;
    }
  }

  void logout() {
    S.clear();
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());

// ── Theme & Language State ──
class AppSettingsState {
  final bool isDarkMode;
  final String language; // 'ar' or 'en'
  const AppSettingsState({this.isDarkMode = true, this.language = 'ar'});
  AppSettingsState copyWith({bool? isDarkMode, String? language}) =>
    AppSettingsState(isDarkMode: isDarkMode ?? this.isDarkMode, language: language ?? this.language);
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  AppSettingsNotifier() : super(const AppSettingsState());

  void toggleDarkMode(bool v) => state = state.copyWith(isDarkMode: v);
  void setLanguage(String lang) => state = state.copyWith(language: lang);
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettingsState>(
  (ref) => AppSettingsNotifier(),
);

// ── Client State ──
final clientsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final r = await ApiService.listClients();
  if (r.success) return r.data['clients'] ?? r.data ?? [];
  return [];
});

final clientTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final r = await ApiService.getClientTypes();
  if (r.success) return r.data is List ? r.data : r.data['data'] ?? [];
  return [];
});

// ── Service Catalog ──
final serviceCatalogProvider = FutureProvider.family<List<dynamic>, String?>((ref, category) async {
  final r = await ApiService.getServiceCatalog(category: category);
  if (r.success) return r.data['data'] ?? [];
  return [];
});

// ── Onboarding ──
final legalEntityTypesProvider = FutureProvider<List<dynamic>>((ref) async {
  final r = await ApiService.getLegalEntityTypes();
  if (r.success) return r.data['data'] ?? [];
  return [];
});

final sectorsProvider = FutureProvider<List<dynamic>>((ref) async {
  final r = await ApiService.getSectors();
  if (r.success) return r.data['data'] ?? [];
  return [];
});

final subSectorsProvider = FutureProvider.family<List<dynamic>, String>((ref, mainCode) async {
  final r = await ApiService.getSubSectors(mainCode);
  if (r.success) return r.data['data'] ?? [];
  return [];
});

// ── Archive ──
final userArchiveProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, page) async {
  final r = await ApiService.getUserArchive(page: page);
  if (r.success) return r.data;
  return {'data': [], 'total': 0};
});

// ── Notifications ──
final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final r = await ApiService.getNotifications();
  if (r.success) return r.data['notifications'] ?? r.data ?? [];
  return [];
});

// ── Plan ──
final currentPlanProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final r = await ApiService.getCurrentPlan();
  if (r.success) return r.data is Map ? r.data : {};
  return {};
});

final plansProvider = FutureProvider<List<dynamic>>((ref) async {
  final r = await ApiService.getPlans();
  if (r.success) return r.data is List ? r.data : r.data['plans'] ?? [];
  return [];
});
