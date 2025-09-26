import SwiftUI
import FirebaseMessaging

struct ContentView: View {
    @State private var fcmToken: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                
                LinearGradient(gradient: Gradient(colors: [.blue, .purple]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Text("Welcome to Smart Pet Feeder🐱🐶")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.top, 150)
                    
                    Spacer()
                    
                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Login")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pink.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                    }
                    
                    
                    NavigationLink {
                        RegisterView()
                    } label: {
                        Text("Register")
                            .font(.title2)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pink.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(30)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                fetchFCMToken()
            }
        }
    }
    
    
    private func fetchFCMToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("⚠️ Token alınamadı:", error)
                return
            }
            guard let token = token else {
                print("⚠️ Token nil dönüyor")
                return
            }
            fcmToken = token
            print("FCM Token:", token)
        }
    }
    
    // Push Bildirim
    private func sendPush(to token: String, title: String, body: String) {
        guard let url = URL(string: "http://192.168.1.4:3000/send-notification") else {
            print("⚠️ URL hatalı")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "token": token,
            "title": title,
            "body":  body
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            print("⚠️ JSON oluşturulamadı:", error)
            return
        }
        
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error {
                print("⚠️ İstek hatası:", error)
                return
            }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                print("⚠️ Cevap işlenemedi")
                return
            }
            print("✅ Sunucu yanıtı:", json)
        }
        .resume()
    }
}
#Preview {
    ContentView()
}

