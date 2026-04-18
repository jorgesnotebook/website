+++
comments= true
author = "Jorge Andreu Calatayud"
categories = ["Java", "Docker"]
tags = ["java", "openjdk", "jdk", "DockerImages", "Docker", "jvm", "jre", "maven", "Spring Boot"]
date = "2020-09-28"
description = "Aprende a crear una JRE pequeña para tus microservicios y así no pagar de más en ECR."
title= "jlink con Spring Boot"
+++

Esto siempre ha sido una prioridad para mí porque... no quiero pagar de más en ECR. Asi que toca crear imágenes Docker pequeñas.

Lo primero es listar el classpath de todas las librerias que vamos a usar. Para eso ejecutamos el siguiente comando en maven y lo guardamos en un fichero:

```shell
mvn dependency:build-classpath -Dmdep.includeScope=runtime -Dmdep.outputFile=classpath
```

Una vez que tenemos todas las librerias en el fichero, las metemos en una variable de entorno para poder usarla después:

```shell
export SERVICE_CLASSPATH=$(cat classpath)
```

Con la variable lista, toca listar todos los módulos de java. Para eso ejecutamos lo siguiente:

```shell
jdeps -cp $SERVICE_CLASSPATH --multi-release $JDK --print-module-deps --ignore-missing-deps -R target/classes
```

Siendo `$JDK` el número de la versión de Java. Una vez que tenemos todos los módulos es hora de crear el JDK slim. Para eso necesitamos ejecutar el siguiente comando (siendo `$JDEPMODULES` la lista de módulos del comando anterior):

```shell
jlink --module-path /opt/java/jmods --compress=2 --strip-debug \
  --no-header-files --no-man-pages \
  --add-modules $JDEPMODULES --output /opt/jlink
```

Y listo. Ya tenemos nuestro runtime en la carpeta `/opt/jlink` y pesa alrededor de 30 Mb en vez de los 240 Mb del JDK normal.

Estos pasos son muy fáciles de meter en un Dockerfile para automatizarlo todo. Si lo haces puedes tener una imagen de menos de 100 Mb, quizás un poco más si tienes muchas dependencias. Intentaré hacer otro post mostrando cómo hacerlo con el Dockerfile completo.

Espero que te haya sido útil. Talogo!
