+++
title = "Cómo instalar GitLab en Debian 9"
date = "2020-01-23"
draft = false
comments = true
author = "Jorge Andreu Calatayud"
categories = ["Gitlab", "Debian", "Linux", "How to"]
description = "Llevaba tiempo dándole vueltas a instalar GitLab en mi servidor y al final me decidí. Aquí te cuento cómo."
tags= ["GitLab", "GitLab en Debian 9", "GitLab en Debian", "Instalar GitLab", "instalaciones"]
images = ['images/gitlab1.png']
+++

Llevaba tiempo dándole vueltas a instalar GitLab en mi servidor. Tenia Git instalado y me gustaba, pero GitLab lo había probado hace un tiempo y me gusto bastante, asi que al final me decidí.

GitLab es una herramienta muy buena. Puedes tenerla en tu servidor, crear equipos, proyectos para esos equipos y asignar roles a cada persona. Lo de los equipos me parece genial la verdad.

## Instalación

Lo primero es instalar las dependencias:

```bash
# apt install -y curl openssh-server ca-certificates
```

Mucha gente instala postfix también para las notificaciones por email. Si quieres usar otra solución para el correo puedes saltarte este paso y configurar un servidor SMTP externo después de instalar GitLab:

```bash
# apt install -y postfix
```

Una vez instalado todo, hay que añadir los repositorios de GitLab:

```bash
# curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
```

Ahora toca instalarlo. Hay dos versiones: Community Edition o Enterprise Edition. Con la Enterprise tienes 30 días de prueba y luego pagas por usuario, pero puedes usar MySQL y tiene más funcionalidades. La gratuita es la Community, que es la que tengo yo. Si quieres puedes configurar una URL externa, algo tipo `http://myFox.jorgeancal.com`. Si lo tienes en local no la necesitas, pero te dejo el comando de todas formas:

```bash
# EXTERNAL_URL="http://gitlab.example.com"

# apt install gitlab-ce
```

## Configuración básica

Hay un comando que te va a hacer falta bastante, que es el de regenerar la configuración:

```bash
# gitlab-ctl reconfigure
```

Y estos para arrancar y parar GitLab:

```bash
# gitlab-ctl start

# gitlab-ctl stop
```

Para configurar la contraseña de admin, abre el navegador con tu URL o con tu IP si no pusiste una. Te va a salir algo así:

![gitlab change root password #incenter](/images/gitlab1.png)

Después de eso tendrás la pantalla de login. El usuario admin es "root" y la contraseña es la que acabas de poner.

![gitlab login #incenter](/images/logIn.png)

Cuando entres verás algo así y ya puedes empezar con tus proyectos:

![gitlab welcome page #incenter](/images/welcome.png)

Espero que te haya sido útil. Talogo!
