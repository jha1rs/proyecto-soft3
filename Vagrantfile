# -*- mode: ruby -*-
# vi: set ft=ruby :
#
# Proyecto final: 3 nodos (vm1, vm2, vm3) + 1 VM para JMeter, todas en el mismo PC.
# Requiere VirtualBox y Vagrant. Este archivo va en la RAIZ del repositorio:
# el repositorio queda disponible dentro de cada VM en /vagrant.
#
# Uso por fases:
#   vagrant up vm1 jmeter                              # Fase 1 (Compose)
#   vagrant provision vm1 --provision-with microk8s    # pasar vm1 a Kubernetes (Fase 2)
#   vagrant up vm2                                     # Fase 3 (2 nodos)
#   vagrant up vm3                                     # Fase 4 (3 nodos)
#   vagrant ssh vm1 | vm2 | vm3 | jmeter               # entrar a una VM
#   vagrant halt                                       # apagar todas
#
# Ninguna VM arranca con un "vagrant up" sin nombre: siempre hay que decir cuales.

# ---- Recursos de cada VM (ajustar segun el PC, ver la guia) ----------------
NODO_CPUS   = 2
NODO_RAM    = 4096    # MB
JMETER_CPUS = 2
JMETER_RAM  = 2048    # MB

MICROK8S_CANAL = "1.31/stable"   # la MISMA version en los 3 nodos
JMETER_VERSION = "5.6.3"

NODOS = {
  "vm1" => "192.168.56.11",
  "vm2" => "192.168.56.12",
  "vm3" => "192.168.56.13",
}
IP_JMETER = "192.168.56.20"
IP_PRINCIPAL = NODOS["vm1"]

HOSTS = NODOS.map { |nombre, ip| "#{ip} #{nombre}" }.push("#{IP_JMETER} jmeter").join("\n")

# ---- Aprovisionamiento comun: paquetes basicos y nombres de las maquinas ----
BASE = <<~SHELL
  set -eux
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q git curl
  sed -i '/192\\.168\\.56\\./d' /etc/hosts
  cat >> /etc/hosts <<'EOF'
  #{HOSTS}
  EOF
SHELL

# ---- vm1: Docker para la fase de Docker Compose ----------------------------
DOCKER = <<~SHELL
  set -eux
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi
  usermod -aG docker vagrant
SHELL

# ---- Nodos: MicroK8s configurado para usar la red privada ------------------
# Cada VM de VirtualBox tiene una tarjeta NAT con la MISMA IP (10.0.2.15) en
# todas. Si Kubernetes usa esa tarjeta, los nodos no se ven entre si. Por eso
# se fija la IP privada en kubelet, kube-apiserver y Calico.
# Argumentos: $1 = IP privada del nodo, $2 = "principal" o "worker"
MICROK8S = <<~SHELL
  set -eux
  IP="$1"
  ROL="$2"
  ARGS=/var/snap/microk8s/current/args

  # Si Docker esta instalado (vm1), se baja Compose y se apaga Docker:
  # compite por CPU y deja la politica FORWARD de iptables en DROP.
  if systemctl list-unit-files docker.service | grep -q docker.service; then
    if [ -f /vagrant/docker/docker-compose.yml ]; then
      docker compose -f /vagrant/docker/docker-compose.yml down || true
    fi
    systemctl disable --now docker.service docker.socket || true
  fi
  iptables -P FORWARD ACCEPT

  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q snapd
  snap wait system seed.loaded
  snap install microk8s --classic --channel=#{MICROK8S_CANAL}
  usermod -aG microk8s vagrant
  mkdir -p /home/vagrant/.kube
  chown -R vagrant:vagrant /home/vagrant/.kube

  grep -q -- "--node-ip" $ARGS/kubelet || echo "--node-ip=${IP}" >> $ARGS/kubelet
  if [ "$ROL" = "principal" ]; then
    grep -q -- "--advertise-address" $ARGS/kube-apiserver || echo "--advertise-address=${IP}" >> $ARGS/kube-apiserver
  fi
  snap restart microk8s
  microk8s status --wait-ready --timeout 600
  snap alias microk8s.kubectl kubectl

  # Funcion "escalar N": baja el backend a 0 replicas y lo sube a N,
  # para que las replicas se repartan desde cero entre los nodos.
  cat > /etc/profile.d/escalar.sh <<'EOF'
  escalar() {
    kubectl scale deployment catalog-backend-deployment -n library-ns --replicas=0
    kubectl wait --for=delete pod -l app=catalog-backend -n library-ns --timeout=120s
    kubectl scale deployment catalog-backend-deployment -n library-ns --replicas="$1"
    kubectl rollout status deployment/catalog-backend-deployment -n library-ns --timeout=300s
    kubectl get pods -n library-ns -o wide
  }
  EOF

  if [ "$ROL" = "principal" ]; then
    microk8s enable dns
    microk8s enable metrics-server
    sed -i "s/first-found/can-reach=${IP}/" $ARGS/cni-network/cni.yaml
    microk8s kubectl apply -f $ARGS/cni-network/cni.yaml
  fi
SHELL

# ---- jmeter: Java + JMeter ---------------------------------------------------
JMETER = <<~SHELL
  set -eux
  export DEBIAN_FRONTEND=noninteractive
  apt-get install -y -q openjdk-17-jre-headless
  if [ ! -d /opt/apache-jmeter-#{JMETER_VERSION} ]; then
    curl -fsSL -o /tmp/jmeter.tgz https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-#{JMETER_VERSION}.tgz
    tar xzf /tmp/jmeter.tgz -C /opt
    rm /tmp/jmeter.tgz
  fi
  echo 'export PATH=/opt/apache-jmeter-#{JMETER_VERSION}/bin:$PATH' > /etc/profile.d/jmeter.sh
SHELL

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant"

  NODOS.each do |nombre, ip|
    config.vm.define nombre, autostart: false do |nodo|
      nodo.vm.hostname = nombre
      nodo.vm.network "private_network", ip: ip
      nodo.vm.provider "virtualbox" do |vb|
        vb.name   = "proyecto-#{nombre}"
        vb.cpus   = NODO_CPUS
        vb.memory = NODO_RAM
      end
      nodo.vm.provision "base", type: "shell", inline: BASE
      if nombre == "vm1"
        # vm1 empieza con Docker (Fase 1). MicroK8s se instala a mano al pasar
        # a Kubernetes: vagrant provision vm1 --provision-with microk8s
        nodo.vm.provision "docker", type: "shell", inline: DOCKER
        nodo.vm.provision "microk8s", type: "shell", run: "never",
                          inline: MICROK8S, args: [ip, "principal"]
      else
        nodo.vm.provision "microk8s", type: "shell",
                          inline: MICROK8S, args: [ip, "worker"]
      end
    end
  end

  config.vm.define "jmeter", autostart: false do |jm|
    jm.vm.hostname = "jmeter"
    jm.vm.network "private_network", ip: IP_JMETER
    jm.vm.provider "virtualbox" do |vb|
      vb.name   = "proyecto-jmeter"
      vb.cpus   = JMETER_CPUS
      vb.memory = JMETER_RAM
    end
    jm.vm.provision "base", type: "shell", inline: BASE
    jm.vm.provision "jmeter", type: "shell", inline: JMETER
  end
end
