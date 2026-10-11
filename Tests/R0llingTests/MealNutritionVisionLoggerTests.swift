import XCTest
@testable import R0lling

final class MealNutritionVisionLoggerTests: XCTestCase {
    private let logger = MealNutritionVisionLogger()

    func testSnapshotRetainsAnalysisTimeAndComputedMacroTotals() {
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = MealNutritionVisionLogger.NutritionSnapshot(
            timestamp: timestamp,
            mealType: .lunch,
            items: [
                MealNutritionVisionLogger.MealItem(
                    name: "Lunch",
                    estimatedGrams: 200,
                    calories: 330,
                    proteinGrams: 55,
                    carbsGrams: 12,
                    fatGrams: 7
                )
            ]
        )

        XCTAssertEqual(snapshot.timestamp, timestamp)
        XCTAssertEqual(snapshot.totalProtein, 55)
        XCTAssertEqual(snapshot.totalCarbs, 12)
        XCTAssertEqual(snapshot.totalFat, 7)
    }

    func testRecognizesGreekFoodTokensAndSumsEstimatedValues() throws {
        let estimate = try XCTUnwrap(logger.analyzeDetectedFoodTokens(
            tokens: ["ΣΑΛΆΤΑ", "κοτόπουλο", "ρύζι"],
            hourOfDay: 12
        ))

        XCTAssertEqual(estimate.mealType, .lunch)
        XCTAssertEqual(estimate.items.count, 3)
        XCTAssertEqual(estimate.totalCalories, 850, accuracy: 0.001)
        XCTAssertEqual(estimate.totalProtein, 66, accuracy: 0.001)
    }

    func testUnknownOrGenericMeatTermsDoNotProduceChickenEstimate() {
        XCTAssertNil(logger.analyzeDetectedFoodTokens(tokens: ["person", "table", "meal"]))
        XCTAssertNil(logger.analyzeDetectedFoodTokens(tokens: ["meat", "steak"]))
    }

    func testCoffeeClassificationFindsCoffeeAfterAnotherRecognizedItem() throws {
        let estimate = try XCTUnwrap(logger.analyzeDetectedFoodTokens(
            tokens: ["rice", "coffee"],
            hourOfDay: 17
        ))

        XCTAssertEqual(estimate.mealType, .coffee)
        XCTAssertEqual(estimate.items.count, 2)
    }

    func testMarkdownDisclosesHeuristicValuesAndIncludesNutritionTotals() throws {
        let estimate = try XCTUnwrap(logger.analyzeDetectedFoodTokens(tokens: ["chicken"], hourOfDay: 20))
        let markdown = logger.formatObsidianMarkdown(snapshot: estimate)

        XCTAssertTrue(markdown.contains("Ενδεικτική εκτίμηση γεύματος"))
        XCTAssertTrue(markdown.contains("δεν μετρήθηκαν"))
        XCTAssertTrue(markdown.contains("330 kcal"))
        XCTAssertTrue(markdown.contains("#meal #nutrition #health"))
    }
}
