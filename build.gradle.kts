import org.asciidoctor.gradle.jvm.AsciidoctorJExtension

plugins {
    kotlin("jvm") version "2.4.20"
    kotlin("plugin.spring") version "2.4.20"
    kotlin("plugin.jpa") version "2.4.20"
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"
    id("org.asciidoctor.jvm.convert") version "4.0.5"
    id("com.gorylenko.gradle-git-properties") version "4.0.1"
}

group = "com.tistory.shanepark"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

repositories {
    mavenCentral()
}

extra["springAiVersion"] = "2.0.1"
extra["springRestDocsVersion"] = "4.0.1"

val asciidoctorExt = configurations.create("asciidoctorExt")

configure<AsciidoctorJExtension> {
    setVersion("3.0.1")
}

dependencies {
    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("tools.jackson.module:jackson-module-kotlin")

    // Spring Boot
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-devtools")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-webclient")
    implementation("org.springframework.ai:spring-ai-starter-model-openai")

    // Monitoring
    implementation("io.micrometer:micrometer-registry-prometheus")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-starter-data-jpa-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.mockito.kotlin:mockito-kotlin:6.3.0")
    testImplementation("com.h2database:h2:2.5.250")

    // Spring Docs
    testImplementation("org.springframework.restdocs:spring-restdocs-mockmvc:${property("springRestDocsVersion")}")
    asciidoctorExt("org.springframework.restdocs:spring-restdocs-asciidoctor:${property("springRestDocsVersion")}")

    // Database
    runtimeOnly("com.mysql:mysql-connector-j:26.7.0")
    implementation("com.github.gavlyukovskiy:p6spy-spring-boot-starter:2.0.1")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.flywaydb:flyway-mysql")

    // Utilities
    implementation("net.gpedro.integrations.slack:slack-webhook:1.4.0")
    implementation("nl.basjes.parse.useragent:yauaa:8.2.0")
    implementation("com.github.f4b6a3:ulid-creator:5.2.4")
    implementation("org.apache.poi:poi-ooxml:5.5.1")
    implementation("net.coobird:thumbnailator:0.4.21")
    implementation("com.twelvemonkeys.imageio:imageio-jpeg:3.15.0")
    implementation("com.twelvemonkeys.imageio:imageio-webp:3.15.0")

    // JWT
    implementation("io.jsonwebtoken:jjwt-api:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-impl:0.13.0")
    runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.13.0")

    // Web Push
    implementation("nl.martijndwars:web-push:5.1.2")
    implementation("org.bouncycastle:bcprov-jdk18on:1.85.2")
    // web-push 5.1.2 demotes httpcomponents to runtime scope, but PushService.send()
    // still returns org.apache.http.HttpResponse, so httpcore must be on the compile classpath.
    implementation("org.apache.httpcomponents:httpcore:4.4.16")
}

dependencyManagement {
    imports {
        mavenBom("org.springframework.ai:spring-ai-bom:${property("springAiVersion")}")
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
    failFast = true
    maxHeapSize = "1g"
}

tasks.jar {
    enabled = false
}

val snippetsDir = file("build/generated-snippets")
tasks {
    test {
        outputs.dir(snippetsDir)
    }

    asciidoctor {
        inputs.dir(snippetsDir)
        configurations(asciidoctorExt.name)
        dependsOn(test)
        doLast {
            copy {
                from("build/docs/asciidoc")
                into("src/main/resources/static/docs")
            }
        }
    }

    build {
        dependsOn(asciidoctor)
    }
}

allOpen {
    annotation("jakarta.persistence.Entity")
    annotation("jakarta.persistence.MappedSuperclass")
    annotation("jakarta.persistence.Embeddable")
}
