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
                var insight: WordInsight
                var usedProvider = provider
                do {
                    insight = try await enricher.enrich(term: term)
                } catch let error as EnrichError where error.isGuardrail && GeminiEnricher.availabilityDescription == nil {
                    // 온디바이스 안전 필터에 막힌 단어는 Gemini 키가 있으면 대신 정리합니다.
                    insight = try await GeminiEnricher().enrich(term: term)
                    usedProvider = .gemini
                }
                word.meaning = insight.meaning
                word.partOfSpeech = insight.partOfSpeech
                word.pronunciation = insight.pronunciation
                word.examples = insight.examples
                word.synonyms = insight.synonyms
                word.usageNote = insight.usageNote
                word.aiProvider = usedProvider == provider ? provider.label : "\(usedProvider.label) (온디바이스 대신)"
                word.aiStatus = .done
                word.touch()
            } catch {
                word.aiStatus = .failed
                var message = error.localizedDescription
                if (error as? EnrichError)?.isGuardrail == true {
                    message += " 설정에서 AI를 Gemini로 바꾸고 'AI로 다시 정리'를 누르면 정리할 수 있어요."
                }
                word.aiError = message
            }
        }
    }
}
