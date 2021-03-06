//
//  ContentView.swift
//  refriger-management-project
//
//  Created by 조종운 on 2020/08/22.
//  Copyright © 2020 조종운. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var tabViewHelper: TabViewHelper
    
    @EnvironmentObject var userHelper : UserHelper
    
    @State var notificationDenied = false
    
    var body: some View {
        ZStack {
            Group {
                if tabViewHelper.view == "식료품관리-선택" {
                    FoodManagementMain()
                        
                } else {
                    MartHome()
                }
            }
            
            if tabViewHelper.isOn {
                VStack {
                    Spacer()
                    TabView()
                }.edgesIgnoringSafeArea(.bottom)
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
                if let error = error {
                    print(error)
                    notificationDenied = true
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
