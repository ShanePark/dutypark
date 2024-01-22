<!--
https://simpleicons.org
<a href="#" target="_blank"><img src="https://img.shields.io/badge/[TEXT YOU WANT]-[COLOR CODE]?style=flat-square&logo=[BRAD NAME]&logoColor=white"/></a>
-->

<div align="center">
<h1>Duty Park 📆</h1>
Simple Duty Manager <br>
<a href="#" target="_blank"><img src="https://img.shields.io/badge/Kotlin-7F52FF?style=flat-square&logo=Kotlin&logoColor=white"/></a>
<a href="#" target="_blank"><img src="https://img.shields.io/badge/Spring Boot-6DB33F?style=flat-square&logo=Spring-Boot&logoColor=white"/></a>
<a href="#" target="_blank"><img src="https://img.shields.io/badge/JPA-ED2761?style=flat-square&logo=Spring&logoColor=white"/></a>
<a href="#" target="_blank"><img src="https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=MySQL&logoColor=white"/></a>
<a href="#" target="_blank"><img src="https://img.shields.io/badge/Thymeleaf-005F0F?style=flat-square&logo=Thymeleaf&logoColor=white"/></a>
</div>

## What's DutyPark?
> [Demo Page](https://dutypark.o-r.kr)
- I planned and developed it in one day when my wife just forgot her duty and late for work
- It is a simple duty manager that can be used by anyone
- Easy to put in your own duty and share it with your family or friends

## How to install

```bash
$ git clone https://github.com/Shane-Park/dutypark.git
$ ./gradlew build
$ java -jar build/libs/dutypark-0.0.1-SNAPSHOT.jar --spring.profiles.active=prod
```

It's recommended to prepare your own database as default is in-memory database
run your database and add it to application-prod.yml

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/dutypark
    username: dutypark
    password: dutypark
  jpa:
    hibernate:
      ddl-auto: update
    database-platform: org.hibernate.dialect.MySQL8Dialect  
```

```bash
$ docker run -d -p 3306:3306 --name mysql -e MYSQL_ROOT_PASSWORD=password -e MYSQL_DATABASE=dutypark -e MYSQL_USER=dutypark -e MYSQL_PASSWORD=dutypark mysql:8.0
```

