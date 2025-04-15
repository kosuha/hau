import SwiftUI
import Supabase
import AuthenticationServices
import CryptoKit
import GoogleSignIn

class AuthViewModel: NSObject, ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // 로그인 과정에서 nonce를 저장하기 위한 변수
    private var currentNonce: String?
    
    // 현재 인증 상태 확인
    func checkAuthStatus() {
        isLoading = true
        
        Task {
            do {
                // 세션 가져오기 시도
                let session = try await client.auth.session
                await MainActor.run {
                    if session != nil {
                        // 세션이 있으면 사용자 정보 가져오기
                        Task { await self.fetchUser() }
                    } else {
                        // 세션이 없으면 로그아웃 상태로 설정
                        self.isLoggedIn = false
                        self.isLoading = false
                    }
                }
            } catch {
                print("세션 확인 오류: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoggedIn = false
                    self.isLoading = false
                    // 세션 오류는 일반적인 상황이므로 사용자에게 알림 표시 안 함
                }
            }
        }
    }
    
    // 사용자 정보 가져오기
    func fetchUser() async {
        do {
            // 현재 세션에서 사용자 정보 가져오기
            if let user = try? await client.auth.session.user {
                await MainActor.run {
                    self.currentUser = user
                    self.isLoggedIn = true
                    self.isLoading = false
                }
            } else {
                // 사용자 정보가 없으면 로그아웃 상태로 설정
                await MainActor.run {
                    self.isLoggedIn = false
                    self.isLoading = false
                }
            }
        } catch {
            print("사용자 정보 가져오기 오류: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoggedIn = false
                self.isLoading = false
                // 오류 메시지 표시 (필요하다면)
                // self.errorMessage = "사용자 정보를 가져오는 중 오류가 발생했습니다."
            }
        }
    }
    
    // 애플 로그인 시작
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // nonce 생성 및 저장
        currentNonce = randomNonceString()
        request.nonce = sha256(currentNonce!)
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        authController.delegate = self
        authController.performRequests()
    }

	// 구글 로그인 시작
	func signInWithGoogle() {
        isLoading = true
        
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            self.errorMessage = "Google 로그인 설정이 올바르지 않습니다."
            self.isLoading = false
            return
        }
        
        // 구글 로그인을 위해 nonce 생성
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // 구글 로그인 설정
        let config = GIDConfiguration(clientID: clientID)
        
        // 현재 표시 중인 ViewController 가져오기
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            self.errorMessage = "Google 로그인을 시작할 수 없습니다."
            self.isLoading = false
            return
        }
        
        // 해시된 nonce 생성
        let hashedNonce = sha256(nonce)
        
        // 최신 Google Sign-In SDK API 형식으로 호출
        GIDSignIn.sharedInstance.signIn(
            withPresenting: rootViewController,
            hint: nil,
            additionalScopes: ["email", "profile"]
        ) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Google 로그인 오류: \(error.localizedDescription)")
                    self.errorMessage = "Google 로그인 과정에서 오류가 발생했습니다."
                    return
                }
                
                guard let result = result,
                      let idToken = result.user.idToken?.tokenString else {
                    self.errorMessage = "사용자 정보를 가져올 수 없습니다."
                    return
                }
                
                // Supabase에 nonce와 함께 Google 토큰 전달
                self.signInWithGoogleToken(idToken: idToken, nonce: self.currentNonce)
            }
        }
    }
    
    // Google 토큰으로 Supabase 로그인
    private func signInWithGoogleToken(idToken: String, nonce: String?) {
        isLoading = true
        
        Task {
            do {
                let response = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .google,
                        idToken: idToken,
                        nonce: nonce  // 생성한 nonce 전달
                    )
                )
                
                await MainActor.run {
                    self.currentUser = response.user
                    self.isLoggedIn = true
                    self.isLoading = false
                }
            } catch {
                print("Supabase Google 로그인 오류: \(error)")
                await MainActor.run {
                    self.errorMessage = "로그인 처리 중 오류가 발생했습니다."
                    self.isLoading = false
                }
            }
        }
    }
    
    // 로그아웃
    func signOut() {
        isLoading = true
        
        Task {
            do {
                try await client.auth.signOut()
                await MainActor.run {
                    self.isLoggedIn = false
                    self.currentUser = nil
                    self.isLoading = false
                }
            } catch {
                print("로그아웃 오류: \(error.localizedDescription)")
                await MainActor.run {
                    self.errorMessage = "로그아웃 중 오류가 발생했습니다."
                    self.isLoading = false
                }
            }
        }
    }
    
    // 무작위 nonce 문자열 생성
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("nonce 생성 실패: \(errorCode)")
                }
                return random
            }
            
            for random in randoms {
                if remainingLength == 0 {
                    break
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    // SHA256 해시 함수
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("애플 ID 인증 정보를 가져오지 못했습니다.")
            return
        }
        
        guard let nonce = currentNonce else {
            print("유효하지 않은 상태: nonce가 없습니다.")
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("ID 토큰을 가져오지 못했습니다.")
            return
        }
        
        // Supabase에 애플 로그인 토큰 전달
        signInWithAppleToken(idToken: idTokenString, nonce: nonce)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "애플 로그인 과정에서 오류가 발생했습니다: \(error.localizedDescription)"
            self.isLoading = false
        }
    }
    
    private func signInWithAppleToken(idToken: String, nonce: String) {
        isLoading = true
        
        Task {
            do {
                let response = try await client.auth.signInWithIdToken(
                    credentials: .init(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                
                await MainActor.run {
                    self.currentUser = response.user
                    self.isLoggedIn = true
                    self.isLoading = false
                }
            } catch {
                print("Supabase 애플 로그인 오류: \(error)")
                await MainActor.run {
                    self.errorMessage = "로그인 처리 중 오류가 발생했습니다."
                    self.isLoading = false
                }
            }
        }
    }
}