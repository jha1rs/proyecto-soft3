# Ruta de trabajo del proyecto final

Lista de lo que falta, en el orden en que conviene hacerlo. Marquen cada casilla cuando terminen.

Lo que ya está hecho:

- [x] Repositorio recortado: solo el backend del catálogo (Spring Boot) y MySQL
- [x] `db/init.sql` crea la tabla `Book` y genera 10.000 libros
- [x] Endpoints para las pruebas: `GET /api/libros?page=0&size=20` y `GET /api/libro/{isbn}`
- [x] `docker/docker-compose.yml` con MySQL y el backend
- [x] Manifiestos de Kubernetes en `k8s/` con probes, límites de recursos y carga automática de datos

---

## Paso 1. Probar con Docker Compose en la VM

Esto confirma que el backend compila y que los datos se cargan. Desde la raíz del repositorio:

```bash
cd docker
docker compose up -d --build
docker compose ps
```

La primera vez tarda unos minutos porque Maven descarga dependencias. Cuando los dos contenedores salgan `healthy`:

```bash
curl "http://localhost:8081/api/libros?page=0&size=5"
curl http://localhost:8081/api/libro/9790000000001
docker exec mysql-catalog mysql -uroot -ppassword -e "SELECT COUNT(*) FROM \`catalog-library\`.Book"
```

El conteo debe dar 10000. Si algo falla, revisar con `docker compose logs backend-catalog`.

Si se cambia `db/init.sql`, hay que borrar el volumen para que se vuelva a ejecutar:

```bash
docker compose down -v
docker compose up -d --build
```

- [ ] Compose levanta sin errores
- [ ] Los dos endpoints responden
- [ ] La tabla tiene 10000 registros

## Paso 2. Publicar la imagen en Docker Hub

Kubernetes no construye imágenes, las descarga de un registro. Cada nodo del clúster tiene que poder bajar la imagen, por eso se sube a Docker Hub. La imagen del profesor (`chaphe/backend-catalog-image:1.0`) no sirve porque no tiene los endpoints nuevos y los probes nunca pasarían.

1. Crear una cuenta en https://hub.docker.com (con una para todo el grupo basta). En este ejemplo el usuario es `usuario123`, cámbienlo por el real.
2. Construir y subir la imagen:

   ```bash
   cd app/backend-catalog
   docker login
   docker build -t usuario123/backend-catalog:1.0 .
   docker push usuario123/backend-catalog:1.0
   ```

3. En `k8s/catalog.yaml` cambiar la línea de la imagen:

   ```yaml
   image: usuario123/backend-catalog:1.0
   ```

4. Hacer commit y push del cambio.

Si después modifican el backend, suban una etiqueta nueva (`1.1`, `1.2`...) y actualicen esa línea. No reutilicen `1.0`, porque los nodos pueden quedarse con la versión que ya habían descargado.

- [ ] Imagen publicada en Docker Hub
- [ ] `k8s/catalog.yaml` apunta a la imagen propia

## Paso 3. Preparar las máquinas

Se necesitan cuatro máquinas en total:

| Máquina | Uso |
|---|---|
| VM 1 | Nodo principal del clúster (y la máquina de Docker Compose) |
| VM 2 | Segundo nodo |
| VM 3 | Tercer nodo |
| Otra máquina | JMeter. El enunciado pide que no sea la misma donde corre la aplicación |

Conviene que las tres VM del clúster tengan la misma CPU y RAM, si no la comparación entre 1, 2 y 3 nodos queda sesgada. Anoten las especificaciones de cada una porque van en el notebook.

- [ ] Cuatro máquinas disponibles y con red entre ellas
- [ ] Especificaciones anotadas (CPU, RAM, sistema operativo)

## Paso 4. Kubernetes con un nodo

Ejemplo con MicroK8s en la VM 1:

```bash
sudo snap install microk8s --classic
sudo usermod -aG microk8s $USER   # cerrar sesión y volver a entrar
microk8s status --wait-ready
alias kubectl='microk8s kubectl'
```

Detener Docker Compose antes, para que no compitan por recursos:

```bash
cd docker && docker compose down
```

Desplegar:

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/
kubectl get pods -n library-ns -w
```

Esperar a que los pods queden `1/1 Running`. MySQL tarda un poco más porque genera los 10K libros al arrancar. Probar desde la máquina de JMeter (el servicio es NodePort en el puerto 30300):

```bash
curl "http://IP_DE_LA_VM1:30300/api/libros?page=0&size=5"
```

Para cambiar el número de réplicas del backend:

```bash
kubectl scale deployment catalog-backend-deployment -n library-ns --replicas=2
kubectl get pods -n library-ns -o wide
```

MySQL se queda siempre en 1 réplica.

- [ ] Clúster de un nodo funcionando
- [ ] Endpoints responden por el NodePort

## Paso 5. Kubernetes con dos y tres nodos

En la VM 1 generar el comando de unión:

```bash
microk8s add-node
```

Copiar el comando `microk8s join ... --worker` que imprime y ejecutarlo en la VM 2 (con MicroK8s instalado). Repetir `add-node` para la VM 3 cuando toque la prueba de tres nodos.

```bash
kubectl get nodes
```

Con varias réplicas, revisar con `kubectl get pods -n library-ns -o wide` en qué nodo quedó cada una y anotarlo. Kubernetes no siempre las reparte de forma pareja y eso afecta los resultados.

- [ ] Clúster de dos nodos funcionando
- [ ] Clúster de tres nodos funcionando
- [ ] Anotado en qué nodo queda cada réplica

## Paso 6. Plan de pruebas con JMeter

Crear el plan en la carpeta `jmeter/` (por ejemplo `jmeter/plan-catalogo.jmx`) con:

- Variables `HOST` y `PORT` para no editar el plan en cada escenario
- Dos peticiones:
  - `GET /api/libros?page=${__Random(0,499)}&size=20`
  - `GET /api/libro/${__groovy("979" + String.format("%010d"\\, new Random().nextInt(10000) + 1))}` (arma un ISBN aleatorio entre 9790000000001 y 9790000010000)
- Varios niveles de carga, por ejemplo 10, 50, 100 y 200 usuarios concurrentes
- Un periodo de subida (ramp-up) y una duración fija por prueba, por ejemplo 2 minutos
- Guardar resultados en CSV

Correrlo siempre en modo consola, no con la interfaz gráfica:

```bash
jmeter -n -t jmeter/plan-catalogo.jmx -JHOST=IP -JPORT=30300 -JUSERS=50 -l resultados/k8s-1nodo-2rep-50u.csv
```

- [ ] Plan `.jmx` creado y subido al repositorio
- [ ] Probado contra Docker Compose

## Paso 7. Ejecutar las pruebas

Matriz de escenarios. Cada escenario se corre con todos los niveles de carga:

| Escenario | Réplicas del backend |
|---|---|
| Docker Compose | 1 |
| K8s 1 nodo | 1, 2, 3 |
| K8s 2 nodos | 1, 2, 3 |
| K8s 3 nodos | 1, 2, 3 |

Son 10 configuraciones por 4 niveles de carga, 40 corridas.

Para que los resultados sean comparables:

- Nombrar los CSV de forma ordenada, por ejemplo `k8s-2nodos-3rep-100u.csv`, y guardarlos en `resultados/`
- Esperar a que todos los pods estén listos antes de cada corrida
- Hacer una corrida corta de calentamiento antes de medir (Spring es lento en las primeras peticiones)
- Repetir cada prueba al menos 2 o 3 veces si da el tiempo, y promediar
- No usar las máquinas para otra cosa mientras corren las pruebas

- [ ] Corridas de Docker Compose
- [ ] Corridas de 1 nodo
- [ ] Corridas de 2 nodos
- [ ] Corridas de 3 nodos
- [ ] CSV subidos al repositorio

## Paso 8. Monitorización (opcional)

Si quieren el punto opcional, instalar Prometheus y Grafana con Helm (`kube-prometheus-stack`) y tomar capturas o exportar el consumo de CPU y memoria de los pods durante cada corrida. En Docker Compose se puede usar `docker stats`.

- [ ] Métricas de CPU y memoria por escenario

## Paso 9. Notebook de análisis

Crear `notebook/analisis.ipynb` (en Colab o Jupyter) con estas secciones, que son las que pide el enunciado:

1. Introducción y objetivos
2. Descripción de la aplicación (backend del catálogo, MySQL, 10K libros, endpoints usados)
3. Configuración de cada escenario, con fragmentos de `docker-compose.yml` y de los YAML de `k8s/`
4. Monitorización, si se hizo
5. Metodología de JMeter: plan, niveles de carga, duración, repeticiones, máquinas usadas
6. Resultados: cargar los CSV con Pandas y calcular tiempo medio de respuesta y throughput por escenario
7. Gráficos con Matplotlib o Seaborn:
   - Tiempo medio de respuesta contra usuarios, una línea por número de réplicas
   - Throughput contra usuarios, igual
   - Comparación entre 1, 2 y 3 nodos con el mismo número de réplicas
   - Docker Compose frente a Kubernetes
8. Análisis comparativo: tendencias, cuellos de botella (es probable que MySQL lo sea, porque no se escala), diferencias entre nodos
9. Conclusiones
10. Recomendaciones

- [ ] Notebook con todas las secciones
- [ ] Gráficos generados dentro del notebook

## Paso 10. Entrega

El repositorio debe tener:

- [ ] Código fuente con el `Dockerfile` (`app/backend-catalog/`)
- [ ] `docker/docker-compose.yml` y los YAML de `k8s/`
- [ ] Plan de JMeter y resultados
- [ ] Notebook `.ipynb`
- [ ] PDF con instrucciones para ejecutar el proyecto, abrir el notebook y los enlaces necesarios (repositorio, Colab, Docker Hub)
- [ ] README actualizado
