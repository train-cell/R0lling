import Foundation

/// Οπτικός Καταγραφέας Γευμάτων και Διατροφής (Meal & Nutrition Visual Logger)
/// Εντοπίζει πιάτα φαγητού, ροφήματα και σκεύη από την κάμερα των γυαλιών.
/// Εκτιμά μακροθρεπτικά συστατικά (θερμίδες, πρωτεΐνη, υδατάνθρακες, λιπαρά)
/// και ετοιμάζει payload για συγχρονισμό με το Apple HealthKit και το Obsidian.
public final class MealNutritionVisionLogger: @unchecked Sendable {
    
    public struct MealItem: Identifiable, Sendable, Codable {
        public let id: UUID
        public let name: String
        public let estimatedGrams: Double
        public let calories: Double
        public let proteinGrams: Double
        public let carbsGrams: Double
        public let fatGrams: Double
        
        public init(
            id: UUID = UUID(),
            name: String,
            estimatedGrams: Double,
            calories: Double,
            proteinGrams: Double,
            carbsGrams: Double,
            fatGrams: Double
        ) {
            self.id = id
            self.name = name
            self.estimatedGrams = estimatedGrams
            self.calories = calories
            self.proteinGrams = proteinGrams
            self.carbsGrams = carbsGrams
            self.fatGrams = fatGrams
        }
    }
    
    public struct NutritionSnapshot: Identifiable, Sendable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let mealType: MealType
        public let items: [MealItem]
        public let totalCalories: Double
        public let totalProtein: Double
        public let totalCarbs: Double
        public let totalFat: Double
        
        public enum MealType: String, Sendable, Codable {
            case breakfast = "Πρωινό"
            case lunch = "Μεσημεριανό"
            case dinner = "Βραδινό"
            case snack = "Σνακ"
            case coffee = "Καφές/Ρόφημα"
        }
        
        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            mealType: MealType,
            items: [MealItem]
        ) {
            self.id = id
            self.timestamp = timestamp
            self.mealType = mealType
            self.items = items
            self.totalCalories = items.reduce(0.0) { $0 + $1.calories }
            self.totalProtein = items.reduce(0.0) { $0 + $1.proteinGrams }
            self.totalCarbs = items.reduce(0.0) { $0 + $1.carbsGrams }
            self.totalFat = items.reduce(0.0) { $0 + $1.fatGrams }
        }
    }
    
    public init() {}
    
    /// Ανάλυση ανιχνευμένων ετικετών όρασης για δημιουργία εκτίμησης γεύματος
    public func analyzeDetectedFoodTokens(tokens: [String], hourOfDay: Int = Calendar.current.component(.hour, from: Date())) -> NutritionSnapshot? {
        var items: [MealItem] = []
        let lower = tokens.map { $0.lowercased() }
        
        // Ευρετική αναγνώριση γνωστών κατηγοριών τροφίμων
        if lower.contains(where: { $0.contains("salad") || $0.contains("σαλάτα") || $0.contains("tomato") }) {
            items.append(MealItem(name: "Χωριάτικη Σαλάτα", estimatedGrams: 250, calories: 280, proteinGrams: 6, carbsGrams: 12, fatGrams: 22))
        }
        if lower.contains(where: { $0.contains("chicken") || $0.contains("κοτόπουλο") || $0.contains("meat") || $0.contains("steak") }) {
            items.append(MealItem(name: "Φιλέτο Κοτόπουλο", estimatedGrams: 200, calories: 330, proteinGrams: 55, carbsGrams: 0, fatGrams: 7))
        }
        if lower.contains(where: { $0.contains("rice") || $0.contains("ρύζι") || $0.contains("pasta") || $0.contains("μακαρόνια") }) {
            items.append(MealItem(name: "Ρύζι / Υδατάνθρακες", estimatedGrams: 180, calories: 240, proteinGrams: 5, carbsGrams: 52, fatGrams: 2))
        }
        if lower.contains(where: { $0.contains("coffee") || $0.contains("καφές") || $0.contains("espresso") || $0.contains("cappuccino") }) {
            items.append(MealItem(name: "Freddo Espresso", estimatedGrams: 200, calories: 5, proteinGrams: 0.2, carbsGrams: 0.8, fatGrams: 0.1))
        }
        
        guard !items.isEmpty else { return nil }
        
        let mealType: NutritionSnapshot.MealType
        switch hourOfDay {
        case 6..<11: mealType = .breakfast
        case 12..<17: mealType = .lunch
        case 19..<23: mealType = .dinner
        default: mealType = items.first?.name.contains("Espresso") == true ? .coffee : .snack
        }
        
        return NutritionSnapshot(mealType: mealType, items: items)
    }
    
    /// Μορφοποίηση σε Markdown Frontmatter / Dataview block για το Obsidian
    public func formatObsidianMarkdown(snapshot: NutritionSnapshot) -> String {
        var md = "### 🥗 Καταγραφή Γεύματος (\(snapshot.mealType.rawValue))\n"
        md += "- **Θερμίδες:** \(Int(snapshot.totalCalories)) kcal\n"
        md += "- **Πρωτεΐνη:** \(String(format: "%.1f", snapshot.totalProtein))g | "
        md += "**Υδατάνθρακες:** \(String(format: "%.1f", snapshot.totalCarbs))g | "
        md += "**Λιπαρά:** \(String(format: "%.1f", snapshot.totalFat))g\n\n"
        md += "**Περιεχόμενα:**\n"
        for item in snapshot.items {
            md += "- \(item.name) (\(Int(item.estimatedGrams))g) — \(Int(item.calories)) kcal\n"
        }
        md += "\n#meal #nutrition #health\n"
        return md
    }
}
