//
//  CallModels.swift
//  swift-hau
//
//  Created on: 현재 날짜
//

import Foundation

// MARK: - 통화 기록 관련 구조체들
struct HistoryRecord: Encodable {
    let transcript: String
    let summary: String
    let auth_id: String
}

struct HistoryResponse: Decodable, Encodable {
    let id: Int64?
    let transcript: String?
    let summary: String?
    let auth_id: String
    let created_at: String?
    
    enum CodingKeys: String, CodingKey {
        case id, transcript, summary, auth_id, created_at
    }
} 