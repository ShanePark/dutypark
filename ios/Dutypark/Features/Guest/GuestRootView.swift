import SwiftUI

struct GuestRootView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var path: [GuestRoute]
    @State private var showsUnsupportedLink = false

    init(initialRoute: GuestRoute? = nil) {
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            GuestLandingView()
                .navigationDestination(for: GuestRoute.self) { route in
                    destination(for: route)
                }
        }
        .task {
            guard let url = session.consumePendingDestination() else { return }
            open(url)
        }
        .onOpenURL { url in
            open(url)
        }
        .alert("link.unsupported.title", isPresented: $showsUnsupportedLink) {
            Button("link.unsupported.ok", role: .cancel) {}
        } message: {
            Text("link.unsupported.message")
        }
    }

    private func open(_ url: URL) {
        if let route = GuestDeepLink.route(from: url) {
            session.deferDestinationUntilAuthenticated(url)
            path = [route]
        } else if url.scheme?.lowercased() == "https",
                  url.host?.lowercased() == "dutypark.o-r.kr" {
            showsUnsupportedLink = true
        }
    }

    @ViewBuilder
    private func destination(for route: GuestRoute) -> some View {
        switch route {
        case .login:
            LoginView(wrapsInNavigationStack: false)
        case .guide:
            GuestGuideView()
        case .terms:
            GuestPolicyView(type: .terms)
        case .privacy:
            GuestPolicyView(type: .privacy)
        case .publicCalendar(let memberID):
            GuestPublicCalendarView(memberID: memberID)
        }
    }
}

private struct GuestLandingView: View {
    private let features: [(icon: String, title: String, description: String)] = [
        ("heart.fill", "guest.feature.share.title", "guest.feature.share.description"),
        ("clock.fill", "guest.feature.duty.title", "guest.feature.duty.description"),
        ("person.2.fill", "guest.feature.life.title", "guest.feature.life.description"),
        ("checkmark.circle.fill", "guest.feature.todo.title", "guest.feature.todo.description"),
        ("flag.fill", "guest.feature.dday.title", "guest.feature.dday.description"),
        ("sun.max.fill", "guest.feature.holiday.title", "guest.feature.holiday.description")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DPSpacing.large) {
                hero

                LazyVStack(spacing: DPSpacing.small) {
                    ForEach(features, id: \.title) { feature in
                        HStack(alignment: .top, spacing: DPSpacing.medium) {
                            Image(systemName: feature.icon)
                                .font(.title2)
                                .foregroundStyle(DPColor.accent)
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                                .background(DPColor.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                                Text(GuestLocalization.text(feature.title))
                                    .font(.headline)
                                    .foregroundStyle(DPColor.textPrimary)
                                Text(GuestLocalization.text(feature.description))
                                    .font(.subheadline)
                                    .foregroundStyle(DPColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(DPSpacing.medium)
                        .background(DPColor.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(
                            RoundedRectangle(cornerRadius: DPRadius.standard)
                                .stroke(DPColor.borderPrimary)
                        )
                    }
                }

                VStack(spacing: DPSpacing.small) {
                    Text("guest.cta.title", tableName: "Guest")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("guest.cta.description", tableName: "Guest")
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.center)
                    NavigationLink(value: GuestRoute.login) {
                        Label(GuestLocalization.text("guest.login"), systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DPPrimaryButtonStyle())
                    .accessibilityIdentifier("guest.login")
                    NavigationLink(value: GuestRoute.guide) {
                        Label(GuestLocalization.text("guest.guide.title"), systemImage: "book")
                            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    }
                    .accessibilityIdentifier("guest.guide")
                }
                .padding(.vertical, DPSpacing.large)

                HStack(spacing: DPSpacing.large) {
                    NavigationLink(
                        GuestLocalization.text("guest.policy.terms"),
                        value: GuestRoute.terms
                    )
                    NavigationLink(
                        GuestLocalization.text("guest.policy.privacy"),
                        value: GuestRoute.privacy
                    )
                }
                .font(.footnote)
                .foregroundStyle(DPColor.textMuted)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.bottom, DPSpacing.large)
        }
        .background(DPColor.backgroundSecondary)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Dutypark").font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(GuestLocalization.text("guest.login.short"), value: GuestRoute.login)
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
        }
        .accessibilityIdentifier("screen.guest")
    }

    private var hero: some View {
        VStack(spacing: DPSpacing.medium) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56))
                .foregroundStyle(DPColor.accent)
                .accessibilityHidden(true)
            Text("Dutypark")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(DPColor.textPrimary)
            Text("guest.hero.tagline", tableName: "Guest")
                .font(.title3.bold())
                .foregroundStyle(DPColor.accent)
                .multilineTextAlignment(.center)
            Text("guest.hero.subtitle", tableName: "Guest")
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: GuestRoute.login) {
                Text("guest.start", tableName: "Guest")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
        }
        .padding(.vertical, DPSpacing.large)
    }
}

enum GuestLocalization {
    static func text(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "Guest",
            bundle: selectedBundle,
            value: key,
            comment: ""
        )
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: selectedLocale, arguments: arguments)
    }

    private static var selectedLocale: Locale {
        guard let language = UserDefaults.standard.string(forKey: "dp-language"),
              !language.isEmpty
        else { return .current }
        return Locale(identifier: language)
    }

    private static var selectedBundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: selectedLocale.identifier,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
