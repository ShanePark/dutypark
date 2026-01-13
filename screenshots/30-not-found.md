# 30-not-found.png - iOS Implementation Status

## Screenshot Features

The screenshot shows a 404 Not Found page with the following elements:
1. Large "404" number display (gray, prominent)
2. "페이지를 찾을 수 없습니다" message (Page not found)
3. "홈으로 돌아가기" button (Return to home - blue primary button)

## iOS App Current Status

### Implemented
- `APIError.notFound` case exists in `APIError.swift` for HTTP 404 error handling
- Error messages are defined: "요청한 리소스를 찾을 수 없습니다."

### Missing Components

#### 1. ErrorView Component
A reusable error view component for displaying API errors (including 404) is not implemented.

**Suggested implementation:**
- Create `ErrorView.swift` in `Components/` folder
- Display error code prominently (like "404")
- Show localized error message
- Include action button (retry or navigate home)
- Support different error types (notFound, forbidden, serverError, networkError)

#### 2. NotFoundView (Optional)
While iOS native apps don't use URL-based routing like web apps, a dedicated view for displaying "resource not found" scenarios could be useful when:
- A schedule/duty/todo being viewed is deleted
- Deep link navigation fails
- Data synchronization results in missing resources

## Recommendation

Since iOS apps use view-based navigation rather than URL routing, a full "404 page" is not directly applicable. However, consider implementing:

1. **ErrorView Component** - A reusable component similar to `EmptyStateView` but for error states:
   ```swift
   struct ErrorView: View {
       let errorCode: String?  // e.g., "404"
       let title: String
       let message: String?
       let actionTitle: String?
       let action: (() -> Void)?
   }
   ```

2. **Usage in ViewModels** - Show ErrorView when API returns 404:
   - DutyViewModel: When duty calendar data is not found
   - ScheduleViewModel: When schedule is deleted while viewing
   - TeamManageViewModel: When team access is revoked

## Priority

**Medium** - The existing error handling via `APIError.errorDescription` provides basic feedback, but a visual error component would improve user experience consistency with the web app.
