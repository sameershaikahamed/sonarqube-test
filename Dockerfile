# Jenkins base image
FROM jenkins/jenkins:2.401.3 as jenkins-base

# Switch to root user for administrative tasks
USER root

# Update system and replace JDK 11 with JDK 17
RUN apt-get update && apt-get remove -y openjdk-11.0.19-jdk && \
    apt-get install -y openjdk-17-jdk && \
    apt-get clean

# Set environment variables for JDK 17
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Switch back to Jenkins user
USER jenkins


# Application build stage using OpenJDK 17
FROM openjdk:17.0.13-jdk-slim as build

WORKDIR /workspace/app

# Copy Maven wrapper, configuration, and source files
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
COPY src src

# Build the application and unpack the JAR file
RUN ./mvnw install -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)


# Runtime stage using Jenkins as the base image and OpenJDK 17
FROM jenkins/jenkins:2.401.3 as runtime

# Switch to root for administrative setup
USER root

# Update system and ensure JDK 17 is installed
RUN apt-get update && apt-get install -y openjdk-17-jdk && apt-get clean

# Set JDK 17 environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Application runtime setup
VOLUME /tmp
ARG DEPENDENCY=/workspace/app/target/dependency
COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Default application entrypoint
ENTRYPOINT ["java","-Dserver.port=${PORT}","-cp","app:app/lib/*","com.example.demo.DemoApplication"]

# Switch back to Jenkins user for running Jenkins
USER jenkins
