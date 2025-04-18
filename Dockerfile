FROM openjdk:17-jdk-alpine
WORKDIR /app

RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
COPY target/*.jar app.jar

ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75"

EXPOSE 8082
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
