# Стабильный XHTTP-профиль для iOS

Этот профиль предназначен для VLESS XHTTP `packet-up` через TurboFlare CDN. Он снижает пиковые аллокации на клиенте и не держит один H2 transport бесконечно после сна или смены сети.

Нельзя гарантировать, что iOS никогда не выгрузит VPN Network Extension: на это влияют приложение, встроенная версия Xray, клиентская маршрутизация и системный лимит памяти. Серверный профиль устраняет наиболее рискованные параметры текущей схемы.

## Remnawave Host

| Поле | Значение |
|---|---|
| Network | `xhttp` |
| Security Layer | `TLS` |
| Mode | `packet-up` |
| ALPN | `h2` |
| Allow insecure | `OFF` |

TurboFlare в этой схеме принимает клиентский HTTP/2, поэтому fallback на HTTP/1.1 не нужен.

## XHTTP Extra на клиенте

```json
{
  "xmux": {
    "maxConcurrency": "4-8",
    "hKeepAlivePeriod": 0,
    "hMaxRequestTimes": "600-900",
    "hMaxReusableSecs": "120-180"
  },
  "seqKey": "chunk_id",
  "noSSEHeader": true,
  "noGRPCHeader": true,
  "seqPlacement": "query",
  "sessionIDKey": "auth",
  "xPaddingBytes": "50-150",
  "xPaddingMethod": "tokenish",
  "sessionIDLength": "16-32",
  "xPaddingObfsMode": true,
  "xPaddingPlacement": "header",
  "scMaxEachPostBytes": "256000-512000",
  "sessionIDPlacement": "query",
  "scMinPostsIntervalMs": "30-50"
}
```

Что изменилось относительно агрессивного профиля:

| Параметр | Было | Стало | Эффект |
|---|---:|---:|---|
| `maxConcurrency` | `1` | `4-8` | меньше отдельных H2/TCP transports при большом числе приложений |
| `hKeepAlivePeriod` | `8` | `0` | стандартный H2 keepalive Xray вместо ping каждые 8 секунд |
| `hMaxRequestTimes` | `50` | `600-900` | меньше частых пересозданий соединений, но ниже типичного лимита 1000 запросов |
| `hMaxReusableSecs` | не задан | `120-180` | старый transport перестаёт использоваться после сна/смены сети |
| `scMaxEachPostBytes` | `3000000` | `256000-512000` | заметно ниже пиковая память одного packet-up POST |
| `scMinPostsIntervalMs` | `5-10` | `30-50` | меньше всплесков POST/goroutine и нагрузки на мобильный радиомодуль |

`hKeepAlivePeriod: 0` означает стандартное поведение Xray для H2, а не полное отключение keepalive. Для отключения используется отрицательное значение, здесь оно не рекомендуется.

## Xray inbound на сервере

Сервер должен принимать блок не меньше максимального клиентского значения:

```json
{
  "mode": "packet-up",
  "scMaxBufferedPosts": 30,
  "scMaxEachPostBytes": 1000000
}
```

Полный серверный объект находится в `templates/xray-inbound.json.template`. `xmux`, `hMaxRequestTimes`, `hMaxReusableSecs` и `scMinPostsIntervalMs` являются клиентской настройкой и намеренно не дублируются в inbound.

## Проверка на iPhone

После изменения Host обновите подписку и пересоздайте профиль в приложении, чтобы старый Extra не остался в кэше.

1. Откройте несколько сайтов и выполните speed test 10-15 минут.
2. Посмотрите видео 15 минут и убедитесь, что VPN не выключился.
3. Заблокируйте экран на 5 минут, затем сразу откройте сайт.
4. Переключитесь Wi-Fi -> LTE -> Wi-Fi без ручного переподключения VPN.
5. Повторите тест с отключёнными тяжёлыми `geoip/geosite`-правилами, если процесс приложения всё ещё завершается.

## Если проблема осталась

Зафиксируйте четыре значения:

- название и версию iOS-приложения;
- версию iOS;
- версию Xray, встроенную в приложение;
- симптом: приложение закрывается, значок VPN исчезает или значок остаётся, но трафик зависает.

Это три разных класса неисправностей. Падение по памяти требует обновления/исправления iOS-клиента; зависание после сна чаще связано с повторным использованием stale H2 socket; обычный разрыв виден в клиентском или серверном журнале.

## Источники

- [Xray-core #5344: High RAM consumption when using xhttp](https://github.com/XTLS/Xray-core/issues/5344)
- [Xray-core #6268: High xray client memory consumption for xhttp/http2 server](https://github.com/XTLS/Xray-core/issues/6268)
- [Xray-core #6348: stale H2 packet-up socket after idle/network change](https://github.com/XTLS/Xray-core/issues/6348)
- [XHTTP XMUX parameters, PR #4163](https://github.com/XTLS/Xray-core/pull/4163)
