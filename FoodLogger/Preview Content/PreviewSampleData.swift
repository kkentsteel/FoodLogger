import SwiftData
import Foundation

@MainActor
let previewContainer: ModelContainer = {
    do {
        let schema = Schema([
            UserProfile.self,
            MealSlot.self,
            FoodItem.self,
            DailyLog.self,
            LogEntry.self,
            ChatMessage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Sample profile
        let profile = UserProfile(
            age: 30,
            weightKg: 80.0,
            heightCm: 180.0,
            biologicalSex: .male,
            activityLevel: .moderatelyActive,
            macroMode: .fullMacros,
            targetCalories: 2400,
            targetProteinGrams: 180,
            targetCarbsGrams: 270,
            targetFatGrams: 80
        )
        container.mainContext.insert(profile)

        // Sample meal slots
        let breakfast = MealSlot(name: "Breakfast", sortOrder: 0, iconName: "sunrise")
        breakfast.userProfile = profile
        container.mainContext.insert(breakfast)

        let lunch = MealSlot(name: "Lunch", sortOrder: 1, iconName: "sun.max")
        lunch.userProfile = profile
        container.mainContext.insert(lunch)

        let dinner = MealSlot(name: "Dinner", sortOrder: 2, iconName: "sunset")
        dinner.userProfile = profile
        container.mainContext.insert(dinner)

        let snack = MealSlot(name: "Snack", sortOrder: 3, iconName: "cup.and.saucer")
        snack.userProfile = profile
        container.mainContext.insert(snack)

        // Sample foods
        let yogurt = FoodItem(
            name: "Greek Yogurt",
            brand: "Tine",
            servingSize: 150,
            servingUnit: .grams,
            caloriesPerServing: 150,
            proteinPerServing: 15,
            carbsPerServing: 10,
            fatPerServing: 5,
            source: .manual
        )
        container.mainContext.insert(yogurt)

        let chicken = FoodItem(
            name: "Chicken Breast",
            servingSize: 150,
            servingUnit: .grams,
            caloriesPerServing: 250,
            proteinPerServing: 45,
            carbsPerServing: 0,
            fatPerServing: 6,
            source: .manual
        )
        container.mainContext.insert(chicken)

        let banana = FoodItem(
            name: "Banana",
            servingSize: 1,
            servingUnit: .pieces,
            servingLabel: "1 medium (120g)",
            caloriesPerServing: 105,
            proteinPerServing: 1.3,
            carbsPerServing: 27,
            fatPerServing: 0.4,
            source: .manual
        )
        container.mainContext.insert(banana)

        return container
    } catch {
        fatalError("Failed to create preview container: \(error)")
    }
}()
