---
name: jvm-preferences
description: Apply JVM ecosystem preferences for wrapper usage, JDK selection, interface design, and documentation expectations for public APIs.
---

# JVM preferences

Use this skill when working in JVM-based projects (Kotlin/Java/Gradle/Maven).

- Use `./gradlew` instead of `gradle` when available.
- Use `./mvnw` instead of `mvn` when available.
- Prefer LTS versions of Azul Java JDK for new projects.
- Only create interfaces for injectable services when there are multiple implementations.
- Add KDoc or Javadoc for all public members:
  - Classes should use a multi-line header.
  - Methods, fields, and functions should use a single-line header.
