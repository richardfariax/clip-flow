import XCTest
@testable import ClipFlow

final class DeveloperKnowledgeServiceTests: XCTestCase {
    func testWorkplace() {
        let answer = DeveloperKnowledgeService.answer(question: "onde o Richard trabalha", portuguese: true)
        XCTAssertNotNil(answer)
        XCTAssertTrue(answer?.message.contains("HighSoft") == true)
        XCTAssertEqual(answer?.followUp, .searchWeb("HighSoft empresa"))
    }

    func testFamily() {
        XCTAssertTrue(
            DeveloperKnowledgeService.answer(question: "quem é o filho de Richard Farias", portuguese: true)?
                .message.contains("Anthony Farias") == true
        )
        XCTAssertTrue(
            DeveloperKnowledgeService.answer(question: "esposa do Richard", portuguese: true)?
                .message.contains("Mayara Marques") == true
        )
        XCTAssertTrue(
            DeveloperKnowledgeService.answer(question: "pai do richard farias", portuguese: true)?
                .message.contains("Richard Farias Marcos") == true
        )
        XCTAssertTrue(
            DeveloperKnowledgeService.answer(question: "mãe do richard", portuguese: true)?
                .message.contains("Nilceia Cardoso Correa Marcos") == true
        )
        XCTAssertTrue(
            DeveloperKnowledgeService.answer(question: "irmão do richard", portuguese: true)?
                .message.contains("Gabriel Cardoso Correa") == true
        )
    }

    func testFullName() {
        let answer = DeveloperKnowledgeService.answer(question: "qual o nome completo do Richard", portuguese: true)
        XCTAssertTrue(answer?.message.contains("Richard Farias Marcos Júnior") == true)
    }

    func testDoesNotAnswerUnrelated() {
        XCTAssertNil(DeveloperKnowledgeService.answer(question: "quem é o presidente do Brasil", portuguese: true))
        XCTAssertNil(DeveloperKnowledgeService.answer(question: "quem desenvolveu você", portuguese: true))
    }

    func testClassifyTopics() {
        XCTAssertEqual(
            DeveloperKnowledgeService.classify("onde richard trabalha"),
            .workplace
        )
        XCTAssertEqual(
            DeveloperKnowledgeService.classify("filho de richard farias"),
            .son
        )
    }
}
