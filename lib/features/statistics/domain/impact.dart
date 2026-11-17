import '../../donations/domain/donation.dart';
import '../../fridge/domain/fridge_event.dart';

// -----------------------------------------------------------------------------
// Estimates (see docs/SPEC_MEMBRE5.md §2). Simplified, per food category.
// -----------------------------------------------------------------------------

/// A meal is about 400 g of food.
const mealWeightKg = 0.4;

/// Average car: about 120 g of CO₂ per km.
const carCo2KgPerKm = 0.12;

/// Average weight (kg) of one piece or pack, for foods counted in pcs/pack.
const pieceWeightKgByCategory = <String, double>{
  'fruits': 0.15,
  'vegetables': 0.25,
  'dairy': 0.2,
  'meat & fish': 0.3,
  'bakery': 0.4,
  'pantry': 0.5,
  'beverages': 1.0,
  'frozen': 0.4,
  'leftovers': 0.3,
};
const defaultPieceWeightKg = 0.25;

/// kg of CO₂-equivalent emitted to produce 1 kg of food (simplified from
/// Poore & Nemecek 2018, Our World in Data).
const co2KgPerKgByCategory = <String, double>{
  'fruits': 0.7,
  'vegetables': 0.8,
  'dairy': 4.0,
  'meat & fish': 15.0,
  'bakery': 1.6,
  'pantry': 2.5,
  'beverages': 1.0,
  'frozen': 4.0,
  'leftovers': 3.0,
};
const defaultCo2KgPerKg = 2.5;

/// Estimated weight in kg of [quantity] [unit] of a food of [category].
double foodWeightKg(double quantity, String unit, String category) {
  if (quantity <= 0) {
    return 0;
  }
  switch (unit.trim().toLowerCase()) {
    case 'kg':
    case 'l':
      return quantity;
    case 'g':
    case 'ml':
      return quantity / 1000;
    default:
      return quantity *
          (pieceWeightKgByCategory[category.trim().toLowerCase()] ??
              defaultPieceWeightKg);
  }
}

/// Estimated CO₂ (kg) emitted to produce [weightKg] of a food of [category].
double co2ForKg(double weightKg, String category) =>
    weightKg *
    (co2KgPerKgByCategory[category.trim().toLowerCase()] ?? defaultCo2KgPerKg);

/// Meals that [weightKg] of food represents. At least 1 as soon as some
/// food was saved.
int mealsForKg(double weightKg) {
  if (weightKg <= 0) {
    return 0;
  }
  final meals = (weightKg / mealWeightKg).round();
  return meals < 1 ? 1 : meals;
}

// -----------------------------------------------------------------------------
// Saved and wasted food
// -----------------------------------------------------------------------------

/// Where a saved (or wasted) food comes from.
enum ImpactSource {
  eaten('Eaten'),
  cooked('Cooked in recipes'),
  donated('Donated'),
  wasted('Wasted');

  const ImpactSource(this.label);

  final String label;

  bool get isSaved => this != ImpactSource.wasted;
}

/// One food that was saved from waste, or thrown away.
class ImpactEntry {
  const ImpactEntry({
    required this.source,
    required this.at,
    required this.foodName,
    required this.category,
    required this.weightKg,
  });

  final ImpactSource source;
  final DateTime at;
  final String foodName;
  final String category;
  final double weightKg;

  double get co2Kg => co2ForKg(weightKg, category);
}

/// Saved and wasted foods, from the fridge history (Membre 2) and the
/// collected donations.
List<ImpactEntry> impactEntries(
  List<FridgeEvent> history,
  List<Donation> donations,
) {
  return [
    for (final event in history)
      ImpactEntry(
        source: event.isWaste
            ? ImpactSource.wasted
            : (event.recipe == null ? ImpactSource.eaten : ImpactSource.cooked),
        at: event.at,
        foodName: event.foodName,
        category: event.category.name,
        weightKg: foodWeightKg(event.quantity, event.unit, event.category.name),
      ),
    for (final donation in donations)
      if (donation.status == DonationStatus.collected)
        ImpactEntry(
          source: ImpactSource.donated,
          at: donation.collectedAt ?? donation.createdAt,
          foodName: donation.foodName,
          category: donation.category.name,
          weightKg: foodWeightKg(
            donation.quantity,
            donation.unit,
            donation.category.name,
          ),
        ),
  ];
}

// -----------------------------------------------------------------------------
// Statistics
// -----------------------------------------------------------------------------

enum StatsPeriod {
  week('This week', 7),
  month('This month', 30),
  allTime('All time', null);

  const StatsPeriod(this.label, this.days);

  final String label;

  /// Number of days counted (today included), null for all time.
  final int? days;
}

/// Saved and wasted foods of one day.
class DayImpact {
  const DayImpact({
    required this.date,
    required this.saved,
    required this.wasted,
  });

  final DateTime date;
  final int saved;
  final int wasted;

  int get total => saved + wasted;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Meals saved, environmental impact and anti-waste score over a period.
///
/// Never stored: always computed from the fridge history and the donations.
class ImpactStats {
  ImpactStats(
    List<ImpactEntry> entries,
    DateTime now, {
    this.period = StatsPeriod.allTime,
  }) : _today = _dateOnly(now),
       _allEntries = entries {
    final days = period.days;
    final from = days == null
        ? null
        : _today.subtract(Duration(days: days - 1));
    this.entries = [
      for (final entry in entries)
        if (from == null || !_dateOnly(entry.at).isBefore(from)) entry,
    ];
  }

  factory ImpactStats.from({
    required List<FridgeEvent> history,
    required List<Donation> donations,
    required DateTime now,
    StatsPeriod period = StatsPeriod.allTime,
  }) => ImpactStats(impactEntries(history, donations), now, period: period);

  final StatsPeriod period;
  final DateTime _today;
  final List<ImpactEntry> _allEntries;

  /// Entries of [period].
  late final List<ImpactEntry> entries;

  Iterable<ImpactEntry> get _saved => entries.where((e) => e.source.isSaved);
  Iterable<ImpactEntry> get _wasted => entries.where((e) => !e.source.isSaved);

  bool get isEmpty => entries.isEmpty;

  int get savedCount => _saved.length;

  int get wastedCount => _wasted.length;

  double get savedKg => _saved.fold(0, (sum, e) => sum + e.weightKg);

  double get wastedKg => _wasted.fold(0, (sum, e) => sum + e.weightKg);

  int get mealsSaved => mealsForKg(savedKg);

  double get co2AvoidedKg => _saved.fold(0, (sum, e) => sum + e.co2Kg);

  double get co2LostKg => _wasted.fold(0, (sum, e) => sum + e.co2Kg);

  /// Distance by car emitting as much CO₂ as [co2AvoidedKg].
  double get carKm => co2AvoidedKg / carCo2KgPerKm;

  /// Share of foods saved instead of thrown away, from 0 to 100.
  /// Null while there is nothing to count.
  int? get score {
    final total = entries.length;
    return total == 0 ? null : (savedCount * 100 / total).round();
  }

  /// Number of saved foods coming from [source].
  int countFor(ImpactSource source) =>
      entries.where((entry) => entry.source == source).length;

  /// The last [days] days (oldest first), whatever the [period].
  List<DayImpact> lastDays([int days = 7]) {
    return [
      for (var offset = days - 1; offset >= 0; offset--)
        _dayImpact(_today.subtract(Duration(days: offset))),
    ];
  }

  DayImpact _dayImpact(DateTime date) {
    var saved = 0;
    var wasted = 0;
    for (final entry in _allEntries) {
      if (_dateOnly(entry.at) == date) {
        entry.source.isSaved ? saved++ : wasted++;
      }
    }
    return DayImpact(date: date, saved: saved, wasted: wasted);
  }
}

/// e.g. 0.25 -> "0.3", 3 -> "3", 12.46 -> "12.5", 150.2 -> "150".
String formatAmount(double value) {
  if (value >= 100) {
    return value.round().toString();
  }
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toInt().toString()
      : rounded.toStringAsFixed(1);
}
