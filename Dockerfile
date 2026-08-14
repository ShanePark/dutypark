FROM eclipse-temurin:25-jre-alpine

RUN addgroup -g 1000 dutypark && \
    adduser -D -s /bin/sh -u 1000 -G dutypark dutypark

WORKDIR /app

RUN mkdir -p /dutypark/logs && chown dutypark:dutypark /dutypark/logs

COPY build/libs/*.jar app.jar

RUN chown dutypark:dutypark /app/app.jar

USER dutypark

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
