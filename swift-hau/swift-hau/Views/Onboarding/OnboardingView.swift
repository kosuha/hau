//
//  OnboardingView.swift
//  swift-hau
//
//  Created by Seonho Kim on 4/11/25.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var userViewModel: UserViewModel
    @State private var currentStep: OnboardingStep = .name
    var onComplete: () -> Void
    
    enum OnboardingStep {
        case name
        case birthdate
        case selfIntro
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch currentStep {
                case .name:
                    NameView(onNext: { goToNextStep() })
                case .birthdate:
                    BirthdateView(onNext: { goToNextStep() }, onBack: { goToPreviousStep() })
                case .selfIntro:
                    SelfIntroView(onNext: { completeOnboarding() }, onBack: { goToPreviousStep() })
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func goToNextStep() {
        switch currentStep {
        case .name:
            currentStep = .birthdate
        case .birthdate:
            currentStep = .selfIntro
        case .selfIntro:
            // 이미 마지막 단계
            break
        }
    }
    
    private func goToPreviousStep() {
        switch currentStep {
        case .name:
            // 이미 첫 단계
            break
        case .birthdate:
            currentStep = .name
        case .selfIntro:
            currentStep = .birthdate
        }
    }
    
    private func completeOnboarding() {
        // 온보딩 완료 후 메인 화면으로 돌아가기
        onComplete()
    }
} 
