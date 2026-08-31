# Стабильность XHTTP на мобильных клиентах

Проверенная для TurboFlare схема использует XHTTP `packet-up`, POST body и размещение session/sequence в query. GET body в этом стенде не работает и в конфигурацию не включён.

Нельзя гарантировать, что мобильная система никогда не выгрузит сетевое расширение приложения: результат зависит от приложения, встроенного Xray, правил маршрутизации и доступной памяти. Настройки ниже уменьшают пиковую память и количество отдельных H2/TLS transports.

## Итоговая схема

- На ноде используется исходный проверенный inbound.
- В Remnawave Host применяется облегчённый клиентский Extra.
- Nginx менять для этого варианта не требуется.
- Нода и клиент используют Xray-core `26.7.28` либо совместимую более новую версию.

## Серверный inbound

```json
{
  "xmux": {
    "maxConcurrency": "1"
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
  "scMaxBufferedPosts": 100,
  "scMaxEachPostBytes": "3000000",
  "sessionIDPlacement": "query",
  "scMinPostsIntervalMs": "5-10",
  "serverMaxHeaderBytes": 32768
}
```

Полный объект: [../templates/xray-inbound.json.template](../templates/xray-inbound.json.template).

## Клиентский Host Extra

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

## Сравнение рабочих вариантов

| Параметр | Исходный клиентский профиль | Облегчённый Host Extra | Практический эффект |
|---|---:|---:|---|
| `maxConcurrency` | `1` | `4-8` | меньше отдельных HTTP-клиентов и TLS-соединений |
| `hKeepAlivePeriod` | не задан или `8` | `0` | стандартное поведение H2 без частого прикладного ping |
| `hMaxRequestTimes` | не задан или `50` | `600-900` | реже создаётся новый transport |
| `hMaxReusableSecs` | не задан | `120-180` | старый uplink transport выводится из повторного использования |
| `scMaxEachPostBytes` | `3000000` | `256000-512000` | ниже пиковая память одного POST |
| `scMinPostsIntervalMs` | `5-10` | `30-50` | меньше кратковременных всплесков отправки |

`maxConcurrency` — число одновременно работающих логических XHTTP-соединений на одном HTTP-клиенте. При значении `1` Xray чаще создаёт дополнительные transports. Диапазон `4-8` является умеренным компромиссом.

`scMaxEachPostBytes` и `scMinPostsIntervalMs` реально влияют на клиентскую отправку в режиме `packet-up`. Поэтому они должны находиться в Host Extra, даже если похожие поля сохранены в серверном baseline.

`hMaxRequestTimes` уменьшается по мере отправки upload-запросов. `hMaxReusableSecs` запрещает назначать новые upload-запросы на устаревший transport после истечения времени.

## Почему не GET

Xray умеет сформировать GET с request body, но промежуточный CDN может удалить тело, отклонить запрос или обработать его как cacheable GET. В проверенной цепочке TurboFlare такие варианты не дошли до origin в требуемом виде.

Поэтому здесь отсутствует:

```json
"uplinkHTTPMethod": "GET"
```

При отсутствии `uplinkHTTPMethod` Xray использует POST.

## Проверка мобильного клиента

После изменения Host обновите профиль в приложении, чтобы прежний Extra не остался в cache.

1. Создайте параллельную нагрузку на 10–15 минут.
2. Проверьте непрерывную передачу данных ещё 15 минут.
3. Заблокируйте экран на 5 минут и повторите запрос.
4. Переключите Wi-Fi → мобильную сеть → Wi-Fi.
5. Проверьте восстановление без ручного пересоздания профиля.

Если приложение завершается, соберите:

- название и версию приложения;
- версию мобильной системы;
- версию встроенного Xray;
- точный сценарий: завершение приложения, разрыв transport или зависание трафика;
- клиентский и серверный журнал за одинаковый интервал времени.

## Источники

- [Xray-core 26.7.28: XHTTP config](https://github.com/XTLS/Xray-core/blob/v26.7.28/transport/internet/splithttp/config.go)
- [Xray-core 26.7.28: XMUX](https://github.com/XTLS/Xray-core/blob/v26.7.28/transport/internet/splithttp/mux.go)
- [Xray-core 26.7.28: packet-up](https://github.com/XTLS/Xray-core/blob/v26.7.28/transport/internet/splithttp/dialer.go)

