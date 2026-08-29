# App Store Connect submission draft

Last reviewed: 2026-08-29 (KST)

This document is the version-controlled input draft for App Store Connect. It is not
evidence that the fields were saved in App Store Connect. Do not add reviewer passwords,
OAuth secrets, private keys, webhook URLs, device tokens, or real user data here.

## 1. App Privacy Details draft

Declare all listed data as **linked to the user**, used for **App Functionality**, and
**not used for tracking**, unless the final production-flow check proves a narrower
answer. Dutypark does not use data to track users across other companies' apps or sites.

| App Store Connect category | Data used by Dutypark | Recommended answer |
|---|---|---|
| Contact Info — Name | Profile name and inquiry/report name snapshots | Collected, linked, App Functionality, not tracking |
| Contact Info — Email Address | Password/OAuth account email and guest inquiry email | Collected, linked, App Functionality, not tracking |
| User Content — Photos or Videos | Profile images and user-selected/camera attachments | Collected, linked, App Functionality, not tracking |
| User Content — Customer Support | Inquiry subject/body, replies, history, and related support metadata | Collected, linked, App Functionality, not tracking |
| User Content — Other User Content | Schedules, D-Days, duty data, Todo, team/friend content, report text and content snapshots, and file attachments | Collected, linked, App Functionality, not tracking |
| Identifiers — User ID | Dutypark account/member/session relationships and OAuth account links | Collected, linked, App Functionality, not tracking |
| Identifiers — Device ID | APNs registration token and device/session registration metadata | Collected, linked, App Functionality, not tracking |
| Other Data Types | IP address, user-agent, session/security/consent metadata, operational and account-deletion records | Collected, linked, App Functionality, not tracking |

The bundled iOS privacy manifest must contain the corresponding collected-data entries,
including `NSPrivacyCollectedDataTypeCustomerSupport`. The manifest is a binary declaration
and does not replace App Store Connect Privacy Details.

### Processors and external flows

- Apple, Kakao, and Naver provide authentication. Dutypark stores the account link and
  credentials needed for the selected provider. The native Apple authorization request
  does not request Apple name or email scopes.
- Apple Push Notification service receives the device token and notification payload
  required to deliver notifications. Do not include unnecessary personal or free-form
  content in production notification payloads.
- Google Gemini receives only the date and schedule text after the user separately opts
  into `AI_SCHEDULE_PARSING`. Dutypark does not intentionally send member, team, or record
  identifiers in that request. Manual schedule entry remains available.
- Current Slack application events are restricted to fixed operational text and enums;
  inquiry/report content, names, user IDs, record IDs, IP addresses, request bodies, and
  stack traces are excluded. If production behavior later sends user-linked data, update
  both the policy and App Privacy Details.

### Retention and deletion boundaries

- Account deletion is asynchronous and normally completes within five minutes for the
  account data and files identified by the product UI. A receipt can be checked after
  sign-out; receipt status is retained for 30 days.
- Incomplete uploads are cleaned up after 24 hours. Login-attempt data is kept for 7 days,
  and operational logs for up to 365 days, as stated in the current privacy policy.
- Inquiry and report records, including necessary content/name snapshots, may remain after
  account deletion until the support, safety, dispute, or legal purpose ends. No fixed
  purge period is currently approved. Do not answer App Store Connect or Review Notes as
  if these records are deleted within five minutes. Exact periods, minimization, and
  access controls remain non-blocking privacy-governance follow-up work.

Public privacy policy URL: <https://dutypark.o-r.kr/privacy>

The page was opened without a login gate on 2026-08-29 and displayed the policy with an
effective date of 2026-08-19.

## 2. Review Notes draft (English)

Copy the following into Review Notes after confirming the reviewer account is active.
Credentials belong exclusively in App Review Information's secure username/password
fields, never in these notes.

> Dutypark is a productivity app for personal schedules, shift calendars, D-Days, Todo
> items, and optional team/friend sharing. It does not provide a social feed, content
> discovery, or user-to-user chat.
>
> Sign in with the reviewer account supplied in App Review Information. The primary tabs
> are Home, Calendar, Todo, Team, and More. The reviewer account has representative sample
> data. Camera, Photos, and Files access is requested only when the reviewer chooses the
> corresponding attachment action.
>
> User-generated text can be reported and the related user can be blocked from the
> relevant shared-content flow. Dutypark applies a content filter to covered public/shared
> text fields. The service has no public social feed.
>
> AI schedule parsing is optional. The first use presents a separate consent disclosure.
> Only the selected date and schedule text are sent for parsing; manual entry remains
> available if consent is declined or parsing fails.
>
> Account deletion is available in the app at More > profile card > Delete Account. After
> the final confirmation, the request is processed asynchronously and normally completes
> within five minutes. The app signs the user out and provides a receipt-based status page
> that can show processing, completed, or failed/support states. Inquiry and report records
> may be retained separately for support, safety, dispute, or legal purposes as described
> in the privacy policy; the five-minute estimate does not apply to those retained records.
>
> Apple, Kakao, and Naver are optional external sign-in providers. Core functionality is
> available with the reviewer account supplied in App Review Information, without using
> a reviewer's personal third-party account. The reviewer account and core backend will
> remain available throughout review.
>
> Please review other feature flows before using Delete Account because successful
> deletion permanently removes that login.

## 3. Review account operation

Put the reviewer username and password only in App Store Connect's secure
`App Review Information` fields, and keep that account and the core backend available for
the review window. This is covered by the consolidated App Store Connect list below.

## 4. Age Rating questionnaire draft

Use the exact wording shown by the current App Store Connect questionnaire. The following
is a source-based draft, not a predicted or final rating.

| Questionnaire area | Draft answer and rationale |
|---|---|
| Primary category | Productivity |
| User-Generated Content | Yes. Users create schedules, D-Days, Todo, profile text, team/friend content, photos, and files; some schedule/D-Day content can be public or shared. Reporting, blocking, and text filtering are present. |
| Messaging and Chat | No. Inquiry replies are customer support, not communication between users; there is no direct or group chat. |
| Social Media | No based on the current product: there is no social feed, discovery, recommendation, follower graph, or general-audience posting surface. Public links and ShareLink exist, so re-evaluate if App Store Connect defines those as social-media functionality. |
| Unrestricted Web Access | No. External policy/support/authentication pages and purpose-specific links are not a general web browser, and the final binary has no service-admin web console. |
| Advertising | No, based on the current source, product flow, and production configuration. |
| Contests, Gambling, Loot Boxes | None. |
| Sexual Content, Nudity, Violence, Alcohol, Tobacco, Drugs, Medical/Treatment | Not intentionally provided by Dutypark. Answer frequency using actual production content and the questionnaire wording; do not treat a banned-word list as proof that user-entered content can never appear. |
| Parental Controls / Age Assurance | None in the current product. Do not claim these controls unless implemented and reviewer-visible. |

Record the rating calculated by App Store Connect after all answers are saved. If Apple
classifies public/shared UGC differently, update this draft and the Review Notes.

## 5. Required in App Store Connect

- App Store Connect Privacy Details saved values and validation result.
- Review Notes and secure reviewer-account fields saved values.
- Questionnaire answers and calculated age rating.
- Uploaded build processing/export-compliance status and the prepared ko/en screenshots.
