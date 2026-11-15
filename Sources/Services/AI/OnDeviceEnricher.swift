import Foundation
import FoundationModels

/// Apple Foundation Models(온디바이스). 키가 필요 없고 Apple Intelligence가 켜진 기기에서 동작합니다.
struct OnDeviceEnricher: WordEnricher {
    static var availabilityDescription: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "이 기기는 Apple Intelligence를 지원하지 않습니다."
            case .appleIntelligenceNotEnabled: return "설정에서 Apple Intelligence를 켜야 합니다."
            case .modelNotReady: return "모델을 내려받는 중입니다. 잠시 후 다시 시도하세요."
            @unknown default: return "지금은 온디바이스 모델을 쓸 수 없습니다."
            }
        }
    }

    func enrich(term: String) async throws -> WordInsight {
        if let reason = Self.availabilityDescription { throw EnrichError.unavailable(reason) }
        let session = LanguageModelSession(instructions: WordPrompt.instructions)
        let response = try await session.respond(to: WordPrompt.make(for: term), generating: GeneratedInsight.self)
        return response.content.insight
    }
}

@Generable
struct GeneratedInsight {
    @Guide(description: "한국어 뜻풀이")
    var meaning: String
    @Guide(description: "품사")
    var partOfSpeech: String
    @Guide(description: "발음 표기")
    var pronunciation: String
    @Guide(description: "예문과 번역", .maximumCount(3))
    var examples: [GeneratedExample]
    @Guide(description: "유의어", .maximumCount(5))
    var synonyms: [String]
    @Guide(description: "사용 팁 한두 문장")
    var usageNote: String

    var insight: WordInsight {
        WordInsight(
            meaning: meaning, partOfSpeech: partOfSpeech, pronunciation: pronunciation,
            examples: examples.map { WordExample(sentence: $0.sentence, translation: $0.translation) },
            synonyms: synonyms, usageNote: usageNote)
    }
}

@Generable
struct GeneratedExample {
    @Guide(description: "예문")
    var sentence: String
    @Guide(description: "예문 번역")
    var translation: String
}
