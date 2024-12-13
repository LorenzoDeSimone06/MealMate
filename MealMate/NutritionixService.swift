//
//  NutritionixService.swift
//  MealMate
//
//  Created by Lorenzo De Simone on 12/12/24.
//

import Foundation
import Alamofire

class NutritionixService {
    private let baseURL = "https://trackapi.nutritionix.com/v2"
    private let appID = "73521cae"
    private let appKey = "e5609bfa9c5a5ee00c67a35a4353fe32"
    
    // Fetch nutrition data for a barcode
    func fetchNutritionData(for barcode: String, completion: @escaping (Result<NutritionItem, Error>) -> Void) {
        let headers: HTTPHeaders = [
            "x-app-id": appID,
            "x-app-key": appKey
        ]
        let url = "\(baseURL)/search/item?upc=\(barcode)"
        
        // Use Alamofire to make the API request
        AF.request(url, headers: headers).responseDecodable(of: NutritionixResponse.self) { response in
            switch response.result {
            case .success(let data):
                if let item = data.foods.first {
                    completion(.success(item))
                } else {
                    completion(.failure(NutritionError.noData))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// Error enum for better error handling
enum NutritionError: Error {
    case noData
}

// Response and data models
struct NutritionixResponse: Decodable {
    let foods: [NutritionItem]
}

struct NutritionItem: Decodable {
    let food_name: String
    let brand_name: String
    let nf_calories: Double
    let nf_total_fat: Double
    let nf_protein: Double
    let nf_sugars: Double
}

