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

Nginx не подключается к Xray. Проверьте:

- Config Profile сохранён и назначен ноде;
- Xray запущен;
- inbound слушает `127.0.0.1:40112`;
- порт совпадает с `proxy_pass` Nginx;
- контейнер Remnawave Node использует ожидаемую сетевую архитектуру.

## `413 Request Entity Too Large`

```nginx
client_max_body_size 4m;
```

Серверный baseline допускает POST до 3 000 000 байт, хотя облегчённый клиент обычно отправляет 256–512 КБ.

## Мобильное соединение завершается после нагрузки или сна

1. Используйте `packet-up` и Extra из `templates/remnawave-xhttp-extra.json.template`.
2. Оставьте ALPN `h2`.
3. Убедитесь, что клиент использует актуальный Xray-core.
4. Обновите профиль после изменения Host.
5. Проверьте нагрузку, блокировку экрана и смену сети отдельно.

Если завершается процесс приложения, серверный timeout не устранит причину. Нужны версия приложения, встроенного ядра и клиентский журнал. См. [IOS-STABILITY.md](IOS-STABILITY.md).

## GET-вариант не работает

Для этого стенда это ожидаемо. Верните:

- `mode: packet-up`;
- POST по умолчанию — не задавайте `uplinkHTTPMethod: GET`;
- `sessionIDPlacement: query`;
- `seqPlacement: query`;
- ключи `auth` и `chunk_id`;
- исходный Xray inbound и облегчённый Host Extra из шаблонов.

Nginx при возврате к POST/query менять не требуется.

## Публичный домен показывает origin-сертификат

Публичная A-запись должна указывать на edge TurboFlare.

```bash
dig +short A "$DOMAIN"
```

## Direct origin работает, TurboFlare возвращает ошибку

Проверьте:

- origin IP и порт `443`;
- HTTPS к источнику;
- завершение делегирования;
- перевод трафика;
- учёт query string;
- отсутствие cache для XHTTP endpoint.

## Endpoint отдаёт статическую страницу

`XHTTP_PATH` не совпадает в одном из трёх мест:

1. `xhttpSettings.path` в Xray;
2. `location ^~` в Nginx;
3. Path в Remnawave Host.

## TLS error

- Address = `DOMAIN`;
- SNI = `DOMAIN`;
- Host = `DOMAIN`;
- Security Layer = TLS;
- Allow insecure = OFF;
- Port = 443.

```bash
openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

## Соединение создаётся без передачи данных

Если routing rules перечисляют `inboundTag`, добавьте:

```json
"inboundTag": ["xHTTP-TurboFlare"]
```

Убедитесь, что выбранный `outboundTag` существует на этой ноде.

## Host отсутствует в выдаче

Проверьте Host visibility, Config Profile, выбранный inbound, Internal Squad и обновление профиля на клиенте.

## `grep: binary file matches`

```bash
docker compose logs --tail=300 remnanode \
  | grep -aEi 'error|failed|xhttp|40112'
```

## Warning `creating new one`

```text
Inbound xHTTP-TurboFlare not found in inboundsHashMap, creating new one
```

Первое такое сообщение означает регистрацию inbound. Ошибка — последующий отказ запуска Xray или отсутствие listener.

## Проверка сгенерированных файлов

```bash
jq empty "build/$DOMAIN/xray-inbound.json"
jq empty "build/$DOMAIN/remnawave-xhttp-extra.json"

grep -RFn -- "$XHTTP_PATH" "build/$DOMAIN"
grep -RFn -- "$XRAY_XHTTP_PORT" "build/$DOMAIN"
```
