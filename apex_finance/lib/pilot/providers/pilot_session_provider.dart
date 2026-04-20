/// Pilot Session Provider — الحالة العامة للعميل الحالي
/// ═════════════════════════════════════════════════════════════
/// يحتفظ بالـ tenant / entity / branch النشط عبر الجلسة.
/// كل شاشة pilot تقرأ من هنا بدلاً من تمرير IDs يدوياً.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/pilot_client.dart';

/// Selection state — مُعرِّفات الـ tenant/entity/branch المختارة.
class PilotSelection {
  final String? tenantId;
  final String? tenantSlug;
  final String? tenantNameAr;
  final String? entityId;
  final String? entityCode;
  final String? entityNameAr;
  final String? entityCountry;
  final String? functionalCurrency;
  final String? branchId;
  final String? branchCode;
  final String? branchNameAr;

  const PilotSelection({
    this.tenantId,
    this.tenantSlug,
    this.tenantNameAr,
    this.entityId,
    this.entityCode,
    this.entityNameAr,
    this.entityCountry,
    this.functionalCurrency,
    this.branchId,
    this.branchCode,
    this.branchNameAr,
  });

  bool get hasTenant => tenantId != null;
  bool get hasEntity => entityId != null;
  bool get hasBranch => branchId != null;

  PilotSelection copyWith({
    String? tenantId,
    String? tenantSlug,
    String? tenantNameAr,
    String? entityId,
    String? entityCode,
    String? entityNameAr,
    String? entityCountry,
    String? functionalCurrency,
    String? branchId,
    String? branchCode,
    String? branchNameAr,
  }) =>
      PilotSelection(
        tenantId: tenantId ?? this.tenantId,
        tenantSlug: tenantSlug ?? this.tenantSlug,
        tenantNameAr: tenantNameAr ?? this.tenantNameAr,
        entityId: entityId ?? this.entityId,
        entityCode: entityCode ?? this.entityCode,
        entityNameAr: entityNameAr ?? this.entityNameAr,
        entityCountry: entityCountry ?? this.entityCountry,
        functionalCurrency: functionalCurrency ?? this.functionalCurrency,
        branchId: branchId ?? this.branchId,
        branchCode: branchCode ?? this.branchCode,
        branchNameAr: branchNameAr ?? this.branchNameAr,
      );

  /// إعادة تعيين الـ entity + branch (عند تغيير tenant)
  PilotSelection resetEntityAndBranch() => PilotSelection(
        tenantId: tenantId,
        tenantSlug: tenantSlug,
        tenantNameAr: tenantNameAr,
      );

  /// إعادة تعيين الـ branch (عند تغيير entity)
  PilotSelection resetBranch() => PilotSelection(
        tenantId: tenantId,
        tenantSlug: tenantSlug,
        tenantNameAr: tenantNameAr,
        entityId: entityId,
        entityCode: entityCode,
        entityNameAr: entityNameAr,
        entityCountry: entityCountry,
        functionalCurrency: functionalCurrency,
      );
}

class PilotSessionNotifier extends StateNotifier<PilotSelection> {
  PilotSessionNotifier() : super(const PilotSelection());

  void selectTenant({required String id, String? slug, String? nameAr}) {
    state = PilotSelection(
      tenantId: id,
      tenantSlug: slug,
      tenantNameAr: nameAr,
    );
  }

  void selectEntity({
    required String id,
    String? code,
    String? nameAr,
    String? country,
    String? functionalCurrency,
  }) {
    state = state.resetBranch().copyWith(
          entityId: id,
          entityCode: code,
          entityNameAr: nameAr,
          entityCountry: country,
          functionalCurrency: functionalCurrency,
        );
  }

  void selectBranch({required String id, String? code, String? nameAr}) {
    state = state.copyWith(
      branchId: id,
      branchCode: code,
      branchNameAr: nameAr,
    );
  }

  void clear() => state = const PilotSelection();
}

final pilotSessionProvider =
    StateNotifierProvider<PilotSessionNotifier, PilotSelection>(
  (ref) => PilotSessionNotifier(),
);

/// Pilot client singleton (for injection in FutureProviders)
final pilotClientProvider = Provider<PilotClient>((ref) => pilotClient);
