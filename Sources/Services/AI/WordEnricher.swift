import Foundation

/// AI가 만든 단어 메타정보. 두 공급자 모두 이 모양으로 돌려줍니다.
struct WordInsight: Codable, Equatable {
    var meaning: String
    var partOfSpeech: String
    var pronunciation: String
    var examples: [WordExample]
    var synonyms: [String]
    var usageNote: String
}

protocol WordEnricher {
    func enrich(term: String) async throws -> WordInsight
}

enum EnrichError: LocalizedError {
    case unavailable(String)
    case badResponse(String)
    /// 온디바이스 모델 오류. 안전 필터에 걸린 경우 Gemini로 대신 정리할 수 있습니다.
    case onDevice(OnDeviceFailure)

    var isGuardrail: Bool {
        if case .onDevice(let failure) = self { return failure == .guardrail }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        case .badResponse(let detail): "AI 응답을 읽지 못했습니다. \(detail)"
        case .onDevice(let failure): failure.koreanDescription
        }
    }
}

enum WordPrompt {
    static let instructions = """
    당신은 한국어 사용자를 돕는 어휘 선생님입니다. 정확하고 간결하게 답하고, 모르는 내용은 지어내지 않습니다.
    """

    /// 완화 모드(문자열 응답)에서 쓰는 JSON 형식 안내
    static let jsonFormat = """
    아래 JSON 하나로만 답하세요. 다른 말은 쓰지 마세요.
    {"meaning": "", "partOfSpeech": "", "pronunciation": "", "examples": [{"sentence": "", "translation": ""}], "synonyms": [""], "usageNote": ""}
    """

    /// 응답 앞뒤의 설명·코드 블록을 걷어내고 JSON만 읽습니다.
    static func decodeJSON(_ text: String) throws -> WordInsight {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else {
            throw EnrichError.badResponse("JSON이 없습니다.")
        }
        return try JSONDecoder().decode(WordInsight.self, from: data)
    }

    static func isKorean(_ term: String) -> Bool {
        term.unicodeScalars.contains { (0xAC00...0xD7A3).contains($0.value) || (0x3131...0x318E).contains($0.value) }
    }

    static func make(for term: String) -> String {
        if isKorean(term) {
            return """
            한국어 단어(또는 표현) "\(term)"를 정리해 주세요.
            - meaning: 한국어 뜻풀이. 뜻이 여러 개면 "1. … 2. …"처럼 번호를 붙입니다. 한자어면 한자도 괄호로 적습니다.
            - partOfSpeech: 품사(예: 명사, 동사, 관용구)
            - pronunciation: 표준 발음 [ ] 표기
            - examples: 자연스러운 한국어 예문 2~3개와 영어 번역
            - synonyms: 비슷한 말 최대 5개
            - usageNote: 언제·어떻게 쓰는지 한두 문장
            """
        }
        return """
        영어 단어(또는 표현) "\(term)"를 한국어 사용자를 위해 정리해 주세요.
        - meaning: 한국어 뜻. 뜻이 여러 개면 "1. … 2. …"처럼 번호를 붙입니다.
        - partOfSpeech: 품사(예: noun, verb, phrasal verb)
        - pronunciation: IPA 발음 기호
        - examples: 자연스러운 영어 예문 2~3개와 한국어 번역
        - synonyms: 영어 유의어 최대 5개
        - usageNote: 뉘앙스, 자주 쓰는 표현, 헷갈리기 쉬운 점을 한국어로 한두 문장
        """
    }
}
