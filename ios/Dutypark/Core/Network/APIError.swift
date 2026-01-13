import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case clientError(statusCode: Int, data: Data)
    case serverError(statusCode: Int)
    case unknown(statusCode: Int)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case .unauthorized:
            return "로그인이 필요합니다."
        case .forbidden:
            return "접근 권한이 없습니다."
        case .notFound:
            return "요청한 리소스를 찾을 수 없습니다."
        case .clientError(let statusCode, _):
            return "요청 오류가 발생했습니다. (코드: \(statusCode))"
        case .serverError(let statusCode):
            return "서버 오류가 발생했습니다. (코드: \(statusCode))"
        case .unknown(let statusCode):
            return "알 수 없는 오류가 발생했습니다. (코드: \(statusCode))"
        case .decodingError:
            return "데이터 처리 중 오류가 발생했습니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        }
    }
}
