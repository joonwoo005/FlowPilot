import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthError?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError("Firebase client ID not found")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.presentationError("No root view controller found")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                throw AuthError.tokenError("Failed to get ID token")
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            let authResult = try await Auth.auth().signIn(with: credential)

            // Create or update user document in Firestore
            try await createUserDocumentIfNeeded(for: authResult.user)

            #if DEBUG
            print("[Auth] Signed in as: \(authResult.user.email ?? "unknown")")
            #endif

        } catch let error as GIDSignInError {
            if error.code == .canceled {
                throw AuthError.cancelled
            }
            throw AuthError.googleSignInError(error.localizedDescription)
        } catch {
            throw AuthError.firebaseError(error.localizedDescription)
        }
    }

    // MARK: - Sign Out
    func signOut() throws {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            throw AuthError.signOutError(error.localizedDescription)
        }
    }

    // MARK: - Continue as Guest
    func continueAsGuest() async throws {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let result = try await Auth.auth().signInAnonymously()
            try await createUserDocumentIfNeeded(for: result.user)

            #if DEBUG
            print("[Auth] Signed in anonymously: \(result.user.uid)")
            #endif
        } catch {
            throw AuthError.firebaseError(error.localizedDescription)
        }
    }

    // MARK: - Create User Document
    private func createUserDocumentIfNeeded(for user: User) async throws {
        let userRef = FirebaseConfig.shared.userDocument(userId: user.uid)
        let document = try await userRef.getDocument()

        if !document.exists {
            let userData: [String: Any] = [
                "uid": user.uid,
                "email": user.email ?? "",
                "displayName": user.displayName ?? "",
                "photoURL": user.photoURL?.absoluteString ?? "",
                "isAnonymous": user.isAnonymous,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            try await userRef.setData(userData)

            #if DEBUG
            print("[Auth] Created user document for: \(user.uid)")
            #endif
        }
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard let user = currentUser else {
            throw AuthError.notAuthenticated
        }

        // Delete user data from Firestore
        let userRef = FirebaseConfig.shared.userDocument(userId: user.uid)
        try await userRef.delete()

        // Delete Firebase Auth account
        try await user.delete()

        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Auth Error
enum AuthError: LocalizedError {
    case configurationError(String)
    case presentationError(String)
    case tokenError(String)
    case googleSignInError(String)
    case firebaseError(String)
    case signOutError(String)
    case notAuthenticated
    case cancelled

    var errorDescription: String? {
        switch self {
        case .configurationError(let message): return "Configuration error: \(message)"
        case .presentationError(let message): return "Presentation error: \(message)"
        case .tokenError(let message): return "Token error: \(message)"
        case .googleSignInError(let message): return "Google Sign-In error: \(message)"
        case .firebaseError(let message): return "Firebase error: \(message)"
        case .signOutError(let message): return "Sign out error: \(message)"
        case .notAuthenticated: return "User is not authenticated"
        case .cancelled: return "Sign in was cancelled"
        }
    }
}
