# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dutypark is a Spring Boot web application built with Kotlin for duty and schedule management. It features a Vue.js frontend with Thymeleaf templates, MySQL database, and Docker-based deployment with monitoring stack.

**Tech Stack:**
- Backend: Kotlin + Spring Boot 3.4.3, Spring Data JPA, Spring Security  
- Frontend: Thymeleaf templates, Vue.js, Bootstrap
- Database: MySQL 8.0 with Flyway migrations
- Build: Gradle with Kotlin DSL
- Deployment: Docker + Docker Compose + Nginx
- Monitoring: Prometheus + Grafana
- AI: Spring AI with Gemini integration
- Authentication: JWT + OAuth (Kakao)

## Development Commands

### Build and Run
```bash
# Build the application
./gradlew build

# Run application locally  
./gradlew bootRun

# Run tests
./gradlew test

# Clean build
./gradlew clean build

# Generate Spring REST Docs
./gradlew asciidoctor
```

### Docker Development
```bash
# Run full stack with Docker Compose
docker compose up -d

# Local development (HTTP only)
NGINX_CONF_NAME=nginx.local.conf docker compose up -d

# Run only database for local development
cd dutypark_dev_db && docker compose up -d
```

### Environment Setup
```bash
# Copy environment template
cp .env.sample .env
# Edit .env with your configuration
```

## Architecture Overview

### Package Structure
- `com.tistory.shanepark.dutypark`
  - `admin/` - Admin functionality (user management, teams)
  - `common/` - Shared utilities, config, exceptions, external APIs
  - `dashboard/` - Main dashboard views
  - `duty/` - Core duty management (schedules, batch imports, duty types)
  - `holiday/` - Holiday integration with data.go.kr API
  - `member/` - User management, friends, D-Day counters
  - `schedule/` - Event scheduling with LLM-based parsing
  - `security/` - Authentication, JWT, OAuth
  - `team/` - Team/organization management
  - `todo/` - Todo list functionality

### Key Components

**Controllers:** Follow Spring MVC pattern with separate View and API controllers
- `*ViewController.kt` - Thymeleaf template rendering
- `*Controller.kt` - REST API endpoints  

**Services:** Business logic layer with comprehensive service classes for each domain

**Repositories:** Spring Data JPA repositories with custom query methods

**Security:** JWT-based authentication with OAuth integration (Kakao), role-based access control

**Database:** MySQL with Flyway migrations in `src/main/resources/db/migration/`

## Key Features Implementation

### AI-Powered Schedule Parsing
- Uses Spring AI + Gemini API for natural language title parsing
- Located in `schedule.timeparsing` package
- Extracts date/time from event descriptions

### Multi-tenancy Support
- Team-based organization structure
- Fine-grained permission system for calendar sharing
- Friend/family relationship management

### Duty Management
- Excel import functionality for bulk duty uploads  
- Color-coded duty types with customization
- Calendar visualization with duty overlays

### Monitoring & Observability
- Prometheus metrics via Spring Boot Actuator
- Grafana dashboards (accessible at localhost:3000)
- Structured logging with request correlation

## Development Guidelines

### Database Changes
- All schema changes must be done via Flyway migrations
- Migration files in `src/main/resources/db/migration/v2/`
- Follow naming convention: `V{version}__{description}.sql`

### Authentication Testing
- Test users can be created via admin interface
- JWT tokens are required for authenticated endpoints
- Use `@Login` annotation for controller method authentication

### External API Integration
- Data.go.kr API for Korean public holidays
- Kakao OAuth for user authentication  
- All API keys configured via environment variables

### Frontend Integration
- Thymeleaf templates in `src/main/resources/templates/`
- Vue.js components embedded in templates
- Bootstrap for responsive design

## Testing

### Test Structure
- Unit tests: Service layer testing with mocking
- Integration tests: Full application context testing
- Controller tests: MockMvc-based API testing
- Spring REST Docs: API documentation generation

### Running Specific Tests
```bash
# Run single test class
./gradlew test --tests "ClassName"

# Run tests with pattern
./gradlew test --tests "*ServiceTest"

# Test with coverage
./gradlew test jacocoTestReport
```

## Configuration

### Environment Variables (see .env.sample)
- Database: MySQL connection settings
- JWT: Secret key for token signing
- OAuth: Kakao REST API key
- External APIs: Data.go.kr service key, Gemini API key
- SSL: Domain and certificate configuration

### Profiles
- dev profile for local development

### Docker Deployment
- Multi-service setup: app, database, nginx, prometheus, grafana
- SSL certificate integration with Let's Encrypt
- Health checks and restart policies configured

## CRITICAL: Git Commit Policy
**NEVER commit changes automatically or proactively.**
- Only commit when the user explicitly asks for a commit with clear instructions like "커밋해줘", "commit this", "create a commit", etc.
- Do not commit after completing tasks, even if the work is finished
- Do not suggest committing unless specifically asked
- Let the user decide when and what to commit
- This rule is ABSOLUTE and must NEVER be violated
