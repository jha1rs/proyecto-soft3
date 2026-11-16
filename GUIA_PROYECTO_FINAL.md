# Guía paso a paso del proyecto final (VirtualBox + Vagrant)

**Análisis del comportamiento de aplicaciones bajo diferentes escenarios de despliegue**
Curso: Principios y prácticas de Desarrollo de Software Orientado a Objetos

Esta guía se basa en la descripción del proyecto (`Descripcion_Proyecto_Final.pdf`) y en el repositorio del grupo [`proyecto-soft3`](https://github.com/jha1rs/proyecto-soft3) (`RUTA.md`). Todo corre en **un solo PC**, con **4 máquinas virtuales** creadas con **VirtualBox y Vagrant**:

- 3 nodos de Kubernetes: `vm1`, `vm2` y `vm3`.
- 1 VM para JMeter: `jmeter`.

Va acompañada del archivo **`Vagrantfile`**, que crea y configura las VMs.

> **Qué está verificado y qué no:**
> - El `Vagrantfile` pasó la revisión de sintaxis de Ruby, y los scripts que genera pasaron la de `bash`.
> - El `docker-compose.yml` y los YAML de Kubernetes pasaron validadores (estos últimos contra el esquema de Kubernetes v1.31, en modo estricto).
> - El código del notebook y el script de JMeter se probaron con datos simulados.
> - **No** se ejecutaron VirtualBox, Vagrant ni el backend durante la preparación. La primera prueba real es el *Paso 3.4*.

---

## Contenido

0. [Qué hay que hacer y qué se entrega](#0-qué-hay-que-hacer-y-qué-se-entrega)
1. [Plan: 4 VMs en un PC](#1-plan-4-vms-en-un-pc)
2. [Matriz de experimentos y nombres de archivos](#2-matriz-de-experimentos-y-nombres-de-archivos)
3. [Paso 1. Organizar el repositorio](#paso-1-organizar-el-repositorio)
4. [Paso 2. Corregir los archivos antes de medir](#paso-2-corregir-los-archivos-antes-de-medir)
5. [Paso 3. Preparar el PC y crear las VMs con Vagrant](#paso-3-preparar-el-pc-y-crear-las-vms-con-vagrant)
6. [Paso 4. vm1: Docker Compose y la imagen en Docker Hub](#paso-4-vm1-docker-compose-y-la-imagen-en-docker-hub)
7. [Paso 5. JMeter: plan de pruebas y script](#paso-5-jmeter-plan-de-pruebas-y-script)
8. [Paso 6. Protocolo de cada medición](#paso-6-protocolo-de-cada-medición)
9. [Paso 7. Fase 1: Docker Compose](#paso-7-fase-1-docker-compose)
10. [Paso 8. Fase 2: Kubernetes con 1 nodo](#paso-8-fase-2-kubernetes-con-1-nodo)
11. [Paso 9. Fase 3: Kubernetes con 2 nodos](#paso-9-fase-3-kubernetes-con-2-nodos)
12. [Paso 10. Fase 4: Kubernetes con 3 nodos](#paso-10-fase-4-kubernetes-con-3-nodos)
13. [Paso 11. Monitoreo de CPU y memoria (opcional)](#paso-11-monitoreo-de-cpu-y-memoria-opcional)
14. [Paso 12. Notebook de análisis](#paso-12-notebook-de-análisis)
15. [Paso 13. Reporte PDF y README](#paso-13-reporte-pdf-y-readme)
16. [Paso 14. Lista de verificación de la entrega](#paso-14-lista-de-verificación-de-la-entrega)
17. [Problemas frecuentes](#problemas-frecuentes)
18. [Tiempos y reparto del trabajo](#tiempos-y-reparto-del-trabajo)

---

## 0. Qué hay que hacer y qué se entrega

**Objetivo (según el PDF):** desplegar la misma aplicación en varios escenarios, generarle carga con JMeter y analizar cómo cambian el **tiempo medio de respuesta** y el **throughput** según el número de **réplicas** y de **nodos**.

| Fase del PDF | Escenario | Réplicas del backend |
|---|---|---|
| Fase 1 | Docker Compose en una máquina (distinta a la de JMeter) | 1 |
| Fase 2 | Kubernetes, 1 nodo | 1, 2, 3 |
| Fase 3 | Kubernetes, 2 nodos | 1, 2, 3 |
| Fase "3" (tres nodos) | Kubernetes, 3 nodos | 1, 2, 3 |
| Fase 5 | Análisis y documentación en un notebook de Jupyter (Colab) | — |

> El PDF numera dos fases como "Fase 3". Los objetivos específicos piden 1, 2 y 3 nodos, y los criterios de evaluación ponen énfasis especial en la diferencia **entre 1 y 2 nodos**.

**Requisitos de la aplicación:** backend con lógica de servidor, API REST, persistencia y mínimo 10.000 registros. El repo `proyecto-soft3` ya los cumple:

- Solo conserva el backend del catálogo (Spring Boot) y MySQL, tomados del `bookstore-app` del profesor.
- `db/init.sql` genera **10.000 libros** (ISBN `9790000000001` a `9790000010000`).
- Expone los endpoints de prueba `GET /api/libros?page=&size=` (paginado) y `GET /api/libro/{isbn}`.
- Ya trae `docker/docker-compose.yml` y los manifiestos `k8s/`.

**Entregables (sección 7 del PDF):**
1. Repositorio con el código fuente, el `Dockerfile`, el `docker-compose.yml` y los YAML de Kubernetes.
2. Notebook `.ipynb` con: introducción y objetivos, descripción de la aplicación, configuración de cada escenario, metodología de JMeter, métricas con gráficos, análisis comparativo, conclusiones y recomendaciones (más el monitoreo, si se hace).
3. Reporte en PDF con instrucciones para ejecutar el proyecto, ver el notebook y los enlaces necesarios.

---

## 1. Plan: 4 VMs en un PC

| VM | IP privada | Recursos (por defecto) | Uso |
|---|---|---|---|
| `vm1` | 192.168.56.11 | 2 vCPU, 4 GB | Docker Compose (Fase 1); después, nodo principal de Kubernetes |
| `vm2` | 192.168.56.12 | 2 vCPU, 4 GB | Segundo nodo (Fase 3) |
| `vm3` | 192.168.56.13 | 2 vCPU, 4 GB | Tercer nodo (Fase 4) |
| `jmeter` | 192.168.56.20 | 2 vCPU, 2 GB | Genera la carga en **todas** las fases |

**VMs encendidas en cada fase:**

| Fase | vm1 | vm2 | vm3 | jmeter |
|---|---|---|---|---|
| 1. Docker Compose | Compose | — | — | ✔ |
| 2. K8s 1 nodo | Nodo | — | — | ✔ |
| 3. K8s 2 nodos | Nodo | Nodo | — | ✔ |
| 4. K8s 3 nodos | Nodo | Nodo | Nodo | ✔ |

(— = apagada o todavía sin crear)

**Ventajas de este plan:**
- JMeter siempre mide desde la misma VM, así que **todas las configuraciones son comparables entre sí**.
- La máquina de Compose (vm1) es distinta a la de JMeter, como pide el PDF.
- El repositorio se comparte automáticamente con todas las VMs en `/vagrant`. Los resultados que escribe JMeter aparecen directamente en la carpeta del repo en el PC.

**Limitación (hay que explicarla en el notebook):** todas las VMs comparten la CPU y la RAM del mismo PC. Agregar un nodo solo aporta capacidad real si el PC tiene núcleos libres para esa VM. Por eso el PC debe tener suficientes núcleos (Paso 3.1).

---

## 2. Matriz de experimentos y nombres de archivos

**Configuraciones (10 en total):** Compose ×1, K8s 1 nodo ×3 réplicas, K8s 2 nodos ×3 réplicas y K8s 3 nodos ×3 réplicas.

**Parámetros de carga (iguales en todas las configuraciones):**

- Cargas: **10, 50, 100 y 200** usuarios concurrentes.
- Ramp-up: **30 s**. Duración total: **150 s** (se analizan solo los 120 s posteriores al ramp-up).
- Pausa de **60 s** entre corridas y un calentamiento de 60 s antes de cada configuración (no se guarda).
- Repeticiones: **2 como mínimo**, 3 si hay tiempo.

**Nombre de cada archivo de resultados** (el notebook depende de este formato):

```
resultados/<escenario>_<réplicas>rep_<usuarios>u_r<repetición>_vm.csv

escenario: compose | k8s1n | k8s2n | k8s3n

Ejemplos: compose_1rep_50u_r1_vm.csv   k8s2n_3rep_200u_r2_vm.csv
```

El script `jmeter/correr.sh` (Paso 5) genera estos nombres automáticamente.

**Volumen y duración:**
- Con 2 repeticiones son 10 configuraciones × 4 cargas × 2 = **80 archivos**.
- Cada configuración tarda ≈ 30 min con 2 repeticiones (≈ 45 min con 3).
- En total son ≈ **5 h** de medición, repartidas en varias sesiones.

---

## Paso 1. Organizar el repositorio

- [ ] El dueño del repo (`jha1rs/proyecto-soft3`) agrega a todos como **colaboradores** (*Settings → Collaborators*). Si prefieren, pueden trabajar en su copia local y subir todo al final.
- [ ] **En Windows, antes de clonar**, ejecutar `git config --global core.autocrlf input`. Si no, Git convierte los finales de línea a formato Windows y los scripts `.sh` fallan dentro de las VMs.
- [ ] Clonar el repo en el PC y crear esta estructura:

```
proyecto-soft3/
├── Vagrantfile              NUEVO: el archivo que acompaña esta guía (en la RAÍZ)
├── .gitattributes           NUEVO: contiene la línea  *.sh text eol=lf
├── app/backend-catalog/     (ya existe: código + Dockerfile)
├── db/init.sql              (ya existe)
├── docker/docker-compose.yml(ya existe)
├── k8s/                     (ya existe)
├── jmeter/                  NUEVO: plan-catalogo.jmx y correr.sh
├── resultados/              NUEVO: CSV de JMeter (+ logs/)
├── monitoreo/               NUEVO (opcional): salidas de kubectl top / docker stats
├── notebook/                NUEVO: analisis.ipynb
└── docs/                    NUEVO: reporte PDF, especificaciones, ubicación de pods
```

- [ ] Agregar `.vagrant/` al `.gitignore`. Esa carpeta la crea Vagrant y no debe subirse.

---

## Paso 2. Corregir los archivos antes de medir

El repo funciona, pero tiene detalles que **sesgan las mediciones**. Hay que corregirlos antes de construir la imagen y medir.

| Problema | Efecto | Corrección |
|---|---|---|
| En Kubernetes cada pod del backend tiene límite de 0.5 CPU y MySQL de 1 CPU; en Compose no hay límites | Compose saldría mucho mejor por la configuración, no por la plataforma | Mismos límites en Compose |
| MySQL `8.0` en Compose y `8.0.27` en Kubernetes | Versiones distintas entre escenarios | Usar `8.0.27` en ambos |
| El healthcheck de Compose y del Dockerfile llama a `/api/getlibros` (devuelve los 10.000 libros) cada 30 s | Carga extra solo en el escenario de Compose | Usar `/api/libros?size=1` |
| Los probes de Kubernetes usan el timeout por defecto (1 s) | Bajo carga alta el pod sale del Service o se reinicia en plena prueba | `timeoutSeconds: 5` y un liveness más tolerante |
| MySQL puede quedar en cualquier nodo | La base cambia de nodo entre escenarios | `nodeSelector` para fijarla en vm1 |
| Las réplicas pueden quedar todas en el mismo nodo | La comparación entre nodos pierde sentido | `topologySpreadConstraints` |

### 2.1 `docker/docker-compose.yml` (reemplazar completo)

```yaml
services:
  mysql-catalog:
    image: mysql:8.0.27            # misma version que en k8s/mysql-catalog.yaml
    container_name: mysql-catalog
    environment:
      MYSQL_DATABASE: catalog-library
      MYSQL_ROOT_PASSWORD: password
      MYSQL_USER: catalog
      MYSQL_PASSWORD: catalog
    ports:
      - "3306:3306"
    volumes:
      - mysql-catalog-data:/var/lib/mysql
      # Todo .sql de db/ se ejecuta la primera vez que se crea el volumen
      # (db/init.sql: crea la tabla y genera los 10K libros)
      - ../db:/docker-entrypoint-initdb.d:ro
    networks:
      - bookstore-network
    # Mismos limites que el pod de MySQL en Kubernetes (limits: cpu 1, memory 1Gi)
    cpus: "1"
    mem_limit: 1g
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-ppassword"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    command: --default-authentication-plugin=mysql_native_password

  backend-catalog:
    build:
      context: ../app/backend-catalog
      dockerfile: Dockerfile
    container_name: backend-catalog
    environment:
      MYSQL_DB_HOST: mysql-catalog
      MYSQL_DB_PORT: 3306
      MYSQL_DB_USERNAME: root
      MYSQL_DB_PASSWORD: password
    ports:
      - "8081:8081"
    networks:
      - bookstore-network
    # Mismos limites que cada pod del backend en Kubernetes (cpu 500m, memory 768Mi)
    cpus: "0.5"
    mem_limit: 768m
    depends_on:
      mysql-catalog:
        condition: service_healthy
    healthcheck:
      # Endpoint liviano: /api/getlibros devolveria los 10.000 libros en cada chequeo
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8081/api/libros?size=1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

volumes:
  mysql-catalog-data:

networks:
  bookstore-network:
    driver: bridge
```

### 2.2 `app/backend-catalog/Dockerfile` (cambiar solo el HEALTHCHECK)

```dockerfile
# Health check: endpoint GET /api/libros?size=1
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -q --spider "http://localhost:8081/api/libros?size=1" || exit 1
```

### 2.3 `k8s/catalog.yaml` (reemplazar completo)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-backend-deployment
  namespace: library-ns
  labels:
    app: catalog-backend
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog-backend
  template:
    metadata:
      labels:
        app: catalog-backend
    spec:
      # Reparte las replicas entre nodos (como maximo 1 de diferencia entre nodos)
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: catalog-backend
      containers:
      - name: catalog-backend
        image: USUARIO_DOCKERHUB/backend-catalog:1.0   # cambiar por la imagen propia (Paso 4.3)
        ports:
        - containerPort: 8081
        env:
        - name: MYSQL_DB_HOST
          value: mysql-catalog-service
        - name: MYSQL_DB_PORT
          value: "3306"
        - name: MYSQL_DB_USERNAME
          value: root
        - name: MYSQL_DB_PASSWORD
          value: password
        resources:
          requests:
            cpu: "250m"
            memory: "384Mi"
          limits:
            cpu: "500m"
            memory: "768Mi"
        # No recibe trafico hasta que Spring arranco y responde con datos.
        # timeoutSeconds alto para que bajo carga el pod no salga del Service.
        readinessProbe:
          httpGet:
            path: /api/libros?size=1
            port: 8081
          initialDelaySeconds: 20
          periodSeconds: 5
          timeoutSeconds: 5
          failureThreshold: 6
        # Tolerante bajo carga para que el pod no se reinicie en plena prueba
        livenessProbe:
          httpGet:
            path: /api/libros?size=1
            port: 8081
          initialDelaySeconds: 90
          periodSeconds: 15
          timeoutSeconds: 5
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-backend-service
  namespace: library-ns
spec:
  type: NodePort
  selector:
    app: catalog-backend
  ports:
    - protocol: TCP
      port: 8081
      targetPort: 8081
      nodePort: 30300
```

### 2.4 `k8s/mysql-catalog.yaml` (reemplazar completo)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-catalog-deployment
  namespace: library-ns
  labels:
    app: mysql-catalog
spec:
  replicas: 1   # La base NO se escala; solo se escala el backend
  selector:
    matchLabels:
      app: mysql-catalog
  template:
    metadata:
      labels:
        app: mysql-catalog
    spec:
      # MySQL siempre en vm1, para que la base no cambie de nodo entre escenarios.
      # Verificar el nombre real con: kubectl get nodes
      nodeSelector:
        kubernetes.io/hostname: vm1
      containers:
      - name: mysql
        image: mysql:8.0.27
        ports:
        - containerPort: 3306
        env:
          - name: MYSQL_ROOT_PASSWORD
            value: password
          - name: MYSQL_DATABASE
            value: catalog-library
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1"
            memory: "1Gi"
        readinessProbe:
          exec:
            command: ["mysql", "-uroot", "-ppassword", "-e", "SELECT COUNT(*) FROM `catalog-library`.Book"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        volumeMounts:
          - name: init-scripts
            mountPath: /docker-entrypoint-initdb.d
            readOnly: true
          - name: mysql-data
            mountPath: /var/lib/mysql
      volumes:
        - name: init-scripts
          configMap:
            name: mysql-catalog-init
        # Datos efimeros a proposito: si el pod se reinicia, MySQL arranca vacio y
        # vuelve a ejecutar los scripts, asi los 10K libros siempre quedan cargados.
        - name: mysql-data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-catalog-service
  namespace: library-ns
spec:
  type: ClusterIP
  selector:
    app: mysql-catalog
  ports:
    - protocol: TCP
      port: 3306
      targetPort: 3306
```

`k8s/00-namespace.yaml` y `k8s/mysql-catalog-init.yaml` no cambian.

- [ ] Aplicar los 4 cambios en la copia del repo en el PC. Las VMs los ven en `/vagrant`.

---

## Paso 3. Preparar el PC y crear las VMs con Vagrant

### 3.1 Requisitos del PC

Para ver cuántos núcleos tiene el PC en Windows: *Administrador de tareas → Rendimiento → CPU* ("Núcleos" y "Procesadores lógicos").

| PC | Qué hacer |
|---|---|
| **8 núcleos físicos o más y 24 GB de RAM o más** | Usar el `Vagrantfile` tal cual. En la Fase 4 las VMs suman 8 vCPU y 14 GB. |
| **6 núcleos y 16 GB** | En el `Vagrantfile`, cambiar `NODO_RAM = 3072` y `JMETER_RAM = 1536`. En la Fase 4 habrá más vCPU que núcleos: hay que explicarlo como limitación. |
| **4 núcleos o menos de 16 GB** | No alcanza para 3 nodos de forma confiable. Conviene usar otra opción (Google Cloud, o varios PCs). |

**Además:**
- La virtualización (VT-x / AMD-V) debe estar **activada en la BIOS**.
- El PC debe tener **x86/amd64**. Los Mac con chip M1/M2/M3 no sirven para este `Vagrantfile`.
- Hace falta espacio en disco: unos 30–40 GB libres.

### 3.2 Instalar el software (en el PC)

1. **VirtualBox:** <https://www.virtualbox.org/wiki/Downloads>.
2. **Vagrant:** <https://developer.hashicorp.com/vagrant/install>. Si Vagrant no reconoce la versión de VirtualBox, actualicen Vagrant.
3. **Git**. En Windows, Git for Windows trae también **Git Bash**.
4. **En Windows:** si tienen activos **WSL2, Docker Desktop o Hyper-V**, VirtualBox puede ir muy lento (aparece una tortuga verde en la ventana de la VM). Para desactivarlos:
   - En *Activar o desactivar características de Windows*, desmarcar **Hyper-V**, **Plataforma de máquina virtual** y **Plataforma del hipervisor de Windows**.
   - En *Seguridad de Windows → Seguridad del dispositivo → Aislamiento del núcleo*, desactivar **Integridad de memoria**.
   - Reiniciar el PC.
   - Ojo: esto deja sin funcionar WSL2 y Docker Desktop mientras esté desactivado.

### 3.3 Qué hace el `Vagrantfile`

- Crea las 4 VMs con **Ubuntu 24.04** (caja `bento/ubuntu-24.04`), con nombre, IP privada fija y CPU/RAM definidas al inicio del archivo.
- Comparte la carpeta del repo con todas las VMs en `/vagrant`.
- **vm1:** instala Docker. MicroK8s **no** se instala al principio, para que no consuma CPU durante la fase de Compose. Se instala a mano en el Paso 8.
- **vm2 y vm3:** instalan MicroK8s al crearse.
- **Configuración de red:** cada VM de VirtualBox trae una tarjeta NAT con la misma IP (`10.0.2.15`) en todas. Si Kubernetes usara esa tarjeta, los nodos no podrían comunicarse. Por eso el archivo configura a MicroK8s para usar la IP privada `192.168.56.x`, en tres lugares: kubelet, kube-apiserver y Calico.
- **jmeter:** instala Java 17 y JMeter 5.6.3.
- Define la función `escalar N` en los nodos (se usa desde vm1).
- **Ninguna VM arranca con `vagrant up` a secas.** Siempre hay que decir cuáles.

### 3.4 Crear las VMs de la Fase 1

En una terminal (PowerShell, Git Bash o la terminal de Linux), dentro de la carpeta del repo:

```bash
vagrant up vm1 jmeter        # la primera vez descarga la caja (~1 GB) y tarda varios minutos
vagrant status               # vm1 y jmeter en "running"
```

Si algo falla durante la instalación, se puede repetir solo esa parte con `vagrant provision vm1` (o `jmeter`).

### 3.5 Comandos del día a día

```bash
vagrant ssh vm1              # entrar a una VM (igual con vm2, vm3, jmeter)
vagrant up vm1 jmeter        # encender las que se van a usar
vagrant halt                 # apagar TODAS al terminar
vagrant status               # ver el estado
```

- Las IPs privadas son fijas, así que el clúster sigue funcionando después de apagar y encender.
- Dentro de cada VM, el repositorio está en **`/vagrant`**.

### 3.6 Registrar las especificaciones (van en el notebook)

- [ ] En `docs/maquinas.md`, anotar:
  - **Del PC:** modelo de CPU, núcleos e hilos, RAM, sistema operativo, versiones de VirtualBox y de Vagrant.
  - **De las VMs:** los valores `NODO_CPUS`, `NODO_RAM`, `JMETER_CPUS` y `JMETER_RAM` del `Vagrantfile`, y la versión de MicroK8s.
  - **Dentro de una VM:** la salida de `nproc; free -h; lsb_release -d`.

---

## Paso 4. vm1: Docker Compose y la imagen en Docker Hub

### 4.1 Levantar la aplicación

```bash
vagrant ssh vm1
cd /vagrant/docker
docker compose up -d --build           # la primera vez tarda varios minutos (Maven)
docker compose ps                      # esperar a que ambos queden "healthy"
```

### 4.2 Verificar

```bash
curl "http://localhost:8081/api/libros?page=0&size=5"         # lista de 5 libros
curl http://localhost:8081/api/libro/9790000000001             # un libro
curl -i http://localhost:8081/api/libro/123 | head -1          # debe dar 404
docker exec mysql-catalog mysql -uroot -ppassword \
  -e "SELECT COUNT(*) FROM \`catalog-library\`.Book"           # debe dar 10000
docker inspect backend-catalog --format 'CPU={{.HostConfig.NanoCpus}} MEM={{.HostConfig.Memory}}'
# esperado: CPU=500000000 MEM=805306368  (0.5 CPU y 768 MiB)
```

- Si algo falla: `docker compose logs backend-catalog`.
- Si cambian `db/init.sql`, el script solo se vuelve a ejecutar si se borra el volumen: `docker compose down -v` y luego `docker compose up -d --build`.

- [ ] Compose levanta sin errores
- [ ] Los dos endpoints responden
- [ ] La tabla tiene 10000 registros
- [ ] Los límites de CPU y memoria están aplicados

### 4.3 Publicar la imagen en Docker Hub

Kubernetes no construye imágenes: cada nodo descarga la imagen de un registro. La imagen del profesor (`chaphe/backend-catalog-image:1.0`) **no sirve**, porque no tiene los endpoints nuevos.

1. Crear una cuenta en <https://hub.docker.com> (basta una para el grupo). Crear un *access token* en *Account settings → Personal access tokens*.
2. En vm1:

   ```bash
   cd /vagrant/app/backend-catalog
   docker login -u USUARIO_DOCKERHUB              # como contraseña, pegar el access token
   docker build -t USUARIO_DOCKERHUB/backend-catalog:1.0 .
   docker push USUARIO_DOCKERHUB/backend-catalog:1.0
   ```

3. Detalles a tener en cuenta:
   - El repositorio de Docker Hub debe ser **público**, para que los nodos lo descarguen sin credenciales.
   - Si después cambian el backend, publiquen una etiqueta nueva (`1.1`, `1.2`...). No reutilicen `1.0`, porque los nodos pueden quedarse con la versión que ya descargaron.
4. En el PC, cambiar la línea `image:` de `k8s/catalog.yaml` por `USUARIO_DOCKERHUB/backend-catalog:1.0`. Como el repo está compartido, las VMs ven el cambio de inmediato.

- [ ] Imagen publicada
- [ ] `k8s/catalog.yaml` apunta a la imagen propia

**Dejen Compose corriendo:** se usa en el Paso 5.4 y en la Fase 1.

---

## Paso 5. JMeter: plan de pruebas y script

La VM `jmeter` ya trae JMeter 5.6.3 instalado. El plan de pruebas se crea en la **interfaz gráfica de JMeter en el PC** y se guarda en el repo.

### 5.1 Instalar JMeter en el PC (solo para crear el plan)

1. Instalar Java 17 (por ejemplo Temurin, de <https://adoptium.net>).
2. Descargar `apache-jmeter-5.6.3.zip` desde <https://archive.apache.org/dist/jmeter/binaries/> y descomprimir.
3. Abrir la interfaz gráfica: `bin/jmeter.bat` (Windows) o `bin/jmeter` (Linux).

### 5.2 Crear el plan en la interfaz gráfica

La interfaz gráfica solo se usa para **crear** el plan. Las pruebas se corren siempre en modo consola, desde la VM `jmeter`.

1. **Test Plan** → *Name*: `Plan catalogo`.
2. Clic derecho en Test Plan → *Add → Config Element → HTTP Request Defaults*:
   - *Protocol*: `http`
   - *Server Name or IP*: `${__P(HOST,localhost)}`
   - *Port Number*: `${__P(PORT,8081)}`
   - Pestaña *Advanced* → *Timeouts*: Connect `5000`, Response `30000` (ms).
3. Clic derecho en Test Plan → *Add → Threads (Users) → Thread Group*:
   - *Name*: `Usuarios`
   - *Action to be taken after a Sampler error*: `Continue`
   - *Number of Threads (users)*: `${__P(USERS,10)}`
   - *Ramp-up period (seconds)*: `${__P(RAMPUP,30)}`
   - *Loop Count*: marcar **Infinite**
   - Marcar **Specify Thread lifetime** → *Duration (seconds)*: `${__P(DURATION,150)}`
4. Clic derecho en `Usuarios` → *Add → Sampler → HTTP Request*:
   - *Name*: `GET libros paginados`
   - *Method*: `GET` · *Path*: `/api/libros`
   - *Parameters* → *Add*: `page` = `${__Random(0,499)}` y `size` = `20`
   - Dejar *Server* y *Port* vacíos (se toman de los Defaults).
5. Otro *HTTP Request*:
   - *Name*: `GET libro por ISBN`
   - *Method*: `GET` · *Path*: `/api/libro/${__groovy(9790000000000L + new Random().nextInt(10000) + 1)}`
   - Esto arma un ISBN aleatorio entre 9790000000001 y 9790000010000, sin comas que haya que escapar.
6. **No agregar listeners** (View Results Tree, Summary Report, etc.). Los resultados se guardan con `-l` en consola, y los listeners consumen recursos durante la prueba. Si agregaron alguno para probar, bórrenlo antes de guardar.
7. Guardar como `jmeter/plan-catalogo.jmx` dentro del repo.

> **Importante:** `-JHOST=...` en la línea de comandos define una **propiedad** de JMeter. En el plan se lee con `${__P(HOST,valor_por_defecto)}`. Si se escribe `${HOST}`, la propiedad se ignora.

**Opcional: incluir escrituras.** El PDF menciona lectura y escritura, y por ahora el plan solo tiene lecturas. Para agregar escrituras:

1. Clic derecho en `Usuarios` → *Add → Logic Controller → Throughput Controller*, con *Percent Executions* = `10`.
2. Dentro, un *HTTP Request* con *Method* `PUT`, *Path* `/api/libro` y en *Body Data*:

   ```json
   {"isbn":"${__groovy(9790000000000L + new Random().nextInt(10000) + 1)}","titulo":"Libro de prueba","autor":"Autor de prueba","descripcion":"Actualizado por JMeter","valor":"10","unidades":${__Random(0,100)}}
   ```

3. Agregar un *HTTP Header Manager* (*Add → Config Element*) dentro del request, con `Content-Type: application/json`.

Si lo agregan, debe estar en **todas** las configuraciones. Las escrituras cambian el contenido de algunos libros, pero no la cantidad, así que no afectan las lecturas. Para volver a los datos originales:
- Compose: `docker compose down -v` y luego `docker compose up -d`.
- Kubernetes: `kubectl delete pod -l app=mysql-catalog -n library-ns`. El pod nuevo arranca vacío y regenera los 10.000 libros.

### 5.3 Script de medición `jmeter/correr.sh`

Crear el archivo con este contenido. Corre el calentamiento y todas las cargas y repeticiones de **una** configuración, y nombra los CSV automáticamente.

```bash
#!/usr/bin/env bash
# Corre todas las cargas de UNA configuracion (escenario + replicas).
# Uso:     bash jmeter/correr.sh <escenario> <replicas> <origen> <host> <puerto>
# Ejemplo: bash jmeter/correr.sh k8s1n 2 vm 192.168.56.11 30300
#   escenario: compose | k8s1n | k8s2n | k8s3n
#   origen:    vm (en este montaje siempre "vm": JMeter corre en su propia VM)
set -euo pipefail

ESC=$1; REP=$2; ORIGEN=$3; HOST=$4; PORT=$5
JMETER=${JMETER:-jmeter}
PLAN=jmeter/plan-catalogo.jmx
CARGAS="10 50 100 200"            # usuarios concurrentes
REPETICIONES=${REPETICIONES:-2}   # subir a 3 si hay tiempo
RAMPUP=30                         # segundos de subida (se descartan en el analisis)
DURACION=150                      # segundos totales: 30 de subida + 120 medidos
PAUSA=60                          # segundos de descanso entre corridas

mkdir -p resultados/logs

echo "== Calentamiento (no se guarda) =="
"$JMETER" -n -t "$PLAN" -JHOST="$HOST" -JPORT="$PORT" \
  -JUSERS=10 -JRAMPUP=5 -JDURATION=60 -l resultados/calentamiento.tmp > /dev/null
rm -f resultados/calentamiento.tmp
sleep 30

for R in $(seq 1 "$REPETICIONES"); do
  for U in $CARGAS; do
    NOMBRE="${ESC}_${REP}rep_${U}u_r${R}_${ORIGEN}"
    rm -f "resultados/$NOMBRE.csv"    # JMeter agrega al final si el archivo ya existe
    echo "$(date +%H:%M:%S)  ->  resultados/$NOMBRE.csv"
    "$JMETER" -n -t "$PLAN" -JHOST="$HOST" -JPORT="$PORT" \
      -JUSERS="$U" -JRAMPUP="$RAMPUP" -JDURATION="$DURACION" \
      -l "resultados/$NOMBRE.csv" > "resultados/logs/$NOMBRE.log"
    grep "summary =" "resultados/logs/$NOMBRE.log" | tail -1 || true   # muestra el % de errores
    sleep "$PAUSA"
  done
done
echo "== Listo: $ESC con $REP replica(s) desde $ORIGEN =="
```

Qué hace el script:
- Alterna las repeticiones (todas las cargas de la repetición 1, luego todas las de la repetición 2). Así un problema temporal no afecta siempre a la misma carga.
- Antes de cada corrida borra el CSV, porque JMeter **agrega** al final si el archivo ya existe.
- Muestra al final de cada corrida la línea `summary =` con el número de peticiones y el % de errores (`Err:`).
- Se ejecuta siempre con `bash jmeter/correr.sh ...`, porque en la carpeta compartida el permiso de ejecución puede no aplicarse.

### 5.4 Prueba corta contra Compose (validar el plan)

Con Compose corriendo en vm1:

```bash
vagrant ssh jmeter
cd /vagrant
curl "http://192.168.56.11:8081/api/libros?size=1"
jmeter -n -t jmeter/plan-catalogo.jmx -JHOST=192.168.56.11 -JPORT=8081 \
  -JUSERS=5 -JRAMPUP=5 -JDURATION=20 -l /tmp/prueba.csv
```

En la última línea `summary =` debe aparecer `Err: 0 (0.00%)`. Revisen también el archivo con `head -3 /tmp/prueba.csv`: las URL deben tener páginas e ISBN distintos.

- [ ] Plan `.jmx` y `correr.sh` en el repositorio
- [ ] Prueba corta sin errores

---

## Paso 6. Protocolo de cada medición

Seguir esta lista **cada vez** que se mide una configuración (un escenario con un número de réplicas).

**Antes:**
1. Encender solo las VMs que la fase necesita (tabla de la sección 1).
2. En Kubernetes (desde vm1):
   - `kubectl get nodes -o wide`: todos los nodos en `Ready`, con su IP `192.168.56.x` en la columna INTERNAL-IP.
   - `kubectl get pods -n library-ns -o wide`: todos `1/1 Running`. **Anotar en qué nodo quedó cada réplica** en `docs/ubicacion_pods.md`.
3. Comprobar que la base tiene 10000 libros:
   - Compose: comando del Paso 4.2.
   - Kubernetes: `kubectl exec -n library-ns deploy/mysql-catalog-deployment -- mysql -uroot -ppassword -e "SELECT COUNT(*) FROM \`catalog-library\`.Book"`
4. **El PC no se usa para nada más durante la medición:** navegador, juegos, descargas y otros programas cerrados. Debe estar conectado a la corriente, con la suspensión desactivada y el plan de energía en "Alto rendimiento".

**Durante:**

5. En la VM `jmeter`: `cd /vagrant && bash jmeter/correr.sh ...`. Incluye el calentamiento.
6. Opcional: registrar CPU y memoria (Paso 11).

**Después:**

7. `kubectl get pods -n library-ns`: la columna **RESTARTS debe seguir en 0**. Si algún pod se reinició, la configuración no es válida y hay que repetirla.
8. Revisar el % de errores de cada corrida. Si hay errores con carga alta y ningún reinicio, la app se está saturando: eso es un resultado y se reporta. Pero si hay muchos errores con 10 usuarios, algo está mal configurado.
9. Los CSV ya quedaron en la carpeta `resultados/` del repo en el PC. Hacer commit de vez en cuando, o al menos una copia de seguridad.

---

## Paso 7. Fase 1: Docker Compose

| vm1 | vm2 | vm3 | jmeter |
|---|---|---|---|
| Compose | — | — | ✔ |

Compose ya está corriendo desde el Paso 4. En la VM `jmeter`:

```bash
cd /vagrant
bash jmeter/correr.sh compose 1 vm 192.168.56.11 8081
```

Opcional, en vm1 mientras corre: monitoreo con `docker stats` (Paso 11).

- [ ] Corridas de Compose completas

---

## Paso 8. Fase 2: Kubernetes con 1 nodo

| vm1 | vm2 | vm3 | jmeter |
|---|---|---|---|
| Nodo | — | — | ✔ |

### 8.1 Pasar vm1 a Kubernetes

En el PC, dentro de la carpeta del repo:

```bash
vagrant provision vm1 --provision-with microk8s
```

Este comando hace lo siguiente en vm1:
1. Baja Compose y desactiva Docker. Docker compite por CPU y deja la política `FORWARD` de iptables en `DROP`, lo que puede bloquear el tráfico de los pods.
2. Instala MicroK8s (versión `MICROK8S_CANAL` del `Vagrantfile`).
3. Configura la IP `192.168.56.11` en kubelet, kube-apiserver y Calico.
4. Activa los complementos `dns` y `metrics-server`.

Tarda varios minutos.

Si más adelante necesitan reconstruir la imagen del backend, enciendan Docker solo para eso con `sudo systemctl start docker`. Después ejecuten `sudo systemctl stop docker docker.socket` y `sudo iptables -P FORWARD ACCEPT`.

### 8.2 Verificar

Entrar de nuevo a la VM, para que se aplique el grupo `microk8s`:

```bash
vagrant ssh vm1
kubectl get nodes -o wide        # vm1 Ready, INTERNAL-IP = 192.168.56.11
kubectl get pods -A              # calico, coredns y metrics-server en Running
```

Si el nombre del nodo **no** es exactamente `vm1`, cambien el `nodeSelector` de `k8s/mysql-catalog.yaml` antes de desplegar.

### 8.3 Desplegar

```bash
cd /vagrant
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/
kubectl get pods -n library-ns -o wide -w    # Ctrl+C cuando todo esté 1/1 Running
```

MySQL tarda un poco más que el backend, porque genera los 10.000 libros al arrancar. Mientras MySQL no está listo, el backend puede reiniciarse algunas veces; eso es normal **solo durante el despliegue**.

Prueba desde la VM `jmeter`:

```bash
curl "http://192.168.56.11:30300/api/libros?page=0&size=5"
```

### 8.4 Medir

En vm1 se usa la función `escalar N`, que ya viene instalada. Baja el backend a 0 réplicas y lo sube a N. Así las réplicas se vuelven a repartir desde cero entre los nodos disponibles; los pods que ya existen nunca se mueven solos. MySQL siempre se queda en 1 réplica.

Repetir para N = 1, 2 y 3:

```bash
# vm1
escalar 1
# jmeter
bash jmeter/correr.sh k8s1n 1 vm 192.168.56.11 30300
```

En un nodo de 2 vCPU las réplicas (0.5 CPU cada una), MySQL (hasta 1 CPU) y los pods del sistema compiten por la misma CPU. Es normal que pasar de 2 a 3 réplicas mejore poco: ese es uno de los resultados a analizar.

- [ ] k8s1n con 1, 2 y 3 réplicas completas

---

## Paso 9. Fase 3: Kubernetes con 2 nodos

| vm1 | vm2 | vm3 | jmeter |
|---|---|---|---|
| Nodo principal | Nodo | — | ✔ |

### 9.1 Crear vm2 y unirla al clúster

```bash
# PC: crea vm2 e instala MicroK8s con su IP configurada
vagrant up vm2

# vm1: genera el comando de unión (es de un solo uso y expira)
microk8s add-node

# vm2 (vagrant ssh vm2): pegar el comando que usa la IP 192.168.56.11, con sudo y --worker
sudo microk8s join 192.168.56.11:25000/<token>/<hash> --worker

# vm1: verificar
kubectl get nodes -o wide                 # vm2 Ready, INTERNAL-IP = 192.168.56.12
kubectl get pods -n kube-system -o wide   # calico-node Running también en vm2
```

`--worker` hace que vm2 solo ejecute pods. El plano de control se queda en vm1.

### 9.2 Comprobar la red entre nodos (una sola vez)

```bash
# vm1
escalar 2                                  # debería quedar 1 réplica en cada nodo
kubectl logs -n library-ns <pod-que-está-en-vm2> --tail=3     # debe mostrar logs, sin error

# jmeter: 20 peticiones; todas deben dar 200
for i in $(seq 20); do curl -s -o /dev/null -w "%{http_code}\n" \
  "http://192.168.56.11:30300/api/libros?size=1"; done | sort | uniq -c
```

Si algo falla, revisen la sección [Problemas frecuentes](#problemas-frecuentes) antes de medir.

### 9.3 Medir

Para N = 1, 2 y 3:

```bash
# vm1
escalar 2
# jmeter
bash jmeter/correr.sh k8s2n 2 vm 192.168.56.11 30300
```

Con 3 réplicas deberían quedar 2 en un nodo y 1 en el otro. Anoten la ubicación de cada configuración.

El NodePort se llama siempre en la IP de vm1, y kube-proxy reparte las peticiones entre las réplicas de **todos** los nodos. Mencionen en el análisis que todo el tráfico entra por vm1.

- [ ] k8s2n con 1, 2 y 3 réplicas completas

---

## Paso 10. Fase 4: Kubernetes con 3 nodos

| vm1 | vm2 | vm3 | jmeter |
|---|---|---|---|
| Nodo principal | Nodo | Nodo | ✔ |

```bash
# PC
vagrant up vm3

# vm1
microk8s add-node

# vm3 (vagrant ssh vm3)
sudo microk8s join 192.168.56.11:25000/<token>/<hash> --worker

# vm1
kubectl get nodes -o wide                 # vm1, vm2 y vm3 Ready con IPs 192.168.56.x
```

Repetir la comprobación del Paso 9.2 y luego medir para N = 1, 2 y 3:

```bash
# vm1
escalar 3                                  # 1 réplica en cada nodo
# jmeter
bash jmeter/correr.sh k8s3n 3 vm 192.168.56.11 30300
```

Al terminar: `vagrant halt`.

- [ ] k8s3n con 1, 2 y 3 réplicas completas

---

## Paso 11. Monitoreo de CPU y memoria (opcional)

Es el punto opcional del PDF. La forma más liviana de cubrirlo es `kubectl top` (usa el *metrics-server* activado en el Paso 8).

Abrir una segunda terminal (`vagrant ssh vm1`) mientras corre cada configuración. Los archivos quedan directamente en la carpeta `monitoreo/` del repo:

```bash
mkdir -p /vagrant/monitoreo
# Kubernetes: CPU (milicores) y memoria por pod, cada 5 s. Ctrl+C al terminar.
while true; do kubectl top pods -n library-ns --no-headers | sed "s/^/$(date +%s) /"; sleep 5; done \
  >> /vagrant/monitoreo/k8s1n_2rep.txt

# Docker Compose (Fase 1):
while true; do docker stats --no-stream --format "$(date +%s) {{.Name}} {{.CPUPerc}} {{.MemUsage}}"; sleep 5; done \
  >> /vagrant/monitoreo/compose_1rep.txt
```

Para la vista por nodo se puede usar `kubectl top nodes`.

Este monitoreo sirve para identificar el cuello de botella. Si el pod de MySQL está cerca de `1000m` (su límite) mientras el backend no llega a `500m`, el límite es la base de datos, y agregar réplicas del backend no va a ayudar.

También conviene mirar el **Administrador de tareas del PC** durante una corrida de 3 nodos. Si la CPU del PC está al 100%, el límite es el hardware compartido. Anótenlo como limitación.

**Alternativa con Prometheus y Grafana:** `microk8s enable observability`. Ojo: consume CPU y RAM de nodos que solo tienen 2 vCPU y altera las mediciones. Si lo usan, déjenlo activo en **todas** las configuraciones de Kubernetes y menciónenlo en el notebook.

---

## Paso 12. Notebook de análisis

Crear el notebook en Google Colab y guardarlo en el repo como `notebook/analisis.ipynb` (*Archivo → Descargar .ipynb*, o *Guardar una copia en GitHub*). Antes de abrirlo en Colab, los resultados deben estar subidos a GitHub.

### 12.1 Secciones (las que pide el PDF)

1. **Introducción y objetivos**
2. **Descripción de la aplicación:** se basa en el `bookstore-app` del profesor. Se dejó solo el catálogo (Spring Boot) con MySQL, se agregaron los endpoints de prueba y se generaron 10.000 libros. Incluir un diagrama simple.
3. **Infraestructura:**
   - El PC y las 4 VMs (`docs/maquinas.md`).
   - Vagrant y VirtualBox, la red privada y la versión de MicroK8s.
4. **Configuración de cada escenario:** fragmentos del `docker-compose.yml`, de los YAML de `k8s/` (límites, probes, `nodeSelector`, `topologySpreadConstraints`) y del `Vagrantfile`, cómo se escala y la tabla de ubicación de pods.
5. **Monitoreo**, si se hizo.
6. **Metodología de JMeter:**
   - El plan: los dos endpoints y los valores aleatorios.
   - Las cargas, el ramp-up, la duración, las repeticiones, el calentamiento y la pausa.
   - JMeter en su propia VM para todas las fases.
   - **La limitación de que todo comparte el mismo PC** (sección 1 de esta guía).
7. **Resultados:** la tabla resumen y los gráficos.
8. **Análisis comparativo**
9. **Conclusiones**
10. **Recomendaciones**

### 12.2 Código

**Celda 1: obtener los datos**

```python
!git clone https://github.com/jha1rs/proyecto-soft3.git
%cd proyecto-soft3
```

**Celda 2: cargar y resumir cada corrida**

```python
import glob
import os
import re

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

CARPETA = "resultados"
RAMPUP_S = 30   # el mismo valor de RAMPUP usado en correr.sh

PATRON = re.compile(
    r"(?P<escenario>compose|k8s[123]n)_(?P<replicas>\d)rep_(?P<usuarios>\d+)u"
    r"_r(?P<corrida>\d+)_(?P<origen>\w+)\.csv$")

def resumir(df):
    """Metricas de una corrida (o de un endpoint dentro de una corrida)."""
    duracion_s = ((df.timeStamp + df.elapsed).max() - df.timeStamp.min()) / 1000
    exito = df.success.astype(str).str.lower() == "true"
    return pd.Series({
        "peticiones": len(df),
        "t_medio_ms": df.elapsed.mean(),
        "p95_ms": df.elapsed.quantile(0.95),
        "throughput_rps": len(df) / duracion_s,
        "errores_pct": 100 * (1 - exito.mean()),
    })

filas = []
for ruta in sorted(glob.glob(os.path.join(CARPETA, "*.csv"))):
    m = PATRON.search(os.path.basename(ruta))
    if not m:
        print("Ignorado (nombre no sigue el formato):", ruta)
        continue
    df = pd.read_csv(ruta, low_memory=False)
    df = df[df.timeStamp >= df.timeStamp.min() + RAMPUP_S * 1000]  # descarta el ramp-up
    filas.append({**m.groupdict(), **resumir(df).to_dict()})

corridas = pd.DataFrame(filas)
for col in ("replicas", "usuarios", "corrida"):
    corridas[col] = corridas[col].astype(int)
nombres = {"compose": "Docker Compose", "k8s1n": "K8s 1 nodo",
           "k8s2n": "K8s 2 nodos", "k8s3n": "K8s 3 nodos"}
corridas["escenario_nombre"] = corridas.escenario.map(nombres)
print(corridas.shape)
```

**Celda 3: tabla resumen (promedio y desviación estándar de las repeticiones)**

```python
tabla = (corridas
         .groupby(["escenario_nombre", "replicas", "usuarios"])
         [["t_medio_ms", "p95_ms", "throughput_rps", "errores_pct"]]
         .agg(["mean", "std"]).round(1))
display(tabla)
```

**Celda 4: gráficos**

```python
sns.set_theme(style="whitegrid")
k8s = corridas[corridas.escenario != "compose"]

# 1 y 2. Efecto de las replicas dentro de cada escenario de Kubernetes
for metrica, titulo in [("t_medio_ms", "Tiempo medio de respuesta (ms)"),
                        ("throughput_rps", "Throughput (peticiones/s)")]:
    g = sns.relplot(data=k8s, x="usuarios", y=metrica, hue="replicas",
                    col="escenario_nombre", kind="line", marker="o",
                    errorbar="sd", palette="viridis")
    g.set_axis_labels("Usuarios concurrentes", titulo)
    g.set_titles("{col_name}")
    g.legend.set_title("Replicas")
    g.figure.suptitle(f"{titulo} segun replicas", y=1.03)
    plt.show()

# 3 y 4. 1 vs 2 vs 3 nodos con el mismo numero de replicas
for metrica, titulo in [("throughput_rps", "Throughput (peticiones/s)"),
                        ("t_medio_ms", "Tiempo medio de respuesta (ms)")]:
    g = sns.relplot(data=k8s, x="usuarios", y=metrica, hue="escenario_nombre",
                    col="replicas", kind="line", marker="o", errorbar="sd")
    g.set_axis_labels("Usuarios concurrentes", titulo)
    g.set_titles("{col_name} replica(s)")
    g.legend.set_title("Escenario")
    g.figure.suptitle(f"{titulo} segun numero de nodos", y=1.03)
    plt.show()

# 5. Docker Compose vs Kubernetes 1 nodo, ambos con 1 replica
base = corridas[(corridas.replicas == 1) & corridas.escenario.isin(["compose", "k8s1n"])]
fig, ejes = plt.subplots(1, 2, figsize=(11, 4))
for eje, metrica, titulo in zip(ejes, ["t_medio_ms", "throughput_rps"],
                                ["Tiempo medio (ms)", "Throughput (peticiones/s)"]):
    sns.lineplot(data=base, x="usuarios", y=metrica, hue="escenario_nombre",
                 marker="o", errorbar="sd", ax=eje)
    eje.set(xlabel="Usuarios concurrentes", ylabel=titulo)
    eje.legend(title="Escenario")
fig.suptitle("Docker Compose vs Kubernetes (1 nodo, 1 replica)")
fig.tight_layout()
plt.show()
```

**Celda 5: indicadores para el análisis**

```python
# Cuanto mejora el throughput con 2 y 3 replicas frente a 1 (con la carga maxima)
carga_max = corridas.usuarios.max()
mejora = (corridas[corridas.usuarios == carga_max]
          .groupby(["escenario_nombre", "replicas"]).throughput_rps.mean()
          .unstack("replicas"))
mejora = mejora.div(mejora[1], axis=0).round(2)
display(mejora)

# Ley de Little (sistema cerrado sin tiempo de espera): throughput ~ usuarios / tiempo medio
corridas["little_ratio"] = (corridas.throughput_rps
                            / (corridas.usuarios / (corridas.t_medio_ms / 1000))).round(2)
print(corridas.little_ratio.describe())
```

**Cómo leer los dos indicadores:**
- **Mejora:** un valor de 2.0 significa que con esa cantidad de réplicas se procesó el doble que con 1.
- **Ley de Little:** con JMeter sin tiempos de espera, cada usuario lanza una petición apenas recibe la anterior, así que el throughput debería ser ≈ usuarios ÷ tiempo medio (`little_ratio` cercano a 1, o un poco menor).
  - Un valor mucho menor indica que la VM de JMeter fue el cuello de botella, o que hubo pausas.
  - Sirve como **chequeo de calidad de las mediciones**, y queda bien en la sección de metodología.

Para ver las métricas por endpoint, se puede agrupar cada CSV por `label` con `df.groupby("label").apply(resumir)`.

### 12.3 Preguntas que debe responder el análisis

- **Réplicas en 1 nodo:** ¿sube el throughput de 1 a 2 y a 3 réplicas? ¿Dónde deja de mejorar? Relaciónenlo con la CPU del nodo: 2 vCPU para las réplicas, MySQL y el sistema.
- **1 vs 2 vs 3 nodos** con el mismo número de réplicas: ¿repartir las réplicas entre nodos mejora el throughput y el tiempo de respuesta? La diferencia entre 1 y 2 nodos es lo que más pesa en la evaluación.
- **Cuello de botella:** MySQL tiene una sola réplica y 1 CPU. Si el throughput se estanca aunque haya más réplicas y más nodos, revisen el monitoreo para ver si MySQL está en su límite.
- **Hardware compartido:** si la CPU del PC llegó al 100% con 3 nodos, el tercer nodo no pudo aportar capacidad real. Hay que discutirlo.
- **Compose vs Kubernetes** con 1 réplica y los mismos límites: ¿qué tanto cuesta la capa de red de Kubernetes (NodePort, kube-proxy, red de pods)?
- **Saturación:** ¿con qué carga empiezan a aparecer errores o a dispararse el p95?
- **Limitaciones:** el hardware es compartido; todo el tráfico entra por vm1; las repeticiones son pocas; la base cabe completa en memoria.

**Recomendaciones posibles:** escalar o replicar la base de datos (réplicas de lectura, caché), ajustar los límites de CPU, usar un balanceador externo en vez del NodePort de un solo nodo, usar autoescalado (HPA), o repetir el experimento con nodos en máquinas físicas distintas.

---

## Paso 13. Reporte PDF y README

### Reporte PDF (`docs/reporte.pdf`)

Pueden escribirlo en Google Docs y exportarlo a PDF (*Archivo → Descargar → PDF*). Debe incluir:

1. **Integrantes**, curso y fecha.
2. **Enlaces:**
   - Repositorio de GitHub.
   - Notebook en Colab: *Compartir → Cualquier persona con el enlace → Lector*.
   - Imagen en Docker Hub.
3. **Requisitos:** VirtualBox y Vagrant (con sus versiones), un PC con los recursos del Paso 3.1, y Java 17 + JMeter 5.6.3 si se quiere editar el plan.
4. **Cómo ejecutar el proyecto:** gracias a Vagrant, cualquiera puede reproducirlo:
   - `vagrant up vm1 jmeter` → Compose: `cd /vagrant/docker && docker compose up -d --build`.
   - `vagrant provision vm1 --provision-with microk8s` → `kubectl apply -f /vagrant/k8s/` y `escalar N`.
   - `vagrant up vm2` / `vagrant up vm3` → `microk8s add-node` y `microk8s join ... --worker`.
   - En la VM `jmeter`: `bash jmeter/correr.sh ...`.
5. **Cómo ver el notebook:** el enlace de Colab, o abrir `notebook/analisis.ipynb` desde GitHub.
6. **Resumen de una página** con los resultados principales.

### README

Actualizar el `README.md` con:
- Una descripción corta del proyecto.
- La estructura de carpetas (Paso 1).
- Los comandos de Vagrant y cómo ejecutar cada escenario.
- Los enlaces al notebook y al PDF.

---

## Paso 14. Lista de verificación de la entrega

**Repositorio**
- [ ] Código fuente con `Dockerfile` (`app/backend-catalog/`)
- [ ] `docker/docker-compose.yml` con los límites de recursos
- [ ] YAML de Kubernetes en `k8s/`
- [ ] `Vagrantfile`, `.gitattributes` y `.vagrant/` en el `.gitignore`
- [ ] `jmeter/plan-catalogo.jmx` y `jmeter/correr.sh`
- [ ] `resultados/`: 80 CSV con 2 repeticiones (10 configuraciones × 4 cargas × 2), más logs
- [ ] `docs/maquinas.md` y `docs/ubicacion_pods.md`
- [ ] (Opcional) `monitoreo/`
- [ ] `README.md` actualizado

**Notebook** (`notebook/analisis.ipynb`)
- [ ] Introducción y objetivos
- [ ] Descripción de la aplicación
- [ ] Configuración de cada escenario y variación de réplicas
- [ ] (Opcional) Configuración del monitoreo
- [ ] Metodología de JMeter, con la limitación del hardware compartido
- [ ] Métricas (tiempo medio y throughput) con gráficos generados en el notebook
- [ ] Impacto del número de réplicas y diferencia entre 1, 2 y 3 nodos
- [ ] Análisis comparativo
- [ ] Conclusiones
- [ ] Recomendaciones

**Reporte**
- [ ] PDF con instrucciones de ejecución, cómo ver el notebook y los enlaces

**Al terminar el semestre**
- [ ] `vagrant destroy` borra las VMs y libera el espacio en disco del PC

---

## Problemas frecuentes

**Vagrant y VirtualBox**

| Síntoma | Causa probable | Solución |
|---|---|---|
| `VT-x is disabled` / `AMD-V is disabled` | Virtualización apagada en la BIOS | Activarla en la BIOS o UEFI del PC |
| Las VMs van muy lentas, con una tortuga verde en VirtualBox | Hyper-V activo en Windows | Ver Paso 3.2, punto 4 |
| Error de rango de IP en la red *host-only* | VirtualBox solo permite ciertos rangos | Las IPs `192.168.56.x` del `Vagrantfile` están dentro del rango por defecto. No las cambien a otro rango |
| `$'\r': command not found` o `bad interpreter` al correr un `.sh` | Finales de línea de Windows (CRLF) | `sed -i 's/\r$//' jmeter/correr.sh`, y el `.gitattributes` del Paso 1 |
| Falla la instalación a la mitad (por ejemplo, por la red) | Descarga interrumpida | `vagrant provision <vm>` la repite |
| `vagrant up` no arranca ninguna VM | Las VMs no arrancan solas | Indicar los nombres: `vagrant up vm1 jmeter` |

**Kubernetes**

| Síntoma | Causa probable | Solución |
|---|---|---|
| INTERNAL-IP de un nodo = `10.0.2.15` | No se aplicó `--node-ip` | Revisar que `/var/snap/microk8s/current/args/kubelet` tenga `--node-ip=192.168.56.x` y ejecutar `sudo snap restart microk8s` |
| `calico-node` en `CrashLoopBackOff` en vm2/vm3, o los pods de un nodo no responden | Calico usa la tarjeta NAT | En vm1, `kubectl get ds calico-node -n kube-system -o yaml \| grep -A1 IP_AUTODETECTION` debe mostrar `can-reach=192.168.56.11`. Si no, repetir los dos últimos comandos del aprovisionamiento de `microk8s` en vm1 (el `sed` y el `apply` del `cni.yaml`) |
| Un nodo se une pero nunca queda `Ready`, o hay errores de certificado | Interacción de `--advertise-address` con la unión | En vm1, quitar la línea `--advertise-address` de `/var/snap/microk8s/current/args/kube-apiserver` y ejecutar `sudo snap restart microk8s`. Luego `sudo microk8s leave` en el nodo y `microk8s remove-node vm2` en vm1, y volver a unir |
| `kubectl logs` de un pod en vm2/vm3 da timeout | El nodo se registró con la IP NAT | Igual que la fila de INTERNAL-IP |
| Pod del backend en `ImagePullBackOff` | Nombre de imagen mal escrito o repo privado en Docker Hub | Revisar la línea `image:` y poner el repo público |
| Pod de MySQL en `Pending` | El nombre del nodo no es `vm1` | `kubectl get nodes` y corregir el `nodeSelector` |
| Réplicas en `Pending` | `topologySpreadConstraints` no puede cumplirse o falta CPU | `kubectl describe pod <pod> -n library-ns` (ver *Events*) |
| Backend en `CrashLoopBackOff` al desplegar | MySQL todavía está generando los datos | Esperar. Si sigue: `kubectl logs <pod> -n library-ns` |
| RESTARTS > 0 después de una corrida | Probes fallando bajo carga o falta de memoria (`OOMKilled`) | `kubectl describe pod`. Repetir la configuración. Si es memoria, subir `NODO_RAM` |
| `microk8s join` falla | Token ya usado o expirado | Ejecutar `microk8s add-node` de nuevo |

**JMeter**

| Síntoma | Causa probable | Solución |
|---|---|---|
| 100% de errores | IP o puerto mal, o el plan usa `${HOST}` en vez de `${__P(HOST,...)}` | Probar con `curl` desde la VM `jmeter`. Revisar el plan |
| `jmeter: command not found` | La sesión se abrió antes de terminar la instalación | Salir y volver a entrar con `vagrant ssh jmeter` |
| Los CSV no aparecen en el notebook | Los nombres no siguen el formato de la sección 2 | Renombrar los archivos |

---

## Tiempos y reparto del trabajo

**Costo:** $0. Todo corre en un PC propio.

**Tiempo estimado:**

| Etapa | Tiempo |
|---|---|
| Correcciones y repositorio (Pasos 1–2) | 1–2 h |
| Instalar VirtualBox y Vagrant y crear las primeras VMs (Paso 3) | 1–2 h, sobre todo en descargas |
| Compose y Docker Hub (Paso 4) | 1 h |
| JMeter (Paso 5) | 1–2 h |
| Mediciones (Pasos 7–10), 2 repeticiones | ≈ 5 h, en varias sesiones |
| Notebook, PDF y README (Pasos 12–13) | 6–10 h |

Como todo corre en un PC, las mediciones se hacen en el PC de quien tenga el hardware. El resto del grupo puede trabajar en el plan de JMeter y en el notebook en paralelo.

**Reparto sugerido:**

| Persona | Responsabilidades |
|---|---|
| A (dueño del PC) | VirtualBox, Vagrant, Compose, Docker Hub, Kubernetes y ejecución de las mediciones |
| B | Plan de JMeter, script, monitoreo y `docs/` (máquinas y ubicación de pods) |
| C | Notebook (análisis y gráficos), reporte PDF y README |

Todos revisan las conclusiones antes de entregar.
