import Testing
import Foundation
@testable import FoodLogger

@Suite("OpenFoodFactsService Tests")
struct OpenFoodFactsServiceTests {

    @Test("OFFResponse decodes found product")
    func decodeFoundProduct() throws {
        let json = """
        {
            "status": 1,
            "product": {
                "product_name": "Chocolate Bar",
                "brands": "TestBrand",
                "code": "1234567890123",
                "serving_size": "40g",
                "nutriments": {
                    "energy-kcal_100g": 534,
                    "proteins_100g": 7.5,
                    "carbohydrates_100g": 57.2,
                    "fat_100g": 30.1,
                    "fiber_100g": 3.4
                }
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OFFResponse.self, from: json)

        #expect(response.status == 1)
        #expect(response.product != nil)
        #expect(response.product?.productName == "Chocolate Bar")
        #expect(response.product?.brands == "TestBrand")
        #expect(response.product?.code == "1234567890123")
        #expect(response.product?.servingSize == "40g")
        #expect(response.product?.nutriments?.energyKcal100g == 534)
        #expect(response.product?.nutriments?.proteins100g == 7.5)
        #expect(response.product?.nutriments?.carbohydrates100g == 57.2)
        #expect(response.product?.nutriments?.fat100g == 30.1)
        #expect(response.product?.nutriments?.fiber100g == 3.4)
    }

    @Test("OFFResponse decodes not-found product")
    func decodeNotFound() throws {
        let json = """
        {
            "status": 0,
            "product": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OFFResponse.self, from: json)
        #expect(response.status == 0)
        #expect(response.product == nil)
    }

    @Test("OFFProduct asFoodData conversion")
    func asFoodDataConversion() {
        let nutriments = OFFNutriments(
            energyKcal100g: 250,
            proteins100g: 12.5,
            carbohydrates100g: 30,
            fat100g: 8.5,
            fiber100g: 2.1
        )
        let product = OFFProduct(
            productName: "Test Food",
            brands: "TestBrand",
            code: "1234567890123",
            servingSize: "50g",
            nutriments: nutriments
        )

        let data = product.asFoodData

        #expect(data.name == "Test Food")
        #expect(data.brand == "TestBrand")
        #expect(data.barcode == "1234567890123")
        #expect(data.calories == 250)
        #expect(data.protein == 12.5)
        #expect(data.carbs == 30)
        #expect(data.fat == 8.5)
        #expect(data.fiber == 2.1)
    }

    @Test("OFFProduct with nil name defaults to Unknown")
    func nilNameDefaults() {
        let product = OFFProduct(
            productName: nil,
            brands: nil,
            code: nil,
            servingSize: nil,
            nutriments: nil
        )

        let data = product.asFoodData
        #expect(data.name == "Unknown Product")
        #expect(data.calories == 0)
        #expect(data.protein == 0)
    }

    @Test("OFFResponse handles missing nutriments gracefully")
    func missingNutriments() throws {
        let json = """
        {
            "status": 1,
            "product": {
                "product_name": "Minimal Product",
                "brands": null,
                "code": "999",
                "serving_size": null,
                "nutriments": {}
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(OFFResponse.self, from: json)
        #expect(response.product?.nutriments?.energyKcal100g == nil)
        #expect(response.product?.nutriments?.proteins100g == nil)

        let data = response.product!.asFoodData
        #expect(data.calories == 0)
        #expect(data.protein == 0)
    }
}
