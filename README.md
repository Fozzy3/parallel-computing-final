# Archivo del GTFS-Realtime abierto de TransMilenio

Capturas del feed GTFS-Realtime abierto de TransMilenio S.A. (`https://gtfs.transmilenio.gov.co`), guardadas desde el 11 de noviembre de 2026 a las 23:00 UTC. El feed es solo en vivo: TransMilenio no publica histórico, así que este archivo es la única copia de esos días.

Los datos son de TransMilenio S.A., que los publica como datos abiertos desde el 4 de noviembre de 2026.

## Qué hay

```text
raw/AAAA/MM/DD/positions_<AAAAMMDDTHHMMSSZ>.pb.gz   posiciones de los vehículos
raw/AAAA/MM/DD/alerts_<AAAAMMDDTHHMMSSZ>.pb.gz      alertas del servicio
archivar_tm.sh                                     script que descarga y guarda
crontab_tm.txt                                     línea de cron que lo ejecuta
fail.log                                           descargas fallidas, una por línea
```

- Cada archivo es un mensaje `FeedMessage` de GTFS-Realtime (protobuf) comprimido con gzip. La hora del nombre es la de descarga, en UTC (Bogotá es UTC−5).
- **Posiciones:** se consultan cada 20 s. Traen `trip_id`, `route_id`, `stop_id`, `current_stop_sequence`, etiqueta y placa del vehículo, posición y hora del reporte. No traen velocidad ni ocupación. En hora punta hay unos 7.000 vehículos por captura.
- **Alertas:** se consultan cada minuto.
- Solo se guarda una captura cuando el archivo cambió desde la anterior. El feed se refresca cada 26 s aproximadamente, así que el máximo es de unas 3.300 capturas de posiciones por día.
- No se archivan los `tripupdates.pb` (7,6 MB por captura) ni el GTFS estático diario (`GTFS.zip`).

## Cómo leerlo

```python
import gzip
from google.transit import gtfs_realtime_pb2  # pip install gtfs-realtime-bindings

feed = gtfs_realtime_pb2.FeedMessage()
feed.ParseFromString(gzip.open("raw/2026/11/21/positions_20261121T130023Z.pb.gz").read())
for e in feed.entity[:3]:
    v = e.vehicle
    print(v.trip.route_id, v.trip.trip_id, v.stop_id, v.position.latitude, v.position.longitude, v.timestamp)
```

## Huecos conocidos

Revisión del 24 de noviembre de 2026, en hora de Bogotá:

| Día | Hueco | Causa |
|---|---|---|
| Todas las noches | 23:59 hasta el inicio del servicio | El feed deja de actualizarse; no hay servicio |
| 13 nov | 05:51, 14 min | Reinicio del servidor que archiva |
| 20 nov | 00:05 a 07:58 | El feed siguió congelado; falta el inicio de la operación y el pico de la mañana |
| 22 nov | 00:09 a 02:21 | Feed congelado, fuera del horario de servicio |
| 23 nov | 00:06 a 08:18 | El feed siguió congelado; falta el inicio de la operación y el pico de la mañana |
| 24 nov | 05:30, 17 min | El feed no se actualizó |
| 24 nov | 06:01 a 07:48 | El feed entregó 0 vehículos y después falló la descarga; el servidor se reinició a las 06:14 |

Los días 20 y 23 no hubo fallas de descarga: el servidor respondía, pero siempre con el mismo archivo. Esos huecos vienen del publicador.
