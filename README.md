# Dutypark

[https://dutypark.o-r.kr](https://dutypark.o-r.kr)

<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Thymeleaf-005F0F?style=flat-square&logo=Thymeleaf&logoColor=white"/></a> <a href="#" target="_blank"><img src="https://img.shields.io/badge/Vue.js-4FC08D?style=flat-square&logo=Vue.js&logoColor=white"/></a>

> **Add your duties and schedules in a snap — then share with friends or family.**

A lightweight, web-based duty and schedule manager. Perfect for both developers and non-tech users—track shifts,
personal events, tasks, D-Day countdowns, then share or collaborate in a snap.

---

## 🚀 Features

| Category                    | Feature                  | Description                                                 |
|:----------------------------|:-------------------------|:------------------------------------------------------------|
| **Duty Management**         | Duty Calendar            | Color-coded shifts & off-days                               |
|                             | Excel Schedule Import    | Bulk-upload duties via Excel                                |
| **Scheduling**              | Event Scheduling         | Create events with public/friends/family/private visibility |
|                             | D-Day Countdown          | "D-n" labels for special dates                              |
|                             | LLM based Title Parsing  | Auto-extract date/time from natural-language event titles   |
| **Sharing & Collaboration** | Friend & Family Sharing  | Share calendars with fine-grained permissions               |
|                             | Schedule Tagging         | Tag friends or family in events to notify and include them  |
|                             | Multi-Account Management | Switch or manage multiple user accounts seamlessly          |
| **Team & Organizations**    | Team Calendars           | Shared group schedules for teams or families                |
|                             | Team Manager Controls    | Admin tools: add/remove members, define custom duty types   |
| **Integrations**            | Holiday Sync             | Auto-fetch public holidays (via data.go.kr API)             |
|                             | OAuth Login              | Kakao login out-of-the-box (extendable to other providers)  |
| **UI & App**                | Mobile-Friendly & PWA    | Responsive design, installable Progressive Web App          |

---

## 🛠️ Quick Start

### Prerequisites
- Docker & Docker Compose
- (Optional) Domain name with SSL certificate for production

### Development Setup

1. **Clone & Configure**
   ```bash
   git clone https://github.com/ShanePark/dutypark.git
   cd dutypark
   cp .env.sample .env
   ```

2. **Edit Environment Variables**
   ```bash
   # Edit .env file with your configuration
   MYSQL_ROOT_PASSWORD=your_secure_password
   MYSQL_PASSWORD=your_db_password
   JWT_SECRET=your_base64_jwt_secret
   # ... configure other variables as needed
   ```

3. **Run with Docker Compose**
   ```bash
   # For local development (HTTP only)
   NGINX_CONF_NAME=nginx.local.conf docker compose up -d
   
   # For production (HTTPS with SSL)
   docker compose up -d
   ```

4. **Access the Application**
   - Local: http://localhost
   - Production: https://your-domain.com

### Development Database Only
If you prefer to run the app locally and only use Docker for the database:
```bash
cd dutypark_dev_db
docker compose up -d  # MySQL on port 3307
```

### Production Deployment
1. Set up SSL certificates with Let's Encrypt
2. Configure `.env` with production values
3. Run `docker compose up -d`

### Monitoring (Optional)
- **Prometheus**: Internal metrics collection
- **Grafana**: Available at http://localhost:3000 (admin/admin)

---

## Sample Usage

![eagles](./README.assets/eagles.png)

Enjoy planning with **dutypark**.
