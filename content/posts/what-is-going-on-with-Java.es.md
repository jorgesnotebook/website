+++
date = 2020-01-23T23:08:17Z
title = "¿Qué está pasando con Java?"
description = "¿Otra versión de Java? Pues sí. Te cuento qué está pasando con Java y hacia dónde va."
tags = ["AdoptOpenJDK", "java", "JDK", "JDK 11", "JDK 11 LTS", "JDK 6", "JDK 7", "JDK 8","OpenJDK", "opinion"]
categories = ["Java", "Opinion"]
comments = true
images = ['images/oracleversion.png']
+++

El otro día salieron varias noticias sobre la nueva versión de Java. Mi primera reacción fue... ¿otra? ¿en serio? Como mucha gente al principio de su carrera, no me fijaba en las diferencias entre versiones de Java porque estaba centrado en los proyectos en los que trabajaba. O igual era solo yo. El caso es que tuve un parón entre trabajos y me puse a actualizar todo lo que tenía pendiente, y esto era una de las cosas de la lista. Espero que te resulte interesante.

Como todos saben, Java tiene una nueva versión del JDK que es el JDK 11.

Hace un año Oracle saco el JDK 9, que mucha gente dijo que era muy malo. Luego saco el JDK 11 después del JDK 10, que es lo lógico. Yo aprendí a desarrollar con el JDK 7, que salió en julio de 2011 mientras estudiaba formación profesional. Tres años después empecé la universidad y tuve que usar el JDK 8, que mucha gente decía que era una maravilla. Si te soy sincero, no me di cuenta de las diferencias entre ellos. Ni me importaba. Pero ahora que estoy investigando cuál usar para mis aplicaciones, me importa. Asi que te voy a contar qué va a pasar con Java en los próximos años y cuál elegí.

## El futuro

Es una locura, pero somos desarrolladores asi que es lo que hay cuando entras en este mundo. El futuro de Java es open source, pero depende de ti o de la empresa para la que trabajes, porque si quieres usarlo... saca la cartera. Para una empresa no creo que sea un problema, pero para alguien como yo que mira cada euro que gasta, sí lo es porque no tenia pensado gastar dinero en esto. La buena noticia es que si no quieres pagar puedes usar OpenJDK. Mira los precios del JDK por si te merece la pena:

|  Productos/Métricas | N up | Licencia | CPU  | Soporte |
|---|---|---|---|---|
| Java SE Advanced Desktop  | $40  | $8.80  | - | -  |
| Java SE Advanced | $100  | $22  | 5000  | $ 1100  |
| Java SE Suite  | $300 | $66  | 15000  |  $3300 |

Quizás dices "tampoco es tan caro" y en parte tienes razón, si tienes una aplicación exitosa y ganas bien no es una locura. Pero como yo no sé si mis aplicaciones van a ser exitosas, prefiero guardar el dinero. Supongo que en una empresa no habría problema, pero al menos en España los clientes no quieren gastar un euro más en desarrollo. Eso es lo que nos dicen los jefes cuando les pedimos algo, por lo menos.

## Sobre las versiones

Cuando leí lo de la nueva versión y que habría que pagar si quería usar el JDK para mis aplicaciones, me eché a reír. Después de reírme un rato, vi una línea de tiempo de las versiones de Java. Espero que no me digan que también hay que pagar por esta imagen.

![Oracle Versions #incenter](/images/oracleversion.png)

Como puedes ver en la imagen, hay algo bueno, que es OpenJDK, que es público y gratuito para siempre. Si tienes una aplicación usando el JDK que no es OpenJDK, lo siento pero estás en un callejón sin salida y tienes que actualizar cuanto antes. Yo usaría OpenJDK, pero es que me encanta el open source.

Ahora te voy a dar información sobre el JDK 11 LTS y sobre OpenJDK.

## JDK 11 LTS

No es buena señal ver LTS en un kit de desarrollo y menos en Java. No entiendo exactamente qué está pensando Oracle, pero no me parece que vayan por buen camino. Cuando ves el historial de versiones y todo lo que quieren hacer, lo primero que piensas es... esto es raro. Estuvieron tres años sacando una versión y ahora cada pocos meses tienes un montón de actualizaciones y versiones. Me preocupa un poco porque en un año vi tres versiones de Java, dos de las cuales nadie usa, y el propio Oracle dijo que las olvidaras porque no eran buenas.

Espero que todo vaya bien. De momento Oracle nos ha hablado de algunos de los bugs corregidos en el JDK 11:

- [181](http://openjdk.java.net/jeps/181): Control de acceso basado en Nest
- [309](http://openjdk.java.net/jeps/309): Constantes de ficheros de clase dinámicas
- [315](http://openjdk.java.net/jeps/): Mejora de Aarch64 Intrinsics
- [318](http://openjdk.java.net/jeps/): Epsilon: Un Garbage Collector sin operación
- [320](http://openjdk.java.net/jeps/): Eliminar los módulos Java EE y CORBA
- [321](http://openjdk.java.net/jeps/): HTTP Client (Estándar)
- [323](http://openjdk.java.net/jeps/): Sintaxis de variable local para parámetros Lambda
- [324](http://openjdk.java.net/jeps/): Acuerdo de claves con Curve25519 y Curve448
- [327](http://openjdk.java.net/jeps/): Unicode 10
- [328](http://openjdk.java.net/jeps/): Flight Recorder
- [329](http://openjdk.java.net/jeps/): Algoritmos criptográficos ChaCha20 y Poly1305
- [330](http://openjdk.java.net/jeps/): Lanzar programas de un solo fichero fuente
- [331](http://openjdk.java.net/jeps/): Perfilado de heap de bajo overhead
- [332](http://openjdk.java.net/jeps/): Transport Layer Security (TLS) 1.3
- [333](http://openjdk.java.net/jeps/): ZGC: Un Garbage Collector escalable de baja latencia (Experimental)
- [335](http://openjdk.java.net/jeps/): Deprecar el motor JavaScript Nashorn
- [336](http://openjdk.java.net/jeps/): Deprecar las herramientas y API Pack200

Si quieres saber más sin leer mucho, Java tiene su propio canal en [YouTube](https://www.youtube.com/channel/UCmRtPmgnQ04CMUpSUqPfhxQ).

## OpenJDK

Úsalo, es el que voy a usar yo. ¿Por qué? Porque uso Linux y no quiero usar algo que no sea gratuito. Las cosas gratuitas siempre son las mejores, y más si es comida gratis. He leído bastante sobre ello y parece que no voy a tener ningún problema al cambiar, pero eso es en teoría. Ya os contaré si surge algo, aunque no creo que pase nada.

Si quieres instalarlo ve a la [web oficial](http://openjdk.java.net/) o a [esta](https://adoptopenjdk.net/index.html?variant=openjdk11&jvmVariant=hotspot). AdoptOpenJDK proporciona binarios precompilados de OpenJDK con scripts e infraestructura totalmente open source.

En resumen, si no quieres pagar, usa OpenJDK.

Espero que te haya sido útil. Talogo!
