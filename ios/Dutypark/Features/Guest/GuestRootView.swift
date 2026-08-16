import SwiftUI

struct GuestRootView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var path: [GuestRoute]
    @State private var showsUnsupportedLink = false

    init(initialRoute: GuestRoute? = nil) {
        var resolvedRoute = initialRoute
#if DEBUG
        if resolvedRoute == nil,
           ProcessInfo.processInfo.arguments.contains("-ui-testing-guest-calendar") {
            resolvedRoute = .publicCalendar(42)
        }
#endif
        _path = State(initialValue: resolvedRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            GuestLandingView()
                .navigationDestination(for: GuestRoute.self) { route in
                    destination(for: route)
                }
        }
        .task {
            guard let url = session.pendingDestination,
                  GuestPendingDestinationPolicy.shouldConsume(url)
            else { return }
            _ = session.consumePendingDestination()
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
            path = [route]
        } else if GuestPendingDestinationPolicy.shouldShowUnsupported(url) {
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

enum GuestPendingDestinationPolicy {
    static func shouldConsume(_ destination: URL) -> Bool {
        GuestDeepLink.route(from: destination) != nil
    }

    static func shouldShowUnsupported(_ destination: URL) -> Bool {
        RootNavigationPolicy.isFirstPartyWebURL(destination)
            && !AppRootDeepLinkPolicy.requiresAuthentication(destination)
    }
}

private struct GuestLandingView: View {
    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let description: String
        let image: String?
    }

    private let features: [Feature] = [
        Feature(
            id: "share",
            icon: "heart",
            title: "guest.feature.share.title",
            description: "guest.feature.share.description",
            image: "IntroSchedule"
        ),
        Feature(
            id: "duty",
            icon: "clock",
            title: "guest.feature.duty.title",
            description: "guest.feature.duty.description",
            image: "IntroDuty"
        ),
        Feature(
            id: "life",
            icon: "person.2",
            title: "guest.feature.life.title",
            description: "guest.feature.life.description",
            image: nil
        ),
        Feature(
            id: "todo",
            icon: "checkmark.circle",
            title: "guest.feature.todo.title",
            description: "guest.feature.todo.description",
            image: "IntroTodo"
        ),
        Feature(
            id: "dday",
            icon: "flag",
            title: "guest.feature.dday.title",
            description: "guest.feature.dday.description",
            image: "IntroDDay"
        ),
        Feature(
            id: "holiday",
            icon: "sun.max",
            title: "guest.feature.holiday.title",
            description: "guest.feature.holiday.description",
            image: "IntroHoliday"
        )
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        hero(proxy: proxy)
                            .frame(minHeight: geometry.size.height)
                            .id("hero")

                        ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                            featurePage(feature, index: index)
                                .frame(minHeight: geometry.size.height)
                                .id(feature.id)
                        }

                        callToAction
                            .frame(minHeight: geometry.size.height)
                            .id("cta")
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.paging)
                .background(DPColor.backgroundSecondary)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("screen.guest")
    }

    private func hero(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 88)

            Text("Dutypark")
                .font(DPFont.bold(size: 50, relativeTo: .largeTitle))
                .tracking(-1)
                .foregroundStyle(
                    LinearGradient(
                        colors: [DPColor.textPrimary, DPColor.textSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 24)

            Text("guest.hero.tagline", tableName: "Guest")
                .font(DPFont.bold(size: 19, relativeTo: .title3))
                .foregroundStyle(DPColor.accent)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

            Text("guest.hero.subtitle", tableName: "Guest")
                .font(DPFont.light(size: 16, relativeTo: .body))
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(9)
                .padding(.horizontal, 26)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: GuestRoute.login) {
                HStack(spacing: 12) {
                    Text("guest.start", tableName: "Guest")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 32)
                .frame(minHeight: 60)
                .background(DPColor.accent)
                .clipShape(Capsule())
                .shadow(color: DPColor.accent.opacity(0.20), radius: 20, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.top, 38)
            .accessibilityIdentifier("guest.login")

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.45)) {
                    proxy.scrollTo(features[0].id, anchor: .top)
                }
            } label: {
                VStack(spacing: 8) {
                    Text("guest.hero.scroll", tableName: "Guest")
                        .font(DPFont.light(size: 14, relativeTo: .subheadline))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundStyle(DPColor.textMuted)
                .frame(minWidth: 160, minHeight: 60)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(DPColor.backgroundSecondary)
    }

    private func featurePage(_ feature: Feature, index: Int) -> some View {
        ZStack(alignment: .leading) {
            DPColor.backgroundSecondary

            VStack(spacing: 18) {
                featureMockup(feature)

                Image(systemName: feature.icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: 64, height: 64)
                    .background(
                        LinearGradient(
                            colors: [DPColor.backgroundTertiary, DPColor.backgroundSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(DPColor.borderPrimary)
                    }
                    .accessibilityHidden(true)

                Text(GuestLocalization.text(feature.title))
                    .font(DPFont.bold(size: 31, relativeTo: .title))
                    .foregroundStyle(DPColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text(GuestLocalization.text(feature.description))
                    .font(DPFont.light(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)

            VStack(spacing: 13) {
                ForEach(features.indices, id: \.self) { dot in
                    Circle()
                        .fill(dot == index ? DPColor.textPrimary : DPColor.borderPrimary)
                        .frame(width: dot == index ? 10 : 8, height: dot == index ? 10 : 8)
                }
            }
            .padding(.leading, 24)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func featureMockup(_ feature: Feature) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28)
                .fill(DPColor.backgroundFooter)

            if let image = feature.image {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [DPColor.backgroundSecondary, DPColor.backgroundTertiary],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Image(systemName: feature.icon)
                    .font(.system(size: 46))
                    .foregroundStyle(DPColor.textMuted)
                    .padding(.top, 115)
            }

            Capsule()
                .fill(DPColor.backgroundFooter)
                .frame(width: 72, height: 22)
                .padding(.top, 7)
        }
        .frame(width: 150, height: 325)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(DPColor.backgroundFooter, lineWidth: 6)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, y: 15)
        .accessibilityHidden(true)
    }

    private var callToAction: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(DPColor.textPrimary)
                .frame(width: 64, height: 64)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 24)

            Text("guest.cta.title", tableName: "Guest")
                .font(DPFont.bold(size: 30, relativeTo: .title))
                .foregroundStyle(DPColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 22)

            Text("guest.cta.description", tableName: "Guest")
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)

            NavigationLink(value: GuestRoute.login) {
                HStack(spacing: 12) {
                    Text("guest.login", tableName: "Guest")
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textOnDark)
                .padding(.horizontal, 38)
                .frame(minHeight: 60)
                .background(
                    LinearGradient(
                        colors: [DPColor.accent, DPColor.accentHover],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: DPColor.accent.opacity(0.20), radius: 20, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("guest.login.cta")

            NavigationLink(value: GuestRoute.guide) {
                Label(GuestLocalization.text("guest.guide.short"), systemImage: "book")
                    .font(DPFont.light(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 44)
                    .background(.clear)
                    .clipShape(Capsule())
                    .overlay { Capsule().stroke(DPColor.borderSecondary) }
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .accessibilityIdentifier("guest.guide")

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [DPColor.backgroundSecondary, DPColor.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
        AppLocalization.locale
    }

    private static var selectedBundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: selectedLocale.identifier,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
