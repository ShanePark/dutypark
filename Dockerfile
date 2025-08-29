# Runtime only
FROM eclipse-temurin:21-jre-alpine

# Add non-root user
RUN addgroup -g 1000 dutypark && \
    adduser -D -s /bin/sh -u 1000 -G dutypark dutypark

# Set working directory
WORKDIR /app

# Create logs directory
RUN mkdir -p /dutypark/logs && chown dutypark:dutypark /dutypark/logs

# Copy the built jar from local build
COPY build/libs/*.jar app.jar

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
