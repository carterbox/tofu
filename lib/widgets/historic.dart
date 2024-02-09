import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart' as chart;

import '../data/green_button.dart';
import '../data/comed.dart';
import 'polar.dart';

import 'dart:math' as math;
import 'dart:io';

final energyUseProvider = StateNotifierProvider<HistoricEnergyUseClockNotifier,
    HistoricEnergyUseClockState>((ref) {
  return HistoricEnergyUseClockNotifier();
});

@immutable
class HistoricEnergyUseClockState {
  final HourlyEnergyUse historicEnergyUse;
  final HourlyEnergyUse filteredHistoricEnergyUse;
  final CentPerEnergyRates historicEnergyRates;
  final CentPerEnergyRates filteredHistoricEnergyRates;
  final Set<int> weekdays;
  final double averageRate;

  const HistoricEnergyUseClockState({
    required this.historicEnergyUse,
    required this.filteredHistoricEnergyUse,
    required this.historicEnergyRates,
    required this.filteredHistoricEnergyRates,
    required this.weekdays,
    this.averageRate = double.nan,
  });

  factory HistoricEnergyUseClockState.fromUnfiltered({
    required HourlyEnergyUse historicEnergyUse,
    required CentPerEnergyRates historicEnergyRates,
  }) {
    return HistoricEnergyUseClockState(
        historicEnergyUse: historicEnergyUse,
        filteredHistoricEnergyUse: historicEnergyUse,
        historicEnergyRates: historicEnergyRates,
        filteredHistoricEnergyRates: historicEnergyRates,
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
        averageRate: computeAverageRate(
          historicEnergyUse.usage,
          historicEnergyRates.rates,
        ));
  }

  HistoricEnergyUseClockState filterByWeekday(Set<int> weekdays) {
    final filteredUsage = historicEnergyUse.filterByWeekday(weekdays);
    final filteredRates = historicEnergyRates.filterByWeekday(weekdays);
    return HistoricEnergyUseClockState(
      historicEnergyUse: historicEnergyUse,
      filteredHistoricEnergyUse: filteredUsage,
      historicEnergyRates: historicEnergyRates,
      filteredHistoricEnergyRates: filteredRates,
      weekdays: weekdays,
      averageRate: computeAverageRate(
        filteredUsage.usage,
        filteredRates.rates,
      ),
    );
  }
}

class HistoricEnergyUseClockControllerButton extends StatelessWidget {
  const HistoricEnergyUseClockControllerButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget controller = Scaffold(
      appBar: AppBar(
        title: const Text('Filter Settings'),
      ),
      body: HistoricEnergyUseClockController(stateProvider: energyUseProvider),
    );
    return FloatingActionButton(
      tooltip: 'Load and filter data',
      heroTag: 'controller',
      child: const Icon(Icons.filter_list),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => controller,
          ),
        );
      },
    );
  }
}

class Legend extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;

  const Legend({
    super.key,
    required this.labels,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    var chips = <Chip>[];
    for (var i = 0; i < labels.length; ++i) {
      chips.add(Chip(
        avatar: CircleAvatar(
          backgroundColor: colors[i],
        ),
        label: Text(labels[i]),
        backgroundColor: Colors.transparent,
      ));
    }
    return Align(
      alignment: Alignment.topCenter,
      child: Wrap(
        spacing: 5.0,
        runSpacing: 5.0,
        children: chips,
      ),
    );
  }
}

class HistoricEnergyUseClock extends StatelessWidget {
  final double radius;
  final HistoricEnergyUseClockState? state;

  const HistoricEnergyUseClock({
    super.key,
    this.state,
    this.radius = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        LayoutBuilder(builder: (context, constraints) {
          if (state == null ){
            return const Placeholder();
          }

          final theme = Theme.of(context);
          final double maxAllowedRadius = 0.4 *
              math.min(
                constraints.maxHeight,
                constraints.maxWidth,
              );

          final centerSpaceRadius = maxAllowedRadius * 0.25;
          final barMaxRadialSize = maxAllowedRadius - centerSpaceRadius;

          final usage = state!.filteredHistoricEnergyUse.hourlyAverages();
          final rates = state!.filteredHistoricEnergyRates.hourlyAverages();
          final double maximumUsage =
              usage.reduce((max, element) => element > max ? element : max);
          final double maximumRates =
              rates.reduce((max, element) => element > max ? element : max);
          var sections = List<chart.PieChartSectionData>.empty(growable: true);
          var offsets = List<double>.empty(growable: true);
          // final importantUsage = getHighlights(usage);
          final importantRates = getHighlights(rates);
          for (int hour = 0; hour < 24; hour++) {
            offsets.add(createOffset(
              value: usage[hour],
              maxValue: maximumUsage,
              centerSpaceRadius: centerSpaceRadius,
              barMaxRadialSize: barMaxRadialSize,
            ));
            sections.add(createSection(
              value: rates[hour],
              units: state!.historicEnergyRates.units,
              color: theme.colorScheme.primaryContainer,
              isImportant: importantRates.contains(rates[hour]),
              barMaxRadialSize: barMaxRadialSize,
              centerSpaceRadius: centerSpaceRadius,
              maxValue: maximumRates,
              colorBorder: theme.colorScheme.onPrimaryContainer,
              colorText: theme.colorScheme.onPrimaryContainer,
              colorTextShadow: theme.colorScheme.primaryContainer,
            ));
          }
          return Stack(children: [
            chart.PieChart(
              chart.PieChartData(
                sections: sections,
                centerSpaceRadius: centerSpaceRadius,
                startDegreeOffset: (360 / 24) * 5,
              ),
            ),
            PolarLineChart(
              radius: centerSpaceRadius,
              offsets: offsets,
              color: theme.colorScheme.tertiaryContainer,
              startRadianOffset: math.pi / 24 * 11,
            ),
          ]);
        }),
        Legend(
          labels: const [
            'Energy Use',
            'Energy Rates',
          ],
          colors: [
            theme.colorScheme.tertiaryContainer,
            theme.colorScheme.primaryContainer,
          ],
        ),
      ],
    );
  }
}

class HistoricEnergyUseClockNotifier
    extends StateNotifier<HistoricEnergyUseClockState> {
  HistoricEnergyUseClockNotifier()
      : super(const HistoricEnergyUseClockState(
          historicEnergyUse: HourlyEnergyUse(usage: {}),
          filteredHistoricEnergyUse: HourlyEnergyUse(usage: {}),
          historicEnergyRates: CentPerEnergyRates(rates: {}),
          filteredHistoricEnergyRates: CentPerEnergyRates(rates: {}),
          weekdays: {1, 2, 3, 4, 5, 6, 7},
        ));

  void changeEnergyUse(HourlyEnergyUse newUse, CentPerEnergyRates newRates) {
    state = HistoricEnergyUseClockState.fromUnfiltered(
      historicEnergyUse: newUse,
      historicEnergyRates: newRates,
    ).filterByWeekday(state.weekdays);
  }

  void changeFilter(Set<int> newWeekdays) {
    state = state.filterByWeekday(
      newWeekdays,
    );
  }
}

class HistoricEnergyUseClockController extends ConsumerWidget {
  final StateNotifierProvider<HistoricEnergyUseClockNotifier,
      HistoricEnergyUseClockState> stateProvider;

  static const Map<String, int> dayNames = {
    'monday': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'friday': DateTime.friday,
    'saturday': DateTime.saturday,
    'sunday': DateTime.sunday,
  };

  const HistoricEnergyUseClockController({
    super.key,
    required this.stateProvider,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    HistoricEnergyUseClockState state = ref.watch(stateProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;

    String averagePriceMessage = '';
    if (state.averageRate.isFinite) {
      averagePriceMessage =
          'The average price for electricity only is ${state.averageRate.toStringAsFixed(3)} ${state.filteredHistoricEnergyRates.units}. Other fees and charges may apply.';
    } else {
      averagePriceMessage = 'The average electricity price is unknown.';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 5.0),
          FilledButton(
            child: const Text('Load your usage data'),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform
                  .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
              // The result will be null, if the user aborted the dialog
              if (result != null) {
                File file = File(result.files.first.path!);
                final newUsage = HourlyEnergyUse.fromComEdCsvFile(file);
                final dateRange = newUsage.getDateRange();
                final newRates = await fetchHistoricHourlyRatesDayRange(
                  dateRange[0],
                  dateRange[1],
                );
                // TODO: Add a loading state here while awaiting results?
                ref.read(stateProvider.notifier).changeEnergyUse(
                      newUsage,
                      newRates,
                    );
              }
            },
          ),
          const SizedBox(height: 30.0),
          Text('Filter by weekday', style: textTheme.titleLarge),
          const SizedBox(height: 10.0),
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 5.0,
            runSpacing: 5.0,
            children: dayNames.entries.map((entry) {
              return FilterChip(
                label: Text(entry.key),
                selected: state.weekdays.contains(entry.value),
                onSelected: (bool selected) {
                  Set<int> newWeekdays = Set.from(state.weekdays);
                  if (selected) {
                    newWeekdays.add(entry.value);
                  } else {
                    newWeekdays.remove(entry.value);
                  }
                  ref.read(stateProvider.notifier).changeFilter(newWeekdays);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10.0),
          Text(
            averagePriceMessage,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 10.0),
        ],
      ),
    );
  }
}

class HistoricEnergyUseExplainer extends StatelessWidget {
  const HistoricEnergyUseExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'What is your historic energy use?',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(2.0),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'This chart shows the average hourly energy use from your Green Button Download.',
              textAlign: TextAlign.left,
              textScaler: TextScaler.linear(1.0),
            ),
          ),
        ],
      ),
    );
  }
}

/// A button which toggles a model bottom sheet containing HistoricEnergyUseExplainer
class HistoricEnergyUseExplainerButton extends StatelessWidget {
  const HistoricEnergyUseExplainerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton.small(
      tooltip: 'Explain chart',
      heroTag: 'explainer',
      child: const Icon(Icons.question_mark),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: colorScheme.primaryContainer,
          builder: (BuildContext context) {
            return const HistoricEnergyUseExplainer();
          },
        );
      },
    );
  }
}
