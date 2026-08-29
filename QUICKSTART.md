# Быстрый запуск за 5 минут

## 1. Переменные

```bash
git clone https://github.com/indie-master/Turboflare_CDN_Setup_Guide.git
cd Turboflare_CDN_Setup_Guide
cp .env.example .env
nano .env
```

Обязательно заменить:

```dotenv
DOMAIN=vpn.example.com
ORIGIN_IP=203.0.113.10
```

Проверить локальные порты и при необходимости заменить:

```dotenv
NGINX_INTERNAL_PORT=8443
XRAY_XHTTP_PORT=40112
```

## 2. Nginx и origin TLS

```bash
chmod +x install.sh scripts/render.sh
sudo bash install.sh
```

Если установщик попросил stream include, добавить внутрь существующего `map $ssl_preread_server_name $backend`:

```nginx
include /etc/nginx/stream-map.d/*.map;
```

Затем повторить:

```bash
sudo bash install.sh
```

## 3. TurboFlare

1. Добавить `DOMAIN` как новый сайт.
2. Делегировать домен на NS из панели.
3. Origin: `ORIGIN_IP:443`.
4. HTTPS к источнику: ON.
5. Stale cache: OFF.
6. Query string: ON.
7. Cookies: ON.
8. Включить перевод трафика.

## 4. Remnawave Config Profile

Скопировать объект:

```text
build/<DOMAIN>/xray-inbound.json
```

Применить профиль к ноде и проверить:

```bash
ss -lntp | grep ':40112'
```

## 5. Remnawave Host

Поля находятся в:

```text
build/<DOMAIN>/remnawave-host-values.md
```

В XHTTP Extra вставить:

```text
build/<DOMAIN>/remnawave-xhttp-extra.json
```

## 6. Internal Squad

1. Создать `TurboFlare-Test`.
2. Выбрать только `xHTTP-TurboFlare`.
3. Добавить одного тестового пользователя.
4. Обновить подписку в Incy/Throne.

## 7. Проверки

```bash
set -a
source .env
set +a

curl -4vk --resolve "$DOMAIN:443:$ORIGIN_IP" "https://$DOMAIN/"
curl -4v "https://$DOMAIN/"
```

Полная инструкция и диагностика находятся в [README.md](README.md).
