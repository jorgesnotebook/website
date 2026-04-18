+++
title= "Cómo instalar Jenkins"
date= "2020-01-23"
draft = false
comments = true
categories = ["Debian", "Linux", "How to"]
description = "Qué es Jenkins, para qué sirve y cómo instalarlo en Debian. Mis notas de cuando lo monté."
tags= ["Instalar Jenkins", "instalaciones", "Jenkins Debian 9", "Jenkins Debian", "Qué es Jenkins"]
images = ['images/jenkins/jenkins2.png']
+++

Voy a intentar explicar qué es Jenkins, para qué lo usamos, cómo instalarlo en Debian y cómo usarlo. Ya sé lo que estás pensando... otro post aburrido sobre Jenkins. Pues igual sí o igual no, juzga tú mismo.

Antes de nada he de decir que esto son mis notas de cuando lo investigué, asi que puede que alguna cosa sea diferente a lo que ves en otras webs, o directamente esté mal. Si ves algo raro dímelo.

## ¿Qué es Jenkins?

Para mí, Jenkins es una aplicación web que te da una forma fácil de hacer integración continua o entrega continua en diferentes tecnologías.

Integración Continua, CI, es el proceso de automatizar la construcción y las pruebas del código cada vez que el equipo sube código al repositorio. Entrega Continua, CD, es el proceso que construye, prueba, configura y despliega desde un entorno de pruebas a producción.

Con eso creo que ya se ve para qué lo usamos. A mí me interesa bastante trabajar con él porque creo que te da más control sobre lo que estás desarrollando.

## Instalando Jenkins en Debian 9

Hay varias formas de instalarlo (Docker, War y apt). Para estas cosas soy un poco raro y prefiero instalarlo via apt. Lo primero es entrar con el usuario root y añadir la clave del repositorio:

```bash
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | apt-key add -
```

Ahora hay que añadir el repositorio en la lista de fuentes. Hay dos formas, yo uso la primera:

```bash
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
```

La segunda opción es crear el fichero `/etc/apt/sources.list.d/jenkins.list` y añadir esta línea:

```bash
deb https://pkg.jenkins.io/debian binary/
```

Ahora actualizamos apt e instalamos:

```bash
apt-get update && apt-get install jenkins
```

Y ya está. Pero espera, no te vayas todavía. Si tienes Tomcat u otra cosa en el puerto 8080 tienes que cambiar el puerto de Jenkins. Ve al fichero de configuración `/etc/default/jenkins`, línea 63, y cámbialo. Yo suelo usar puertos raros tipo 6669. Después reinicia el servicio:

```bash
/etc/init.d/jenkins restart
```

Abre el navegador y ve a Jenkins. Te va a salir algo así:

![jenkis #incenter](/images/jenkins/jenkins.png)

La contraseña inicial está aquí: `/var/lib/jenkins/secrets/initialAdminPassword`. Pégala y te saldrá esto:

![jenkins #incenter](/images/jenkins/custom.png)

Yo normalmente selecciono los plugins sugeridos, pero esta vez probé la otra opción. Después de hacer clic te sale la siguiente ventana:

![jenkins #incenter](/images/jenkins/theStarted.png)

Puedes seleccionarlos todos o ir leyendo y elegir los que quieras. Yo instalé los sugeridos y añadí algunos más como JUnit, Warnings, los plugins de ssh y todo lo de Git. Una cosa útil: puedes ver las dependencias de cada plugin haciendo clic en el número de la fila. Cuando termines de seleccionar los plugins haz clic en instalar y espera:

![jenkins #incenter](/images/jenkins/theInstallation.png)

Después puedes añadir un usuario o continuar como admin. Te recomiendo añadir un usuario admin.

![jenkins #incenter](/images/jenkins/jenkins1.png)

Luego decides la URL de Jenkins. En mi caso es algo tipo `https://myBarMan.jorgeancal.com:6669`. Y con eso está todo hecho.

![jenkins #thumbinline2](/images/jenkins/jenkins2.png) ![jenkis #thumbinline2](/images/jenkins/jenkins3-1.png)

Espero que te haya sido útil. Talogo!
