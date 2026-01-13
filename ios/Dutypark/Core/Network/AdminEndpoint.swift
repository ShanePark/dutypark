import Foundation

struct AdminEndpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?

    init(path: String, method: HTTPMethod = .get, body: Encodable? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

extension AdminEndpoint {
    static func members(keyword: String?, page: Int, size: Int) -> AdminEndpoint {
        let encodedKeyword = (keyword ?? "")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return AdminEndpoint(path: "/members?keyword=\(encodedKeyword)&page=\(page)&size=\(size)")
    }

    static var refreshTokens: AdminEndpoint {
        AdminEndpoint(path: "/refresh-tokens")
    }

    static func teams(keyword: String?, page: Int, size: Int) -> AdminEndpoint {
        let encodedKeyword = (keyword ?? "")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return AdminEndpoint(path: "/teams?keyword=\(encodedKeyword)&page=\(page)&size=\(size)")
    }

    static func createTeam(request: TeamCreateDto) -> AdminEndpoint {
        AdminEndpoint(path: "/teams", method: .post, body: request)
    }

    static func checkTeamName(name: String) -> AdminEndpoint {
        AdminEndpoint(path: "/teams/check", method: .post, body: TeamNameCheckRequest(name: name))
    }

    static func deleteTeam(id: Int) -> AdminEndpoint {
        AdminEndpoint(path: "/teams/\(id)", method: .delete)
    }
}
