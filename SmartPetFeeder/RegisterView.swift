import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var email = ""
    @State private var password = ""
    @State private var petName = ""
    @State private var petType = "Cat"
    @State private var errorMessage = ""
    @State private var navigateToMain = false
    
    let petTypes = ["Cat", "Dog"]
    
    
    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            ZStack {
                
                LinearGradient(gradient: Gradient(colors: [.purple, .blue]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Register")
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
                    
                    TextField("Pet Name", text: $petName)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    
                    
                    Picker("Pet Type", selection: $petType) {
                        ForEach(petTypes, id: \.self) { type in
                            Text(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    
                    Button {
                        registerUser()
                    } label: {
                        Text("Register")
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
        
        .fullScreenCover(isPresented: $navigateToMain) {
            MainView(petName: petName, petEmoji: petType == "Cat" ? "🐱" : "🐶")
        }
    }
    
    private func registerUser() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
            } else {
                // Registration success, now store pet info in Firestore
                guard let user = result?.user else {
                    self.errorMessage = "User creation failed."
                    return
                }
                let uid = user.uid
                let petData: [String: Any] = [
                    "petName": self.petName,
                    "petType": self.petType
                ]
                
                db.collection("users").document(uid).setData(petData) { err in
                    if let err = err {
                        self.errorMessage = "Firestore error: \(err.localizedDescription)"
                    } else {
                        // Pet info stored successfully, navigate to MainView
                        self.navigateToMain = true
                    }
                }
            }
        }
    }
}

#Preview {
    RegisterView()
}

