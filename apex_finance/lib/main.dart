import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_service.dart';
import 'core/session.dart';
import 'core/v5/v5_routing_validator.dart';

// G-TREESHAKE-FIX-2 (2026-05-07): direct imports of widgets that are
// reachable only through the v5WiredScreens Map. The Offstage sentinel
// tree below mounts one instance of each so the framework's
// createElement → createState → build path keeps every State class
// alive in release builds. Construction-only references (PR #164) and
// switch-based touches were both elided by dart2js. See main() for the
// mount site.
import 'screens/operations/ar_aging_screen.dart';
import 'screens/operations/ap_aging_screen.dart';
import 'screens/operations/receipt_capture_screen.dart';
import 'screens/operations/sales_invoices_screen.dart';
import 'screens/v5_2/vat_return_v52_screen.dart';
import 'screens/v4_erp/cash_flow_forecast_screen.dart';
import 'screens/v4_erp/activity_log_screen.dart';
import 'screens/compliance/tax_timeline_screen.dart';
import 'screens/compliance/zatca_status_center_screen.dart';
import 'screens/v4_compliance/wht_calculator_v5_screen.dart';
import 'screens/v4_compliance/zakat_calculator_v5_screen.dart';
import 'screens/settings/entity_setup_screen.dart';
import 'screens/finance/trial_balance_screen.dart';
import 'screens/finance/income_statement_screen.dart';
import 'screens/finance/balance_sheet_screen.dart';

// Sprint-1 refactor: the root widget now lives in app/apex_app.dart.
// Re-exported so existing imports of `package:apex_finance/main.dart`
// that rely on `ApexApp` still resolve without source-level churn.
export 'app/apex_app.dart' show ApexApp;
import 'app/apex_app.dart' show ApexApp;

Future<void> main() async {
  // G-CLEANUP-2 (Sprint 15): main is now async because we await a
  // backend round-trip to validate any restored token before trusting
  // it. WidgetsFlutterBinding.ensureInitialized() is required when
  // main is async per Flutter convention.
  WidgetsFlutterBinding.ensureInitialized();

  // Restore session from localStorage.
  if (S.token == null) {
    final restored = S.restore();
    if (restored && S.token != null) {
      ApiService.setToken(S.token!);

      // G-CLEANUP-2 (Sprint 15): a non-null token in localStorage from
      // a previous session is NOT enough — it might be expired (60-min
      // access-token lifetime per app/phase1/services/auth_service.py:46)
      // or signed by a rotated JWT_SECRET. Validate against the backend
      // before trusting it. On any failure, clear the token so the
      // GoRouter auth guard (lib/core/auth_guard.dart) redirects the
      // user to /login.
      //
      // The operator's directive (file 39 § 5): bare-URL visitors must
      // land on /login, not on /app with a stale session. This async
      // probe is the mechanism that delivers that promise.
      //
      // Fail-closed: if validation can't reach the backend (network
      // error, timeout, etc.), we treat the token as invalid and
      // redirect to /login. Better to over-redirect than to under-
      // redirect.
      //
      // See APEX_BLUEPRINT/09 § 20.1 G-CLEANUP-2.
      final isValid = await ApiService.validateToken();
      if (!isValid) {
        S.clear();
        ApiService.clearToken();
      }
    }
  }

  if (kDebugMode) validatePins();

  runApp(const ProviderScope(
    child: _AppWithKeepAlive(),
  ));
}

// G-TREESHAKE-FIX-2 (2026-05-07) — Offstage-mounted sentinel tree.
//
// Wraps [ApexApp] in a Stack whose second child is an Offstage subtree
// containing one instance of every widget that's only referenced from
// the v5WiredScreens Map<String, V5ChipBuilder>. dart2js was eliding
// the State class bodies of these widgets despite the Map's closures
// being preserved. Mounting them — even invisibly — forces the
// framework to call createElement → createState → build, which dart2js
// must keep alive.
//
// Trade-offs (accepted):
// - Each sentinel widget runs initState once at startup. Some of those
//   call ApiService methods (e.g. TaxTimelineScreen → aiTaxTimeline).
//   The cost is one extra round-trip per screen at startup. The
//   alternative is shipping a UI that shows "قيد البناء" for chips
//   the user actually wired in PR #161.
// - TickerMode(enabled: false) suppresses any AnimationController
//   updates the screens schedule.
// - Offstage(offstage: true) prevents the subtree from painting,
//   taking layout space, or receiving hits. It still builds.
// - The MaterialApp inside the sentinel provides Theme / Directionality
//   / MediaQuery / Navigator inheritance so screens that read
//   Theme.of(context) etc. don't throw during construction.
//
// Earlier attempts that dart2js folded away (verified bundle byte-
// identical or near-identical):
//   - PR #164: const Type list + contains() check; final widget list
//     + length print; switch with runtime index + runtimeType print.
// All defeated by dart2js elision of State classes whose only
// activation path was through the wired-screens Map.
class _AppWithKeepAlive extends StatelessWidget {
  const _AppWithKeepAlive();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        children: [
          const ApexApp(),
          // Sentinel positioned offstage AND off-screen. Either alone
          // would suffice; both together belt-and-braces.
          const _V5KeepAliveSentinel(),
        ],
      ),
    );
  }
}

class _V5KeepAliveSentinel extends StatelessWidget {
  const _V5KeepAliveSentinel();

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: TickerMode(
        enabled: false,
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: SizedBox(
              width: 1,
              height: 1,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: const SingleChildScrollView(
                  child: Column(
                    children: [
                      ArAgingScreen(),
                      ApAgingScreen(),
                      VatReturnV52Screen(),
                      CashFlowForecastScreen(),
                      TaxTimelineScreen(),
                      WhtCalculatorV5Screen(),
                      ZakatCalculatorV5Screen(),
                      ZatcaStatusCenterScreen(),
                      ActivityLogScreen(),
                      ReceiptCaptureScreen(),
                      EntitySetupScreen(),
                      SalesInvoicesScreen(),
                      // G-TB-DISPLAY-1 (2026-05-08).
                      TrialBalanceScreen(),
                      // G-FIN-IS-1 (2026-05-08).
                      IncomeStatementScreen(),
                      // G-FIN-BS-1 (2026-05-08).
                      BalanceSheetScreen(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
