//
//  MartFoodData.swift
//  refriger-management-project
//
//  Created by 조종운 on 2020/08/22.
//  Copyright © 2020 조종운. All rights reserved.
//

import Foundation
import SwiftUI
import FirebaseFirestore


let martfoodData: [MartFood] = load("RefrigerData.json")

let firebase_db = Firestore.firestore()

func load<T: Decodable>(_ filename: String) -> T {
    let data: Data
    
    guard let file = Bundle.main.url(forResource: filename, withExtension: nil) else {
        fatalError("\(filename)을 찾을 수 없어요.")
    }
    
    do {
        data = try Data(contentsOf: file)
    } catch {
        fatalError("\(filename)을 불러올 수 없어요.")
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    } catch {
        fatalError("\(filename)을 \(T.self)로 파싱할 수 없어요.")
    }
}

struct MartFood: Hashable, Codable, Identifiable {
    var id : Int
    var name : String
    var category : String
    var foodType : String
    var price : String
}

struct CartFoodType: Hashable {
    var foodName: String
    var foodCategory: String
    var foodCount: Int
    var foodPrice: String
}

struct User: Hashable {
    var userName: String
    var hp: String
    var address: String
}

class CartHelper: ObservableObject {
    
    /* 카트에 식료품 추가하기 */
    func addCart(_ email: String, _ martfood: CartFoodType, completion: @escaping (Bool) -> Void) {
        firebase_db
            .collection("User").document(email)
            .collection("Cart").document(martfood.foodName).setData([
                "foodName": martfood.foodName,
                "foodCategory": martfood.foodCategory,
                "foodCount": martfood.foodCount,
                "foodPrice": martfood.foodPrice
            ])
        
        completion(true)
    }
    
    /* 변경된 카트내용 db에 반영 */
    func editCartDB(_ email: String, _ foodName: String) {
        /* db 내용을 모두 지우고 새로 쓴다. */
        firebase_db
            .collection("User").document(email)
            .collection("Cart").document(foodName).delete()
    }
    
    /* 사용자 계정이 Purchase에 있는지 확인 */
    func checkUserInPurchase(_ email: String , completion: @escaping (Bool) -> Void) {
        
        /* true - 있음, false - 없음 */
        /* DB가 비어있거나 자신의 주문이 없을 경우 false */
        var purchase_check = false
        
        firebase_db
            .collection("Purchase").getDocuments { snapShot, error in
                if snapShot!.count != 0 {
                    for document in snapShot!.documents {
                        if document.documentID == email {
                            purchase_check = true
                        }
                    }
                }
                
                completion(purchase_check)
        }
    }
    
    /* 주문 횟수 구하기 */
    func getOrderCount(_ email: String, completion: @escaping (Int, Array<String>) -> Void) {
        var orderCount: Int?
        var orderArr: Array<String>?
        
        firebase_db
            .collection("Purchase").document(email).getDocument { document, error in
                if let document = document, document.exists {
                    orderCount = document.data()!["orderCount"] as? Int
                    orderArr = document.data()!["orderArr"] as? Array<String>
                }
                
                completion(orderCount! + 1, orderArr!)
        }
    }
    
    /* Purchase DB 주문넣기 */
    func insertOrderInPurchase(_ userInfo: User, _ email: String, _ totalPrice: String, _ cartlist: [CartFoodType], _ orderCount: Int = 0, _ orderArr: Array<String> = []) {
        var foodNames: [String] = []
        var foodCategory: [String] = []
        var foodCounts: [Int] = []

        for food in cartlist {
            foodNames.append(food.foodName)
            foodCategory.append(food.foodCategory)
            foodCounts.append(food.foodCount)
        }
        
        var _orderArr: Array<String> = orderArr
        _orderArr.append(String(orderCount) + "-" + email)
        
        
        firebase_db
            .collection("Purchase").document(email)
            .collection(String(orderCount)).document("Food").setData([
                "foodNames": foodNames,
                "foodCategory": foodCategory,
                "foodCounts": foodCounts
            ])

        firebase_db
            .collection("Purchase").document(email)
            .collection(String(orderCount)).document("orderInfo").setData([
                "totalPrice": totalPrice,
                "hp": userInfo.hp,
                "address": userInfo.address,
                "name": userInfo.userName
            ])

        firebase_db
            .collection("Purchase").document(email).setData([
                "orderCount": orderCount,
                "orderArr": _orderArr
            ])
        
        firebase_db
            .collection("User").document(email)
            .collection("Cart").getDocuments { snapShot, error in
                for document in snapShot!.documents {
                    document.reference.delete()
                }
        }
    }
    
    /* 카트에 있는 식자재 구매 */
    func purchase(_ email: String, _ totalPrice: String, _ userInfo: User, _ cartlist: [CartFoodType], completion: @escaping (Bool) -> Void) {
        
        /* Purchase에 사용자 이메일이 있는지 확인 */
        checkUserInPurchase(email) { purchase_check in
            if purchase_check {
                /* 이메일에서 주문횟수를 가져온다. */
                self.getOrderCount(email) { orderCount, orderArr in
                    /* 주문을 넣는다. */
                    self.insertOrderInPurchase(userInfo, email, totalPrice, cartlist, orderCount, orderArr)
                    
                }
            } else {
                self.insertOrderInPurchase(userInfo, email, totalPrice, cartlist)
            }
        }
        
        completion(true)
    }
    
    /* 식자재 불러오기 */
    func loadCart(_ email: String, completion: @escaping (Bool, [CartFoodType]) -> Void) {
        
        var cartlist: [CartFoodType] = []
        
        firebase_db
            .collection("User").document(email)
            .collection("Cart").getDocuments { (snapShot, error) in
                if let error = error {
                    print(error)
                } else {
                    for document in snapShot!.documents {
                        cartlist.append(CartFoodType(
                            foodName: document.data()["foodName"] as! String,
                            foodCategory: document.data()["foodCategory"] as! String,
                            foodCount: document.data()["foodCount"] as! Int,
                            foodPrice: document.data()["foodPrice"] as! String )
                        )
                    }
                    
                    completion(true, cartlist)
                }
        }
    }
    
    /* db에서 사용자 정보(이름, hp, 주소) 가져오기 */
    func getUserInfo(_ email: String, completion: @escaping (Bool, User) -> Void) {
        
        var user = User(userName: "", hp: "", address: "")
        
        firebase_db
            .collection("User").document(email).getDocument { document, error in
                if let document = document {
                    user.userName = document.data()!["userName"] as! String
                    user.hp = document.data()!["hp"] as! String
                    user.address = document.data()!["address"] as! String
                }
            
            completion(true, user)
        }
    }
    
    /* 가격에서 쉼표를 빼주는 함수 */
    func sub_comma(_ foodPrice: String) -> String {
        var _foodPrice = foodPrice
        if let index = _foodPrice.firstIndex(of: ",") {
            _foodPrice.remove(at: index)
        }
        
        return _foodPrice
    }
    
    /* 가격에 쉼표를 붙여주는 함수 */
    func add_comma(_ foodPrice: String) -> String {
        var _foodPrice = foodPrice
        
        if _foodPrice.count == 4 {
            _foodPrice.insert(",", at: _foodPrice.index(_foodPrice.startIndex, offsetBy: 1))
        } else if _foodPrice.count == 5 {
            _foodPrice.insert(",", at: _foodPrice.index(_foodPrice.startIndex, offsetBy: 2))
        } else if _foodPrice.count == 6 {
            _foodPrice.insert(",", at: _foodPrice.index(_foodPrice.startIndex, offsetBy: 3))
        }
        
        return _foodPrice
    }
}


