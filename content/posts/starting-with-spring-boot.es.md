+++
date = 2020-01-23T23:10:39Z
title = "Empezando con Spring Boot"
comments = true
description = "Qué es Spring, cómo crear un proyecto con Spring Boot y qué significa cada fichero que te genera. Lo básico para empezar."
tags = ["init spring boot", "spring", "spring boot", "spring boot 2.0", "empezar con spring", "empezando con spring boot"]
categories = ["java","spring boot"]
+++

Vamos a ver qué es Spring, cómo crear un proyecto con Spring Boot y qué significa cada fichero que te genera cuando empiezas. Lo típico de todo curso de iniciación.

## ¿Qué es Spring?

Si paras a alguien por la calle y le preguntas te va a decir que Spring es una estación del año, pero eso no es lo que buscamos. Spring en IT es un framework open source para plataformas Java creado por Roderick "Rod" Johnson. Es ligero porque tiene una filosofía modular, es decir, tienes una base y vas añadiendo los módulos que necesitas conforme la aplicación crece. Es muy popular por su simplicidad, bajo acoplamiento y lo fácil que es testearlo.

Dentro de este framework está Spring Boot. Si vas a la web te pone que 'Spring Boot makes it easy to create stand-alone, production-grade Spring based Applications that you can "just run"'. Bastante buena descripción la verdad.

### Cómo crear un proyecto

Esto es lo más fácil que vas a aprender de Spring. No sé qué IDE usas pero yo uso IntelliJ IDEA o Eclipse con Spring Tools, y los dos tienen la opción del inicializador. Si usas otro IDE puedes ir directamente al inicializador de la web de Spring.

#### IntelliJ IDEA

Crea un nuevo proyecto, selecciona "Spring Initializr" y haz clic en "next". Rellena el formulario y vuelve a hacer clic en "next". Ahora te sale una lista con todos los módulos de Spring que puedes añadir. Aquí suelo añadir la dependencia de Lombok porque me permite tener clases más cortas, ya haré otro post sobre eso. Selecciona los módulos que necesites, haz clic en "next", dale un nombre y haz clic en "Finish". Fácil no?

![Intellij0 #intheleft #thumbinline2](/images/Intellij0.png)![Intellij2 #intheleft #thumbinline2](/images/Intellij1.png)![Intellij2 #intheleft #thumbinline2](/images/Intellij2.png)![Intellij3 #intheleft #thumbinline2](/images/Intellij3.png)

#### STS

Muy parecido a IntelliJ. Te dejo unas fotos del proceso. La diferencia está en el segundo paso, donde puedes elegir más cosas y darle nombre en el mismo paso, que es más cómodo que IntelliJ en mi opinión.

![STS #incenterreduced](/images/STS0.png)

![STS #intheleft #thumbinline2](/images/STS1.png)![STS #intheleft #thumbinline2](/images/STS2.png)

### ¿Qué tenemos en el proyecto?

Cuando abres el proyecto tienes tres ficheros como puedes ver en la siguiente imagen:

![Project Schema #incenterreduced](/images/projectschema.png)

1. El fichero "PruebaApplication" es la clase principal. Sin él no tienes un proyecto Spring Boot. Si lo abres verás algo así:

![TetsApplicationFile #incenterreduced](/images/PruebasApplicationFIle.png)

Parece una clase normal de Java, la única diferencia es la anotación `@SpringBootApplication`. Esta anotación es el equivalente de estas tres:

 - `@EnableAutoConfiguration` activa el mecanismo de autoconfiguración de Spring Boot
 - `@ComponentScan` activa el escaneo de `@Component` en el paquete donde está la aplicación
 - `@Configuration` permite registrar beans extra en el contexto o importar clases de configuración adicionales

Puedes usar la anotación que te da Spring Boot o cambiarla por estas tres, como prefieras.

2. El fichero "application.properties" es el fichero de configuración. Aquí puedes poner la conexión a la base de datos y muchas otras cosas. Como puedes ver empieza totalmente vacío.

![application properties file #incenter](/images/applicationpropertiesfile.png)

3. El fichero "PruebaApplicationTests" es el fichero de tests. Tienes que usarlo. Mucha gente te dice que quiere expertos en tests y luego no los usa, pero deberías saber qué hacer con él. Yo lo uso en mis aplicaciones aunque he estado en cinco proyectos y solo en uno lo usamos de verdad. Al principio los tests estaban, pero pasados unos meses nadie los actualizaba y quedaron obsoletos. Si quieres hacer una buena aplicación usa este fichero, lo vas a agradecer cuando tengas que revisar tickets o issues del WebService.

![application tests file #incenter](/images/pruebasTestsFile.png)

Y con esto creo que hemos terminado.

Espero que te haya sido útil. Talogo!
