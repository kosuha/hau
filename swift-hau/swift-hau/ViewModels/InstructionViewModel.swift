import Foundation
import Supabase

@MainActor
class InstructionViewModel: ObservableObject {
    @Published var instructions: [Instruction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchInstructions(forTitle title: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Instruction] = try await client
                .from("instructions")
                .select()
                .eq("title", value: title)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            instructions = response
        } catch {
            errorMessage = "지시사항을 불러오는데 실패했습니다: \(error.localizedDescription)"
            print("Error fetching instructions: \(error)")
        }
        
        isLoading = false
    }
    
    func fetchAllInstructions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Instruction] = try await client
                .from("instructions")
                .select()
                .order("title", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            instructions = response
        } catch {
            errorMessage = "지시사항을 불러오는데 실패했습니다: \(error.localizedDescription)"
            print("Error fetching all instructions: \(error)")
        }
        
        isLoading = false
    }
    
    // 특정 제목의 지시사항 가져오기
    func getInstruction(forTitle title: String) -> Instruction? {
        return instructions.first { $0.title == title }
    }
    
    // 템플릿 목록 가져오기 (프로필 화면용)
    func getTemplateOptions() -> [(String, String)] {
        let templateTitles = ["냉소적인 친구", "심리학자", "모험가 해적"]
        return templateTitles.compactMap { title in
            if let instruction = getInstruction(forTitle: title) {
                return (title, instruction.content)
            }
            return nil
        }
    }
} 