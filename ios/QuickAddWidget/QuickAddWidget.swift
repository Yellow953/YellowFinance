import SwiftUI
import WidgetKit

// Static "Quick Add" home-screen widget: five buttons that deep-link into the
// app's add flows. It shows no user data, so it needs no App Group and its
// timeline never changes.
//
// The URLs are resolved by `HomeWidgetService` in Dart — keep them in sync with
// it and with the Android widget. The `homeWidget` query item is what the
// home_widget plugin uses to recognise a URL as a widget tap.

@main
struct QuickAddWidgetBundle: WidgetBundle {
  var body: some Widget {
    QuickAddWidget()
  }
}

struct QuickAddWidget: Widget {
  let kind = "QuickAddWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StaticProvider()) { _ in
      QuickAddView()
        .containerBackground(for: .widget) { Palette.surface }
    }
    .configurationDisplayName("Quick Add")
    .description("Add an expense, income, task, workout or diary entry in one tap.")
    // Individual buttons need Link, which the small family doesn't support.
    .supportedFamilies([.systemMedium])
    // The view sets its own 8pt padding so outer margin, gaps and corner
    // radii follow one spacing system instead of the default 16pt margins.
    .contentMarginsDisabled()
  }
}

/// A single entry that never expires — there is nothing to refresh.
struct StaticProvider: TimelineProvider {
  func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: .now) }

  func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
    completion(SimpleEntry(date: .now))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
    completion(Timeline(entries: [SimpleEntry(date: .now)], policy: .never))
  }
}

struct SimpleEntry: TimelineEntry {
  let date: Date
}

// MARK: - View

/// Layout constants: Home's add buttons (40pt chip, 22pt icon, 16pt label,
/// 12pt gap) scaled to widget size. The 8pt margin matches the 8pt gap between
/// tiles, and tile corners are the widget's ~22pt radius minus that margin so
/// the curves stay concentric. The narrowest medium widget (292pt, iPhone SE)
/// still fits a chip and "Sport" in each bottom tile.
private enum Metrics {
  static let padding: CGFloat = 8
  static let gap: CGFloat = 8
  static let tileRadius: CGFloat = 14
  static let chip: CGFloat = 28
  static let chipRadius: CGFloat = 8
  static let icon: CGFloat = 14
  static let label: CGFloat = 14
}

struct QuickAddView: View {
  var body: some View {
    VStack(spacing: Metrics.gap) {
      // Money is logged most often, so it gets the larger top row.
      HStack(spacing: Metrics.gap) {
        Tile(action: "expense", title: "Expense", symbol: "minus", tint: Palette.danger, dark: true)
        Tile(action: "income", title: "Income", symbol: "plus", tint: Palette.success)
      }
      HStack(spacing: Metrics.gap) {
        Tile(action: "task", title: "Task", symbol: "checkmark.circle", tint: Palette.dark)
        Tile(action: "sport", title: "Sport", symbol: "dumbbell.fill", tint: Palette.dark)
        Tile(action: "diary", title: "Diary", symbol: "book.fill", tint: Palette.dark)
      }
    }
    .padding(Metrics.padding)
  }
}

/// One deep-link button: a tinted icon chip and a label, centered in the tile.
private struct Tile: View {
  let action: String
  let title: String
  let symbol: String
  let tint: Color
  var dark = false

  var body: some View {
    Link(destination: URL(string: "yellowfinance://add/\(action)?homeWidget")!) {
      HStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.system(size: Metrics.icon, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: Metrics.chip, height: Metrics.chip)
          .background(
            tint.opacity(dark ? 0.2 : 0.1),
            in: RoundedRectangle(cornerRadius: Metrics.chipRadius, style: .continuous)
          )
          .widgetAccentable()
        Text(title)
          .font(.system(size: Metrics.label, weight: .semibold))
          .foregroundStyle(dark ? Palette.surface : Palette.dark)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .padding(.horizontal, 6)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        dark ? Palette.dark : Palette.tile,
        in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
      )
    }
    .accessibilityLabel("Add \(title.lowercased())")
  }
}

/// Mirrors `AppColors` in `lib/core/constants/app_colors.dart`.
private enum Palette {
  static let surface = Color.white
  static let dark = Color(red: 0x11 / 255, green: 0x11 / 255, blue: 0x11 / 255)
  static let tile = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF4 / 255)
  static let success = Color(red: 0x22 / 255, green: 0xC5 / 255, blue: 0x5E / 255)
  static let danger = Color(red: 0xEF / 255, green: 0x44 / 255, blue: 0x44 / 255)
}

#Preview(as: .systemMedium) {
  QuickAddWidget()
} timeline: {
  SimpleEntry(date: .now)
}
