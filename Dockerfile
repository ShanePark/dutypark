# Multi-stage build
FROM eclipse-temurin:21-jdk-alpine AS builder

# Set working directory
WORKDIR /app

# Copy gradle wrapper and build files
COPY gradle/ gradle/
COPY gradlew .
COPY build.gradle.kts .
COPY settings.gradle.kts .

# Download dependencies (for better caching)
RUN ./gradlew dependencies --no-daemon

# Copy source code
COPY src/ src/
COPY dutypark_secret/ dutypark_secret/

# Build the application (skip asciidoctor and tests)
RUN ./gradlew build --no-daemon -x test -x asciidoctor

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

# Add non-root user
RUN addgroup -g 1000 dutypark && \
    adduser -D -s /bin/sh -u 1000 -G dutypark dutypark

# Set working directory
WORKDIR /app

# Create logs directory
RUN mkdir -p /dutypark/logs && chown dutypark:dutypark /dutypark/logs

# Copy the built jar from builder stage
COPY --from=builder /app/build/libs/*.jar app.jar

# Change ownership
RUN chown dutypark:dutypark /app/app.jar

# Switch to non-root user
USER dutypark

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "-Djava.security.egd=file:/dev/./urandom", "/app/app.jar"]
