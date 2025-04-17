
import SwiftUI
import FirebaseAuth
import FirebaseDatabase  // Firebase Realtime Database entegrasyonu
import UserNotifications
import UIKit
import FirebaseMessaging
import UserNotifications


// Model: Örnek veri yapısı (Adafruit IO modeline benzer)
struct FeedData: Codable {
    let value: String
    let created_at: String
}

struct MainView: View {
    // Pet bilgileri
    var petName: String
    var petEmoji: String

    // Firebase düğüm isimleri
    private let currentFeedName  = "current_feed"
    private let currentWaterName = "current_water"
    private let controlFeedName  = "control_feed"

    // Hedef değerler
    @State private var targetFeed: Double  = 1000  // grams
    @State private var targetWater: Double = 500   // ml

    // Güncel değerler
    @State private var currentFeed: Double  = 0
    @State private var currentWater: Double = 0

    // Yemek ve su ekleme seçenekleri
    @State private var showFoodOptions: Bool = false
    @State private var selectedFoodAmount: Int? = nil
    @State private var showWaterOptions: Bool = false
    @State private var selectedWaterAmount: Int? = nil

    // Bildirim tekrarını engellemek için son bildirim zamanları
    @State private var lastEmptyNotificationDate: Date? = nil
    @State private var lastRatioNotificationDate: Date? = nil
    
    @State private var fcmToken: String = ""

    @State private var lastAllEmptyDate:   Date? = nil
    @State private var lastFeedEmptyDate:  Date? = nil
    @State private var lastWaterEmptyDate: Date? = nil
    @State private var lastFeed50Date:     Date? = nil
    @State private var lastFeed100Date:    Date? = nil
    @State private var lastWater100Date:   Date? = nil
    @State private var lastWater200Date:   Date? = nil
    @State private var lastRatioDate:      Date? = nil
    @State private var lastSummaryDate:    Date? = nil


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

                // Evcil hayvan bilgileri
                Text("\(petEmoji) \(petName)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 40)

                // Yemek Kartı
                infoCard(
                    title: "Pet Food",
                    systemImage: "pawprint.fill",
                    currentValue: currentFeed,
                    targetValue: targetFeed,
                    progressColor: .yellow
                )

                // Su Kartı
                infoCard(
                    title: "Water",
                    systemImage: "drop.fill",
                    currentValue: currentWater,
                    targetValue: targetWater,
                    progressColor: .blue
                )

                // Yemek ve su ekleme butonları
                HStack(spacing: 20) {
                    // Yemek Ekle Butonu
                    Button(action: {
                        showFoodOptions = true
                    }) {
                        Label("Add Food", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(Color.yellow.opacity(0.8))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                    }
                    .confirmationDialog("Select Food Amount", isPresented: $showFoodOptions, titleVisibility: .visible) {
                        Button("50 gr") { selectedFoodAmount = 50 }
                        Button("100 gr") { selectedFoodAmount = 100 }
                        Button("200 gr") { selectedFoodAmount = 200 }
                        Button("300 gr") { selectedFoodAmount = 300 }
                        Button("500 gr") { selectedFoodAmount = 500 }
                        Button("Cancel", role: .cancel) { }
                    }

                    // Su Ekle Butonu
                    Button(action: {
                        showWaterOptions = true
                    }) {
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

                // Seçilen miktar için gönderme butonları
                if let foodAmount = selectedFoodAmount {
                    Button(action: {
                        postControlCommand("ADD_FEED:\(foodAmount)")
                        selectedFoodAmount = nil
                    }) {
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
                    Button(action: {
                        postControlCommand("ADD_WATER:\(waterAmount)")
                        selectedWaterAmount = nil
                    }) {
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

                // Çıkış (Log Out) butonu
                Button(action: {
                    logout()
                }) {
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
            // Bildirim izni iste
            requestNotificationPermission()
            fetchFCMToken()
            

            print("🟢 onAppear çalıştı")
            // Ekran açılışında verileri çek ve test amaçlı bildirim gönder
            fetchAllData()
            
            // Veriler her 10 saniyede bir güncelleniyor
            Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                fetchAllData()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EmptyView()
            }
        }
    }
    
    // MARK: - Kart Görünümü
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
    
    // MARK: - Veri Çekme ve Kontrol
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
        let ref = Database.database().reference().child(feedName)
        ref.observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? Double {
                completion(value)
            } else if let valueStr = snapshot.value as? String,
                      let doubleValue = Double(valueStr) {
                completion(doubleValue)
            } else {
                completion(0)
            }
        }
    }
    
    // Bildirim izni al
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    // Local bildirim gönder
    private func sendLocal(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // FCM token al
    private func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            if let token = token {
                fcmToken = token
                print("📲 FCM Token: \(token)")
            }
        }
    }

    // Push gönder
    private func sendPushNotification(title: String, body: String) {
        guard !fcmToken.isEmpty,
              let url = URL(string: "http://192.168.1.4:3000/send-notification") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = [
            "token": fcmToken,
            "title": title,
            "body": body
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request).resume()
    }

    
    // MARK: - Firebase'ye Kontrol Komutu Gönderme
    private func postControlCommand(_ command: String) {
        let ref = Database.database().reference().child(controlFeedName)
        ref.setValue(command) { error, _ in
            if let error = error {
                print("Error posting control command: \(error.localizedDescription)")
            } else {
                print("Control command posted successfully")
            }
        }
    }
    
    private func checkNotificationConditions() {
        print("🔍 Bildirim fonksiyonu çalışıyor. Feed: \(currentFeed), Water: \(currentWater)")
        let now = Date()

        // Tüm değerleri formatla
        let feed = currentFeed
        let water = currentWater

        // 1) Her ikisi 0
        if feed == 0 && water == 0 {
            if lastAllEmptyDate == nil || now.timeIntervalSince(lastAllEmptyDate!) > 60 {
                let title = "Alert"
                let body  = "Food and water are empty!"
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastAllEmptyDate = now
            }
        }

        // 2) Sadece mama 0
        if feed == 0 && (water > 0) {
            if lastFeedEmptyDate == nil || now.timeIntervalSince(lastFeedEmptyDate!) > 60 {
                let title = "Food Alert"
                let body  = "Pet food is empty!"
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastFeedEmptyDate = now
            }
        }

        // 3) Sadece su 0
        if water == 0 && (feed > 0) {
            if lastWaterEmptyDate == nil || now.timeIntervalSince(lastWaterEmptyDate!) > 60 {
                let title = "Water Alert"
                let body  = "Water container is empty!"
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastWaterEmptyDate = now
            }
        }

        // 4) Mama ≤ 50 gr
        if feed <= 50 && feed > 0 {
            if lastFeed50Date == nil || now.timeIntervalSince(lastFeed50Date!) > 60 {
                let title = "Low Food"
                let body  = "Only \(Int(feed))g food left!"
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastFeed50Date = now
            }
        }

        // 5) Mama ≤ 100 gr
        if feed <= 100 && feed > 50 {
            if lastFeed100Date == nil || now.timeIntervalSince(lastFeed100Date!) > 60 {
                let title = "Food Running Low"
                let body  = "\(Int(feed))g food remaining."
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastFeed100Date = now
            }
        }

        // 6) Su ≤ 100 ml
        if water <= 100 && water > 0 {
            if lastWater100Date == nil || now.timeIntervalSince(lastWater100Date!) > 60 {
                let title = "Low Water"
                let body  = "Only \(Int(water))ml water left!"
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastWater100Date = now
            }
        }

        // 7) Su ≤ 200 ml
        if water <= 200 && water > 100 {
            if lastWater200Date == nil || now.timeIntervalSince(lastWater200Date!) > 60 {
                let title = "Water Running Low"
                let body  = "\(Int(water))ml water remaining."
                sendLocal(title: title, body: body)
                sendPushNotification(title: title, body: body)
                lastWater200Date = now
            }
        }

        // 8) Mama/Su oranı dengesiz (normal: 1.5 - 2.5)
        if water > 0 {
            let ratio = feed / water
            if ratio < 1.5 || ratio > 2.5 {
                if lastRatioDate == nil || now.timeIntervalSince(lastRatioDate!) > 60 {
                    let title = "Imbalance Warning"
                    let body  = "Food/water ratio is off: \(String(format: "%.2f", ratio))"
                    sendLocal(title: title, body: body)
                    sendPushNotification(title: title, body: body)
                    lastRatioDate = now
                }
            }
        }

        // 9) Özet bildirimi (her 5 dakikada bir sadece bilgi amaçlı)
        if lastSummaryDate == nil || now.timeIntervalSince(lastSummaryDate!) > 300 {
            let title = "Current Status"
            let body  = "Food: \(Int(feed))g / \(Int(targetFeed))g, Water: \(Int(water))ml / \(Int(targetWater))ml"
            sendLocal(title: title, body: body)
            sendPushNotification(title: title, body: body)
            lastSummaryDate = now
        }
    }

    
    private func scheduleNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification scheduling error: \(error.localizedDescription)")
            } else {
                print("Notification scheduled: \(title) - \(body)")
            }
        }
    }
    
    // MARK: - Çıkış İşlemi
    private func logout() {
        do {
            try Auth.auth().signOut()
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = UIHostingController(rootView: ContentView())
                window.makeKeyAndVisible()
            }
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
    }
}

