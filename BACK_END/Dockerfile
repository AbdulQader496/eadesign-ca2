FROM eclipse-temurin:17-jdk-jammy

WORKDIR /app

COPY target/*.jar app.jar

EXPOSE 8080

USER 1000:1000

ENTRYPOINT ["java", "-jar", "app.jar"]
