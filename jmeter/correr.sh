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
