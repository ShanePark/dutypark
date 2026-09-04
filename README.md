<p align="center">
  <a href="https://apps.apple.com/us/app/dutypark/id6801560782">
    <img src="frontend/public/apple-touch-icon.png" width="120" alt="Dutypark app icon">
  </a>
</p>

# Dutypark

[한국어](README.ko.md) | **English**

> A social calendar for shifts, schedules, and the people who matter.

Dutypark brings work schedules and everyday plans into one calendar, with sharing controls for friends, family, and teams.

[Web](https://dutypark.o-r.kr/) · [App Store](https://apps.apple.com/us/app/dutypark/id6801560782)

## Highlights

- Organize shifts and schedules in a color-coded monthly calendar
- Share each schedule as public, friends, family, or private, and tag the people involved
- Manage team rosters and import supported Excel duty schedules
- Keep track of Todos, D-Days, search results, and notifications
- Use cached Calendar and Todo data offline in the native iPhone app

For a fuller product tour, visit the [Dutypark website](https://dutypark.o-r.kr/) or the App Store page above.

## Repository

- `src/` — Kotlin and Spring Boot backend
- `frontend/` — Vue 3, TypeScript, and Vite web app
- `ios/` — native SwiftUI iPhone app
- `docs/` — demo, design, and App Store asset workflows

The service uses MySQL with Flyway migrations. See [`frontend/README.md`](frontend/README.md), [`ios/README.md`](ios/README.md), and [`docs/app-store/README.md`](docs/app-store/README.md) for platform-specific details.

## Local development

Requirements: JDK 25+, Node.js 20+, and Docker. iOS development additionally requires Xcode 26+.

```bash
# Terminal 1
cd dutypark_dev_db
docker compose up -d

# Terminal 2 (from the repository root)
./gradlew bootRun --args='--spring.profiles.active=dev'

# Terminal 3 (from the repository root)
cd frontend
npm install
npm run dev
```

The web app runs at [http://localhost:5173](http://localhost:5173) and proxies API requests to the backend at `http://localhost:8080`.

## License

[MIT](LICENSE)
