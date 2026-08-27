import AppIntents
import WidgetKit

struct PreviousPocketIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Pesolita card"
    static let description = IntentDescription("Shows the previous card in the Pesolita widget.")

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.moveSelection(by: -1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.widgetKind)
        return .result()
    }
}

struct NextPocketIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Pesolita card"
    static let description = IntentDescription("Shows the next card in the Pesolita widget.")

    func perform() async throws -> some IntentResult {
        WidgetSharedStore.moveSelection(by: 1)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.widgetKind)
        return .result()
    }
}
