import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct LoginView: View {
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var navigateToMain = false

    // Pet info fetched from Firestore
    @State private var petName: String = ""
    @State private var petEmoji: String = "🐾" // default placeholder

    @State private var isLoading = false

    // Firestore reference
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient (purple to blue)
                LinearGradient(
                    gradient: Gradient(colors: [.purple, .blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Login")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top, 60)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    if isLoading {
                        ProgressView("Loading...")
                            .padding(.horizontal)
                    }

                    Button(action: {
                        loginUser()
                    }) {
                        Text("Login")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.pink.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .shadow(radius: 4)
                            .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        // MainView modal olarak açılıyor; böylece geri butonu çıkmıyor.
        .fullScreenCover(isPresented: $navigateToMain) {
            MainView(petName: petName, petEmoji: petEmoji)
        }
    }

    private func loginUser() {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            } else {
                // Login successful—fetch pet info from Firestore
                guard let user = Auth.auth().currentUser else {
                    self.errorMessage = "No current user."
                    self.isLoading = false
                    return
                }
                let uid = user.uid
                db.collection("users").document(uid).getDocument { snapshot, err in
                    if let err = err {
                        self.errorMessage = "Firestore error: \(err.localizedDescription)"
                        self.isLoading = false
                        return
                    }
                    
                    if let data = snapshot?.data() {
                        let fetchedName = data["petName"] as? String ?? "Your Pet"
                        let fetchedType = data["petType"] as? String ?? "Cat"
                        let emoji = (fetchedType == "Cat") ? "🐱" : "🐶"
                        
                        self.petName = fetchedName
                        self.petEmoji = emoji
                        self.navigateToMain = true
                    } else {
                        self.errorMessage = "No pet info found in Firestore."
                    }
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

