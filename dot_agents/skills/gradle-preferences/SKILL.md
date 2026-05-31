---
name: gradle-preferences
description: Apply Gradle conventions for Kotlin DSL, version catalogs, dependency versioning, and multi-module dependency organization.
---

# Gradle preferences

Use this skill when editing Gradle build configuration.

- Use Kotlin DSL (`.kts`) over Groovy.
- Use version catalogs for dependency management.
- Never hardcode dependency versions in `build.gradle.kts`.
- Group dependencies by type/domain (logging, testing, REST, etc.).
- Keep dependency grouping consistent between `build.gradle.kts` and `libs.versions.toml`.
- In multi-module projects, each module should only declare the dependencies it needs.
- Shared dependencies should be defined in the root `build.gradle.kts`.
