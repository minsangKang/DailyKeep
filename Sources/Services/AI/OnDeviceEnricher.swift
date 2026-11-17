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
        do {
            let session = LanguageModelSession(instructions: WordPrompt.instructions)
            let response = try await session.respond(to: WordPrompt.make(for: term), generating: GeneratedInsight.self)
            return response.content.insight
        } catch {
            // 시사·정치 용어(예: 대북제재)는 기본 안전 필터에 걸리기 쉽습니다.
            // 단어 설명은 사전 성격이라 완화 모드로 한 번 더 시도합니다(완화 모드는 문자열 응답에만 적용).
            let failure = OnDeviceFailure(error)
            guard failure == .guardrail else { throw EnrichError.onDevice(failure) }
            do {
                return try await enrichPermissively(term: term)
            } catch let error as EnrichError {
                throw error
            } catch {
                throw EnrichError.onDevice(OnDeviceFailure(error))
            }
        }
    }

    private func enrichPermissively(term: String) async throws -> WordInsight {
        let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)
        let session = LanguageModelSession(model: model, instructions: WordPrompt.instructions)
        let prompt = WordPrompt.make(for: term) + "\n\n" + WordPrompt.jsonFormat
        let text = try await session.respond(to: prompt).content
        return try WordPrompt.decodeJSON(text)
    }
}

/// 온디바이스 모델 실패를 화면에 보여줄 종류로 나눕니다.
nonisolated enum OnDeviceFailure: Equatable, Sendable {
    case guardrail, unsupportedLanguage, busy, tooLong, other

    init(_ error: any Error) {
        if let error = error as? LanguageModelError {
            switch error {
            case .guardrailViolation, .refusal: self = .guardrail
            case .unsupportedLanguageOrLocale: self = .unsupportedLanguage
            case .rateLimited, .timeout: self = .busy
            case .contextSizeExceeded: self = .tooLong
            default: self = .other
            }
            return
        }
        // 27.0에서 deprecated된 이전 오류 타입(GenerationError)으로 올 때를 대비해 케이스 이름으로 판별합니다.
        let name = String(describing: error)
        if name.contains("guardrailViolation") || name.contains("refusal") { self = .guardrail }
        else if name.contains("unsupportedLanguageOrLocale") { self = .unsupportedLanguage }
        else if name.contains("rateLimited") || name.contains("concurrentRequests") { self = .busy }
        else if name.contains("exceededContextWindowSize") { self = .tooLong }
        else { self = .other }
    }

    var koreanDescription: String {
        switch self {
        case .guardrail: "Apple 온디바이스 모델이 민감한 주제로 판단해 답하지 않았어요."
        case .unsupportedLanguage: "온디바이스 모델이 이 언어를 지원하지 않아요."
        case .busy: "요청이 몰려 있어요. 잠시 후 다시 시도해 주세요."
        case .tooLong: "입력이 너무 길어요."
        case .other: "온디바이스 모델이 답을 만들지 못했어요."
        }
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
