# Быстрый запуск лабораторного стенда

> Материал предназначен для обучения и работы с собственной либо авторизованной инфраструктурой.

## 1. Переменные

```bash
git clone https://github.com/indie-master/Turboflare_CDN_Setup_Guide.git
cd Turboflare_CDN_Setup_Guide
cp .env.example .env
nano .env
```

Замените демонстрационные значения:

```dotenv
DOMAIN=cdn.example.com
ORIGIN_IP=203.0.113.10
```

Проверьте локальные порты:

```dotenv
NGINX_INTERNAL_PORT=8443
XRAY_XHTTP_PORT=40112
```

## 2. Nginx и origin TLS

```bash
chmod +x install.sh scripts/render.sh
sudo bash install.sh
```

Если требуется stream include, добавьте внутрь существующего `map $ssl_preread_server_name $backend`:

```nginx
include /etc/nginx/stream-map.d/*.map;
```

Повторите `sudo bash install.sh`.

## 3. TurboFlare

1. Добавьте `DOMAIN` как новый сайт.
2. Делегируйте зону на NS из кабинета.
3. Укажите origin `ORIGIN_IP:443`.
4. Включите HTTPS к источнику.
5. Выключите stale cache.
6. Включите учёт query string и cookies.
7. Дождитесь завершения делегирования.

## 4. Config Profile

Добавьте объект `build/<DOMAIN>/xray-inbound.json`, назначьте профиль ноде и проверьте:

```bash
ss -lntp | grep ':40112'
```

## 5. Host

Поля Host находятся в `build/<DOMAIN>/remnawave-host-values.md`.

В XHTTP Extra вставьте `build/<DOMAIN>/remnawave-xhttp-extra.json`.

Используйте `packet-up`, POST по умолчанию, ALPN `h2` и query-размещение session/sequence. GET-варианты для этого стенда не применяются.

## 6. Internal Squad

1. Создайте `TurboFlare-Lab`.
2. Выберите только `xHTTP-TurboFlare`.
3. Добавьте одну тестовую запись.
4. Расширяйте состав после проверки.

## 7. Проверка

```bash
set -a
source .env
set +a

curl -4vk --resolve "$DOMAIN:443:$ORIGIN_IP" "https://$DOMAIN/"
curl -4v "https://$DOMAIN/"
```

Подробности: [README.md](README.md). Мобильная диагностика: [docs/IOS-STABILITY.md](docs/IOS-STABILITY.md).

