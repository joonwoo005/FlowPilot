import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import GoogleSignIn

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

                #if DEBUG
                if let user = user {
                    print("[Auth] Auth state changed - User: \(user.uid), Anonymous: \(user.isAnonymous)")
                } else {
                    print("[Auth] Auth state changed - No user")
                }
                #endif
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

        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.presentationError("No root view controller found")
        }
        let presentingController = rootViewController
        #elseif canImport(AppKit)
        guard let window = NSApplication.shared.keyWindow else {
            throw AuthError.presentationError("No key window found")
        }
        let presentingController = window
        #endif

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingController)
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

    // MARK: - Link Anonymous Account with Google
    /// Links an anonymous account to a Google account
    /// Returns: tuple of (newUserId, hasExistingOnboarding)
    func linkAnonymousAccountWithGoogle() async throws -> (String, Bool) {
        guard let currentUser = currentUser, currentUser.isAnonymous else {
            throw AuthError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationError("Firebase client ID not found")
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.presentationError("No root view controller found")
        }
        let linkPresentingController = rootViewController
        #elseif canImport(AppKit)
        guard let window = NSApplication.shared.keyWindow else {
            throw AuthError.presentationError("No key window found")
        }
        let linkPresentingController = window
        #endif

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: linkPresentingController)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                throw AuthError.tokenError("Failed to get ID token")
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )

            // Try to link the anonymous account
            do {
                let authResult = try await currentUser.link(with: credential)

                // Update user document to reflect linked account
                let userRef = FirebaseConfig.shared.userDocument(userId: authResult.user.uid)
                let email: String = authResult.user.email ?? ""
                let displayName: String = authResult.user.displayName ?? ""
                let photoURL: String = authResult.user.photoURL?.absoluteString ?? ""
                try await userRef.updateData([
                    "email": email,
                    "displayName": displayName,
                    "photoURL": photoURL,
                    "isAnonymous": false,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                #if DEBUG
                print("[Auth] Successfully linked anonymous account to Google: \(authResult.user.email ?? "unknown")")
                #endif

                // Anonymous account linked - no existing data (same user)
                return (authResult.user.uid, false)

            } catch let linkError as NSError {
                // Check if the Google account already exists (credential already in use)
                if linkError.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    #if DEBUG
                    print("[Auth] Google account already exists, signing in instead")
                    #endif

                    // Sign in with the existing Google account
                    let authResult = try await Auth.auth().signIn(with: credential)

                    // Check if the existing account has completed onboarding
                    let existingUserData = try await UserRepository.shared.getUser(userId: authResult.user.uid)
                    let hasOnboarding = existingUserData?.hasCompletedOnboarding ?? false

                    #if DEBUG
                    print("[Auth] Existing account has onboarding: \(hasOnboarding)")
                    #endif

                    return (authResult.user.uid, hasOnboarding)
                }
                throw linkError
            }

        } catch let error as GIDSignInError {
            if error.code == .canceled {
                throw AuthError.cancelled
            }
            throw AuthError.googleSignInError(error.localizedDescription)
        } catch {
            throw AuthError.firebaseError(error.localizedDescription)
        }
    }

    // MARK: - Migrate Data to New User
    /// Migrates data from one user to another (used when linking anonymous to existing Google account)
    func migrateDataToUser(fromUserId: String, toUserId: String, onboardingState: OnboardingState) async throws {
        #if DEBUG
        print("[Auth] Migrating data from \(fromUserId) to \(toUserId)")
        #endif

        // Save priorities to new user
        try await PriorityRepository.shared.batchSavePriorities(onboardingState.priorities, userId: toUserId)

        // Update user profile with onboarding data
        try await UserRepository.shared.updateUserProfile(userId: toUserId, displayName: onboardingState.userName)

        // Save sleep schedule
        try await UserRepository.shared.updateSleepSchedule(
            userId: toUserId,
            wakeTime: onboardingState.sleepSchedule.wakeTime,
            sleepTime: onboardingState.sleepSchedule.sleepTime
        )

        // Mark onboarding complete
        try await UserRepository.shared.markOnboardingComplete(userId: toUserId)

        #if DEBUG
        print("[Auth] Data migration completed successfully")
        #endif
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
