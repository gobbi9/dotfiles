---
name: kotlin-preferences
description: Apply Kotlin coding, logging, and unit-testing conventions for this project, including mapper style, ktlint usage, and Kotest+Mockk patterns.
---

# Kotlin preferences

Use this skill when writing or reviewing Kotlin code.

## General Kotlin style

- Avoid using `also` and `apply` unless the block contains at least 3 statements.
- Implement mappers as extension functions.
- Use `ktlint` as linter and respect `.editorconfig` when present.

Mapper example:

```kotlin
fun CouponDto.toEntity(): CouponDocument =
    CouponDocument(
        code = code,
        discount = discount,
    )
```

## Logging

- Use `oshai/kotlin-logging` as logging framework.
- Use `logback` as logging backend.
- Log declarations must be file-level (above the class).
- The logger variable name must be `log`.
- Never include sensitive data in logs.

Log message rules:

- Start with a capital letter.
- Be a single line.
- Interpolate values using `$` or `${}` syntax.
- Use `:` before regular values.
- Use `#` for counters/integer count values.

Examples:

- `log.info { "Example of a log message:$someValue" }`
- `log.debug { "Example of a counter:#$counter" }`
- `log.error(ex) { "Error occurred: ${ex.message}" }`

Log level rules:

- `trace`: can log whole data classes; use extensively.
- `debug`: can log selected properties; use extensively.
- `info` / `warn`: never log whole data classes.

## Unit tests

- Test modules must mirror the package structure of the main module.
- Use `Kotest` + `Mockk`.
- Use `StringSpec`.
- Extension-function mapper tests should follow this format:

```kotlin
"toEntity should map DTO to entity" {
    val dto = CouponDto(
        code = "SALE10",
        discount = BigDecimal("10.50"),
    )

    val entity = dto.toEntity()

    entity.code shouldBe "SALE10"
    entity.discount shouldBe BigDecimal("10.50")
}
```
