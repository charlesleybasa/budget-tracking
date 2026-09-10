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

struct PocketConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Pocket Configuration"
    static let description = IntentDescription("Configure the Pesolita Pocket widget.")

    @Parameter(title: "Show Money Amount", default: true)
    var showAmount: Bool
}

struct TogglePrivacyIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Privacy"
    static let description = IntentDescription("Show or hide money amounts on the widget.")

    func perform() async throws -> some IntentResult {
        let payload = WidgetSharedStore.loadPayload()
        let currentPrivacy = WidgetSharedStore.getPrivacyOverride() ?? payload.privacyEnabled
        WidgetSharedStore.togglePrivacyOverride(currentPrivacy: currentPrivacy)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSharedStore.widgetKind)
        return .result()
    }
}
