# Ubicación de los pods en cada configuración

MySQL siempre estuvo en **vm1**, porque el manifiesto `k8s/mysql-catalog.yaml` lo fija con un `nodeSelector`. La tabla muestra en qué nodo quedó cada réplica del backend.

| Configuración | Réplicas | Ubicación del backend | MySQL |
|---|---|---|---|
| Docker Compose | 1 | vm1 (contenedor) | vm1 (contenedor) |
| K8s 1 nodo | 1 | vm1 | vm1 |
| K8s 1 nodo | 2 | vm1, vm1 | vm1 |
| K8s 1 nodo | 3 | vm1, vm1, vm1 | vm1 |
| K8s 2 nodos | 1 | vm2 | vm1 |
| K8s 2 nodos | 2 | vm1, vm2 (una en cada nodo) | vm1 |
| K8s 2 nodos | 3 | vm1, vm2, vm2 (dos réplicas en vm2) | vm1 |
| K8s 3 nodos | 1 | vm2 | vm1 |
| K8s 3 nodos | 2 | vm2, vm3 | vm1 |
| K8s 3 nodos | 3 | vm1, vm2, vm3 (una en cada nodo) | vm1 |
| K8s 1 nodo, referencia (`ref`) | 1 | vm1 (vm2 y vm3 apagadas y marcadas como no programables con `kubectl cordon`) | vm1 |

## Cómo se garantiza el reparto

El despliegue del backend (`k8s/catalog.yaml`) usa una restricción de reparto entre nodos:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: DoNotSchedule
```

La restricción impide que la diferencia de réplicas entre dos nodos sea mayor que 1. Por eso varias ubicaciones quedan determinadas aunque no se hayan anotado:

- **2 nodos, 2 réplicas:** la única opción válida es una réplica en cada nodo.
- **2 nodos, 3 réplicas:** dos en un nodo y una en el otro. La restricción no define cuál nodo recibe dos.
- **3 nodos, 2 réplicas:** las réplicas quedan en dos nodos distintos.
- **3 nodos, 3 réplicas:** una réplica en cada nodo.

Antes de cada configuración se bajó el backend a 0 réplicas y luego se subió al número deseado (función `escalar`), para que el reparto se hiciera desde cero.

## Cómo se reconstruyó la ubicación

Las configuraciones de 1 nodo y la de 2 nodos con 1 réplica se anotaron durante las pruebas. Las demás se reconstruyeron a partir de los registros de containerd de cada nodo, con el comando:

```bash
sudo journalctl -u snap.microk8s.daemon-containerd --since "2026-11-16 18:00" --no-pager -o short-iso \
  | grep "RunPodSandbox for" | grep catalog-backend | grep -v "returns"
```

Cada creación de un pod del backend queda registrada con su hora, y esa hora se comparó con el inicio de cada medición (hora de los archivos de `resultados/`). Las horas de los registros están en UTC; en Colombia son 5 horas menos.

| Hora del escalado (UTC) | Configuración medida a continuación | Pods creados en vm1 | Pods creados en vm2 |
|---|---|---|---|
| 2026-11-16 18:35 | 2 nodos, 2 réplicas | 1 | 1 |
| 2026-11-16 19:08 | 2 nodos, 3 réplicas | 1 | 2 |
| 2026-11-17 03:29 | 3 nodos, 3 réplicas | 1 | 1 |
| 2026-11-17 04:07 | 3 nodos, 2 réplicas | 0 | 1 |
| 2026-11-17 04:40 | 3 nodos, 1 réplica | 0 | 1 |

Los registros de vm3 no se pudieron consultar. Las réplicas asignadas a vm3 se deducen de la regla de reparto: con 3 nodos y 3 réplicas hay una en cada nodo, y con 3 nodos y 2 réplicas las réplicas están en dos nodos distintos. Como en vm1 no se creó ningún pod en ese escalado, la segunda réplica quedó en vm3.

Los pods que aparecen en los registros a las 03:13–03:14 UTC del 17 de noviembre no corresponden a un escalado: son los mismos pods, que se reiniciaron al volver a encender las VMs.

## Tráfico de entrada

JMeter enviaba todas las peticiones al NodePort 30300 de **vm1** (192.168.56.11). Desde ahí, kube-proxy las repartía entre las réplicas de todos los nodos.
