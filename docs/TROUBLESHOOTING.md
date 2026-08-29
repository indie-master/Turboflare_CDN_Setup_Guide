# Диагностика TurboFlare + Remnawave XHTTP

## Базовый сбор состояния

```bash
set -a
source .env
set +a

dig +short NS "$DOMAIN"
dig +short A "$DOMAIN"

ss -lntp | grep -E ':443|:8443|:40112'

sudo nginx -t

curl -4vk --resolve "$DOMAIN:443:$ORIGIN_IP" "https://$DOMAIN/"
curl -4v "https://$DOMAIN/"

tail -n 50 "/var/log/nginx/$DOMAIN.access.log"
tail -n 50 "/var/log/nginx/$DOMAIN.error.log"

cd /opt/remnanode
docker compose logs --since=15m remnanode \
  | grep -aEi 'xHTTP-TurboFlare|40112|error|failed'
```

## `502 Bad Gateway`

Nginx не может подключиться к Xray.

```bash
ss -lntp | grep ':40112'
```

Проверить:

- Config Profile сохранён и назначен ноде;
- Xray запущен;
- inbound слушает `127.0.0.1`;
- порт в Xray совпадает с `proxy_pass` Nginx;
- контейнер Remnawave Node использует ожидаемую сетевую архитектуру.

## `413 Request Entity Too Large`

В XHTTP location должен быть лимит выше `scMaxEachPostBytes`:

```nginx
client_max_body_size 4m;
```

## Публичный домен показывает origin-сертификат

Запрос обходит TurboFlare и попадает прямо на origin.

Проверить:

```bash
dig +short A "$DOMAIN"
```

Публичный A должен указывать на edge TurboFlare. Не создавайте публичный A корневого домена непосредственно на origin.

## Direct origin работает, TurboFlare возвращает ошибку

Проверить в панели:

- точный origin IP;
- порт `443`;
- HTTPS к источнику включён;
- трафик переведён;
- делегирование завершено.

## XHTTP path отдаёт cover page

Путь не совпадает в одном из трёх мест:

1. `xhttpSettings.path` в Xray;
2. `location ^~` в Nginx;
3. Path в Remnawave Host.

Сравнить с `.env`:

```dotenv
XHTTP_PATH=/static/getFile/video/segment.ts
```

## Клиент сообщает TLS error

В Remnawave Host:

- Address = `DOMAIN`;
- SNI = `DOMAIN`;
- Host = `DOMAIN`;
- Security Layer = TLS;
- Allow insecure = OFF;
- порт = 443.

Проверить edge certificate:

```bash
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

## Соединение устанавливается, но трафика нет

Проверить routing rules. Если правила используют `inboundTag`, в них должен присутствовать новый tag:

```json
"inboundTag": ["xHTTP-TurboFlare"]
```

Проверить, что `outboundTag` существует и доступен на этой ноде.

## Host не появляется в подписке

Проверить:

- Host visibility включена;
- выбран правильный Config Profile;
- выбран `xHTTP-TurboFlare`;
- Internal Squad содержит inbound;
- пользователь добавлен в Squad;
- подписка обновлена в клиенте.

## `grep: binary file matches`

Это не ошибка Xray. Использовать текстовый режим:

```bash
docker compose logs --tail=300 remnanode \
  | grep -aEi 'error|failed|xhttp|40112'
```

## Warning `creating new one`

Сообщение:

```text
Inbound xHTTP-TurboFlare not found in inboundsHashMap, creating new one
```

допустимо при первой регистрации inbound. Ошибкой является последующий отказ запуска Xray или отсутствие listener.

## Проверка совпадения сгенерированных конфигов

```bash
jq empty "build/$DOMAIN/xray-inbound.json"
jq empty "build/$DOMAIN/remnawave-xhttp-extra.json"

grep -RFn -- "$XHTTP_PATH" "build/$DOMAIN"
grep -RFn -- "$XRAY_XHTTP_PORT" "build/$DOMAIN"
```
