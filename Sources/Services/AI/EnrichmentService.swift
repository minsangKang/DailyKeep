import Foundation
import SwiftUI

/// 단어를 저장하면 선택한 AI로 뜻·예문을 비동기로 채웁니다.
@Observable
final class EnrichmentService {
    static let providerKey = "aiProvider"

    var provider: AIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Self.providerKey) }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.providerKey).flatMap(AIProvider.init(rawValue:))
        provider = stored ?? AppConfig.defaultAIProvider
    }

    func availability(of provider: AIProvider) -> String? {
        switch provider {
        case .onDevice: OnDeviceEnricher.availabilityDescription
        case .gemini: GeminiEnricher.availabilityDescription
        }
    }

    private var enricher: any WordEnricher {
        switch provider {
        case .onDevice: OnDeviceEnricher()
        case .gemini: GeminiEnricher()
        }
    }

    func enrich(_ word: Word) {
        let term = word.title
        let enricher = enricher
        let provider = provider
        word.aiStatus = .pending
        word.aiError = ""
        Task {
            do {
                let insight = try await enricher.enrich(term: term)
                word.meaning = insight.meaning
                word.partOfSpeech = insight.partOfSpeech
                word.pronunciation = insight.pronunciation
                word.examples = insight.examples
                word.synonyms = insight.synonyms
                word.usageNote = insight.usageNote
                word.aiProvider = provider.label
                word.aiStatus = .done
                word.touch()
            } catch {
                word.aiStatus = .failed
                word.aiError = error.localizedDescription
            }
        }
    }
}
