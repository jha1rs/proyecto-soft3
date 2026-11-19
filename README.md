# proyecto-soft3

Proyecto final de Principios y prácticas de Desarrollo de Software Orientado a Objetos.

Integrantes: Jhair Sánchez, Mariana Gómez y Daniel Prada.

Desplegamos la misma aplicación (el servicio de catálogo de libros del [bookstore-app](https://github.com/chaphe/bookstore-app) del profesor, con MySQL y 10.000 libros) en cuatro escenarios: Docker Compose y Kubernetes (MicroK8s) con 1, 2 y 3 nodos. En Kubernetes probamos 1, 2 y 3 réplicas del backend. Con JMeter medimos el tiempo medio de respuesta y el throughput con 10, 50, 100 y 200 usuarios.

- Notebook de análisis: [`notebook/analisis.ipynb`](notebook/analisis.ipynb) ([abrir en Colab](https://colab.research.google.com/github/jha1rs/proyecto-soft3/blob/main/notebook/analisis.ipynb))
- Reporte: [`docs/reporte.docx`](docs/reporte.docx)
- Imagen del backend: [`mari0812/backend-catalog:1.0`](https://hub.docker.com/r/mari0812/backend-catalog)

## Estructura

```
app/backend-catalog/   código del backend (Spring Boot) y su Dockerfile
db/init.sql            crea la tabla Book y genera los 10.000 libros
docker/                docker-compose.yml (escenario 1)
k8s/                   manifiestos de Kubernetes (namespace, MySQL, backend)
jmeter/                plan de pruebas (.jmx) y script correr.sh
resultados/            un CSV por prueba, logs de JMeter y pruebas descartadas
notebook/              notebook con el análisis
docs/                  reporte
Vagrantfile            crea las 4 máquinas virtuales
```

## Requisitos

- VirtualBox y Vagrant.
- Un PC x86 con virtualización activada en la BIOS. Para los 3 nodos se recomiendan 8 núcleos y 24 GB de RAM (ver `GUIA_PROYECTO_FINAL.md`, paso 3.1).
- Java 17 y JMeter 5.6.3 solo si se quiere editar el plan de pruebas. La VM `jmeter` ya los instala.

## Máquinas virtuales

| VM | IP | Uso |
|---|---|---|
| vm1 | 192.168.56.11 | Docker Compose y luego nodo principal de Kubernetes |
| vm2 | 192.168.56.12 | segundo nodo |
| vm3 | 192.168.56.13 | tercer nodo |
| jmeter | 192.168.56.20 | genera la carga |

Dentro de cada VM el repositorio queda en `/vagrant`. Ninguna VM arranca con `vagrant up` sin nombre.

```bash
vagrant up vm1 jmeter     # encender las VMs indicadas
vagrant ssh vm1           # entrar a una VM
vagrant halt              # apagar todas
```

## Cómo correr cada escenario

**Docker Compose**

```bash
# vm1
cd /vagrant/docker && docker compose up -d --build
# jmeter
cd /vagrant && bash jmeter/correr.sh compose 1 vm 192.168.56.11 8081
```

**Kubernetes con 1 nodo**

```bash
# PC
vagrant provision vm1 --provision-with microk8s
# vm1
cd /vagrant
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/
escalar 1                      # o 2, o 3 réplicas
# jmeter
bash jmeter/correr.sh k8s1n 1 vm 192.168.56.11 30300
```

**Kubernetes con 2 y 3 nodos**

```bash
# PC
vagrant up vm2                 # vm3 para el tercer nodo
# vm1
microk8s add-node
# vm2 (o vm3), con el comando que imprime add-node
sudo microk8s join 192.168.56.11:25000/<token>/<hash> --worker
# vm1
escalar 2
# jmeter
bash jmeter/correr.sh k8s2n 2 vm 192.168.56.11 30300
```

Los CSV quedan en `resultados/` con el formato `<escenario>_<réplicas>rep_<usuarios>u_r<repetición>_vm.csv`. El notebook lee esos archivos directamente.

La guía completa, con la solución de problemas frecuentes, está en [`GUIA_PROYECTO_FINAL.md`](GUIA_PROYECTO_FINAL.md).
