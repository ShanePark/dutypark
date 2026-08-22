import Foundation

enum SocialConfirmation: Identifiable {
    case reject(FriendRequestDTO)
    case cancel(FriendRequestDTO)
    case removeFamily(DashboardFriendDetailDTO)
    case removeFriend(DashboardFriendDetailDTO)
    case block(DashboardFriendDetailDTO)
    case unblock(BlockedMemberDTO)
    case sendFamily(DashboardFriendDetailDTO)
    case unpin(DashboardFriendDetailDTO)

    var id: String {
        switch self {
        case .reject(let request): "reject-\(request.id)"
        case .cancel(let request): "cancel-\(request.id)"
        case .removeFamily(let friend): "family-\(friend.member.id ?? -1)"
        case .removeFriend(let friend): "friend-\(friend.member.id ?? -1)"
        case .block(let friend): "block-\(friend.member.id ?? -1)"
        case .unblock(let member): "unblock-\(member.id)"
        case .sendFamily(let friend): "sendFamily-\(friend.member.id ?? -1)"
        case .unpin(let friend): "unpin-\(friend.member.id ?? -1)"
        }
    }

    var memberName: String {
        switch self {
        case .reject(let request): request.fromMember.name
        case .cancel(let request): request.toMember.name
        case .removeFamily(let friend), .removeFriend(let friend), .block(let friend),
            .sendFamily(let friend), .unpin(let friend): friend.member.name
        case .unblock(let member): member.name
        }
    }

    var titleKey: String {
        switch self {
        case .reject: "social.confirm.reject.title"
        case .cancel: "social.confirm.cancel.title"
        case .removeFamily: "social.confirm.removeFamily.title"
        case .removeFriend: "social.confirm.removeFriend.title"
        case .block: "social.confirm.block.title"
        case .unblock: "social.confirm.unblock.title"
        case .sendFamily: "social.confirm.sendFamily.title"
        case .unpin: "social.confirm.unpin.title"
        }
    }

    var messageKey: String {
        switch self {
        case .reject: "social.confirm.reject.message"
        case .cancel: "social.confirm.cancel.message"
        case .removeFamily: "social.confirm.removeFamily.message"
        case .removeFriend: "social.confirm.removeFriend.message"
        case .block: "social.confirm.block.message"
        case .unblock: "social.confirm.unblock.message"
        case .sendFamily: "social.confirm.sendFamily.message"
        case .unpin: "social.confirm.unpin.message"
        }
    }

    var confirmKey: String {
        switch self {
        case .reject: "social.action.reject"
        case .cancel: "social.action.cancel"
        case .removeFamily: "social.action.removeFamily"
        case .removeFriend: "social.action.removeFriend"
        case .block: "social.action.block"
        case .unblock: "social.action.unblock"
        case .sendFamily: "social.action.sendRequest"
        case .unpin: "social.action.unpin"
        }
    }

    /// Undoing a block and sending a family request both need a confirmation, but neither
    /// takes anything away, so only the removing actions get the destructive styling.
    var isDestructive: Bool {
        switch self {
        case .reject, .cancel, .removeFamily, .removeFriend, .block, .unpin: true
        case .unblock, .sendFamily: false
        }
    }
}
