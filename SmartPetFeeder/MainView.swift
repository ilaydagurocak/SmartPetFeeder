import SwiftUI
import FirebaseAuth
import FirebaseDatabase  // Firebase Realtime Database entegrasyonu
import UserNotifications
import UIKit
import FirebaseMessaging
import UserNotifications


struct FeedData: Codable {
    let value: String
    let created_at: String
}

struct MainView: View {
    
    var petName: String
    var petEmoji: String

    
    private let petNode          = "pet"
    private let currentFeedName  = "currentFeed"
    private let currentWaterName = "currentWater"

    
    private let targetFeedName   = "targetFeed"
    private let targetWaterName  = "targetWater"

    
    @State private var targetFeed: Double  = 1000  // grams
    @State private var targetWater: Double = 500   // ml

    
    @State private var currentFeed: Double  = 0
    @State private var currentWater: Double = 0

    
    @State private var showFoodOptions: Bool      = false
    @State private var selectedFoodAmount: Int?   = nil
    @State private var showWaterOptions: Bool     = false
    @State private var selectedWaterAmount: Int?  = nil

    
    @State private var lastAllEmptyDate:    Date? = nil
    @State private var lastFeedEmptyDate:   Date? = nil
    @State private var lastWaterEmptyDate:  Date? = nil
    @State private var lastFeed50Date:      Date? = nil
    @State private var lastFeed100Date:     Date? = nil
    @State private var lastWater100Date:    Date? = nil
    @State private var lastWater200Date:    Date? = nil
    @State private var lastRatioDate:       Date? = nil
    @State private var lastSummaryDate:     Date? = nil
    
    @State private var fcmToken: String = ""

    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Smart Pet Feeder")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)

                Text("\(petEmoji) \(petName)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)

                
                infoCard(
                    title: "Pet Food",
                    systemImage: "pawprint.fill",
                    currentValue: currentFeed,
                    targetValue: targetFeed,
                    progressColor: .yellow
                )

                
                infoCard(
                    title: "Water",
                    systemImage: "drop.fill",
                    currentValue: currentWater,
                    targetValue: targetWater,
                    progressColor: .blue
                )

                // Ekleme Butonları
                HStack(spacing: 20) {
                    Button {
                        showFoodOptions = true
                    } label: {
                        Label("Add Food", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.yellow.opacity(0.8))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                    }
                    .confirmationDialog("Select Food Amount", isPresented: $showFoodOptions, titleVisibility: .visible) {
                        Button("50 gr")  { selectedFoodAmount = 50 }
                        Button("100 gr") { selectedFoodAmount = 100 }
                        Button("200 gr") { selectedFoodAmount = 200 }
                        Button("300 gr") { selectedFoodAmount = 300 }
                        Button("500 gr") { selectedFoodAmount = 500 }
                        Button("Cancel", role: .cancel) { }
                    }

                    Button {
                        showWaterOptions = true
                    } label: {
                        Label("Add Water", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.blue.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                    }
                    .confirmationDialog("Select Water Amount", isPresented: $showWaterOptions, titleVisibility: .visible) {
                        Button("100 ml") { selectedWaterAmount = 100 }
                        Button("200 ml") { selectedWaterAmount = 200 }
                        Button("300 ml") { selectedWaterAmount = 300 }
                        Button("400 ml") { selectedWaterAmount = 400 }
                        Button("500 ml") { selectedWaterAmount = 500 }
                        Button("Cancel", role: .cancel) { }
                    }
                }
                .padding(.top, 20)

                // Seçilen miktarı gönder
                if let foodAmount = selectedFoodAmount {
                    Button {
                        postTargetFeedCommand(amount: foodAmount)
                        selectedFoodAmount = nil
                    } label: {
                        Text("Send Food: \(foodAmount) gr")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal)
                }

                if let waterAmount = selectedWaterAmount {
                    Button {
                        postTargetWaterCommand(amount: waterAmount)
                        selectedWaterAmount = nil
                    } label: {
                        Text("Send Water: \(waterAmount) ml")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.cyan.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                Button {
                    logout()
                } label: {
                    Text("Log Out")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .shadow(radius: 4)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .padding(.horizontal)
        }
        .onAppear {
            requestNotificationPermission()
            fetchFCMToken()
            fetchAllData()

            Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                fetchAllData()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EmptyView() }
        }
    }

    
    @ViewBuilder
    private func infoCard(title: String,
                          systemImage: String,
                          currentValue: Double,
                          targetValue: Double,
                          progressColor: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(progressColor)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Text("\(Int(currentValue)) / \(Int(targetValue))")
                .font(.headline)
                .foregroundColor(.white)
            ProgressView(value: currentValue, total: targetValue)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .frame(width: 220)
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
        .shadow(radius: 5)
    }

    
    private func fetchAllData() {
        fetchFeedValue(feedName: currentFeedName) { value in
            DispatchQueue.main.async {
                self.currentFeed = value
                self.checkNotificationConditions()
            }
        }
        fetchFeedValue(feedName: currentWaterName) { value in
            DispatchQueue.main.async {
                self.currentWater = value
                self.checkNotificationConditions()
            }
        }
    }

    private func fetchFeedValue(feedName: String, completion: @escaping (Double) -> Void) {
        let ref = Database.database()
            .reference()
            .child(petNode)
            .child(feedName)
        ref.observeSingleEvent(of: .value) { snapshot in
            if let val = snapshot.value as? Double {
                completion(val)
            } else if let str = snapshot.value as? String, let dbl = Double(str) {
                completion(dbl)
            } else {
                completion(0)
            }
        }
    }

    
    private func postTargetFeedCommand(amount: Int) {
        Database.database().reference()
            .child(petNode)
            .child(targetFeedName)
            .setValue(amount) { err, _ in
                if let e = err {
                    print("Error posting targetFeed: \(e.localizedDescription)")
                } else {
                    print("Posted targetFeed: \(amount)")
                }
            }
    }

    private func postTargetWaterCommand(amount: Int) {
        Database.database().reference()
            .child(petNode)
            .child(targetWaterName)
            .setValue(amount) { err, _ in
                if let e = err {
                    print("Error posting targetWater: \(e.localizedDescription)")
                } else {
                    print("Posted targetWater: \(amount)")
                }
            }
    }

    //  - Bildirimler
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func sendLocal(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func fetchFCMToken() {
        Messaging.messaging().token { token, _ in
            if let t = token {
                fcmToken = t
                print("📲 FCM Token: \(t)")
            }
        }
    }

    private func sendPushNotification(title: String, body: String) {
        guard !fcmToken.isEmpty,
              let url = URL(string: "http://192.168.1.4:3000/send-notification") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": fcmToken,
            "title": title,
            "body": body
        ])
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Bildirim Koşulları
    private func checkNotificationConditions() {
        let now = Date()
        let feed = currentFeed
        let water = currentWater

        if feed == 0 && water == 0 {
            if lastAllEmptyDate == nil || now.timeIntervalSince(lastAllEmptyDate!) > 60 {
                sendLocal(title: "Alert", body: "Food and water are empty!")
                sendPushNotification(title: "Alert", body: "Food and water are empty!")
                lastAllEmptyDate = now
            }
        }
        if feed == 0 && water > 0 {
            if lastFeedEmptyDate == nil || now.timeIntervalSince(lastFeedEmptyDate!) > 60 {
                sendLocal(title: "Food Alert", body: "Pet food is empty!")
                sendPushNotification(title: "Food Alert", body: "Pet food is empty!")
                lastFeedEmptyDate = now
            }
        }
        if water == 0 && feed > 0 {
            if lastWaterEmptyDate == nil || now.timeIntervalSince(lastWaterEmptyDate!) > 60 {
                sendLocal(title: "Water Alert", body: "Water container is empty!")
                sendPushNotification(title: "Water Alert", body: "Water container is empty!")
                lastWaterEmptyDate = now
            }
        }
        if feed <= 50 && feed > 0 {
            if lastFeed50Date == nil || now.timeIntervalSince(lastFeed50Date!) > 60 {
                sendLocal(title: "Low Food", body: "Only \(Int(feed))g food left!")
                sendPushNotification(title: "Low Food", body: "Only \(Int(feed))g food left!")
                lastFeed50Date = now
            }
        }
        if feed <= 100 && feed > 50 {
            if lastFeed100Date == nil || now.timeIntervalSince(lastFeed100Date!) > 60 {
                sendLocal(title: "Food Running Low", body: "\(Int(feed))g food remaining.")
                sendPushNotification(title: "Food Running Low", body: "\(Int(feed))g food remaining.")
                lastFeed100Date = now
            }
        }
        if water <= 100 && water > 0 {
            if lastWater100Date == nil || now.timeIntervalSince(lastWater100Date!) > 60 {
                sendLocal(title: "Low Water", body: "Only \(Int(water))ml water left!")
                sendPushNotification(title: "Low Water", body: "Only \(Int(water))ml water left!")
                lastWater100Date = now
            }
        }
        if water <= 200 && water > 100 {
            if lastWater200Date == nil || now.timeIntervalSince(lastWater200Date!) > 60 {
                sendLocal(title: "Water Running Low", body: "\(Int(water))ml water remaining.")
                sendPushNotification(title: "Water Running Low", body: "\(Int(water))ml water remaining.")
                lastWater200Date = now
            }
        }
        if water > 0 {
            let ratio = feed / water
            if ratio < 1.5 || ratio > 2.5 {
                if lastRatioDate == nil || now.timeIntervalSince(lastRatioDate!) > 60 {
                    sendLocal(title: "Imbalance Warning", body: "Food/water ratio is off: \(String(format: "%.2f", ratio))")
                    sendPushNotification(title: "Imbalance Warning", body: "Food/water ratio is off: \(String(format: "%.2f", ratio))")
                    lastRatioDate = now
                }
            }
        }
        if lastSummaryDate == nil || now.timeIntervalSince(lastSummaryDate!) > 300 {
            sendLocal(
                title: "Current Status",
                body: "Food: \(Int(feed))g / \(Int(targetFeed))g, Water: \(Int(water))ml / \(Int(targetWater))ml"
            )
            sendPushNotification(
                title: "Current Status",
                body: "Food: \(Int(feed))g / \(Int(targetFeed))g, Water: \(Int(water))ml / \(Int(targetWater))ml"
            )
            lastSummaryDate = now
        }
    }

   
    private func logout() {
        do {
            try Auth.auth().signOut()
            if let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let w = ws.windows.first {
                w.rootViewController = UIHostingController(rootView: ContentView())
                w.makeKeyAndVisible()
            }
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
}

