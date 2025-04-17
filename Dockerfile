FROM openjdk:17-jdk-alpine
WORKDIR /app

# Crée un utilisateur non-root pour plus de sécurité
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copie le JAR en le renommant systématiquement
COPY target/*.jar app.jar

# Paramètres JVM recommandés
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75"

EXPOSE 8082
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
