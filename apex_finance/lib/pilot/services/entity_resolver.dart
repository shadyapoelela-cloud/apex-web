/// APEX — Entity Resolver helper (G-UX-1, Sprint 11).
///
/// Ensures an entity is selected before proceeding to entity-scoped
/// screens (JE Builder, AI Inbox, Bank Rec, etc.). Replaces the
/// historic dead-end pattern:
///
///     if (!PilotSession.hasEntity) {
///       _error = 'اختر الكيان من شريط العنوان أولاً';
///       return;  // user must figure out what to do next
///     }
///
/// with a graceful resolver:
///
///   1. Already has entity         → return true (no-op).
///   2. No tenant at all           → snackbar + redirect to onboarding.
///   3. Tenant set, 0 entities     → snackbar + redirect to onboarding.
///   4. Tenant set, exactly 1      → auto-select silently, return true.
///   5. Tenant set, multiple       → show TenantTreePicker, return based on pick.
///
/// Reuses existing infrastructure (`pilotClient.listEntities`,
/// `showTenantTreePicker`, onboarding wizard). No backend changes.
///
/// Usage in entity-scoped screens:
///
///     Future<void> _load() async {
///       if (!PilotSession.hasEntity) {
///         final ok = await EntityResolver.ensureEntitySelected(context);
///         if (!ok) {
///           setState(() => _loading = false);
///           return;
///         }
///       }
///       // entity is now set — continue with normal load
///       final eid = PilotSession.entityId!;
///       ...
///     }
///
/// Reference: G-UX-1 (Sprint 11). Companion gap G-UX-1.1 (deferred):
/// onboarding wizard auto-select first entity post-completion — would
/// remove the need for this helper's "0 entities → wizard" branch in
/// the freshly-completed-wizard case.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../api/pilot_client.dart';
import '../session.dart';
import '../tenant_tree_picker.dart';

class EntityResolver {
  /// Ensure `PilotSession.entityId` is set before the caller proceeds.
  ///
  /// Returns `true` if an entity is now selected (either via auto-select
  /// or via the picker). Returns `false` if the user was redirected to
  /// onboarding or cancelled the picker — in that case the caller should
  /// stop the current load and show its empty/no-entity state.
  static Future<bool> ensureEntitySelected(BuildContext context) async {
    if (PilotSession.hasEntity) return true;

    if (!PilotSession.hasTenant) {
      _showSnackbar(context, 'إعداد الكيان مطلوب — افتح معالج الإعداد أولاً.');
      if (!context.mounted) return false;
      context.go('/app/erp/finance/onboarding');
      return false;
    }

    // Have a tenant but no entity — try to auto-select if there's only one.
    try {
      final res = await pilotClient.listEntities(PilotSession.tenantId!);
      if (!res.success) {
        if (!context.mounted) return false;
        _showSnackbar(context, 'تعذّر تحميل الكيانات — حاول لاحقاً.');
        return false;
      }
      final entities = (res.data is List)
          ? List<Map<String, dynamic>>.from(res.data as List)
          : <Map<String, dynamic>>[];

      if (entities.isEmpty) {
        if (!context.mounted) return false;
        _showSnackbar(context, 'لا يوجد كيان مسجَّل — افتح معالج الإعداد.');
        context.go('/app/erp/finance/onboarding');
        return false;
      }

      if (entities.length == 1) {
        final id = entities.first['id'] as String?;
        if (id == null || id.isEmpty) {
          if (!context.mounted) return false;
          _showSnackbar(context, 'بيانات الكيان غير مكتملة.');
          return false;
        }
        PilotSession.entityId = id;
        return true;
      }

      // Multiple entities — let the user pick via the existing tree picker.
      if (!context.mounted) return false;
      await showTenantTreePicker(context);
      // After the picker closes, check whether the user actually picked one.
      return PilotSession.hasEntity;
    } catch (e) {
      if (!context.mounted) return false;
      _showSnackbar(context, 'تعذّر تحميل الكيانات: $e');
      return false;
    }
  }

  static void _showSnackbar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
