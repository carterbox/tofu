// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'historic.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HistoricEnergyUseClockNotifier)
final historicEnergyUseClockProvider =
    HistoricEnergyUseClockNotifierProvider._();

final class HistoricEnergyUseClockNotifierProvider extends $NotifierProvider<
    HistoricEnergyUseClockNotifier, HistoricEnergyUseClockState?> {
  HistoricEnergyUseClockNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'historicEnergyUseClockProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$historicEnergyUseClockNotifierHash();

  @$internal
  @override
  HistoricEnergyUseClockNotifier create() => HistoricEnergyUseClockNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HistoricEnergyUseClockState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HistoricEnergyUseClockState?>(value),
    );
  }
}

String _$historicEnergyUseClockNotifierHash() =>
    r'19f5b210bcb2bc7c51a9ddc78a1e2cd627e1c9d7';

abstract class _$HistoricEnergyUseClockNotifier
    extends $Notifier<HistoricEnergyUseClockState?> {
  HistoricEnergyUseClockState? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<HistoricEnergyUseClockState?, HistoricEnergyUseClockState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<HistoricEnergyUseClockState?, HistoricEnergyUseClockState?>,
        HistoricEnergyUseClockState?,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
