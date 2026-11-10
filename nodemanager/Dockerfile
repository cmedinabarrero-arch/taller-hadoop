# NodeManager de Hadoop + Python 3.
# Las tareas Map/Reduce se ejecutan en los NodeManagers, así que es aquí
# donde Hadoop Streaming necesita Python para correr mapper.py y reducer.py.
FROM bde2020/hadoop-nodemanager:2.0.0-hadoop3.2.1-java8

# La imagen base es Debian 9 (stretch), que ya está archivada:
# apuntamos apt al repositorio de archivo antes de instalar.
RUN sed -i -e 's|deb.debian.org|archive.debian.org|g' \
           -e 's|security.debian.org|archive.debian.org|g' \
           -e '/stretch-updates/d' /etc/apt/sources.list \
 && apt-get -o Acquire::Check-Valid-Until=false update \
 && apt-get install -y --no-install-recommends python3 \
 && rm -rf /var/lib/apt/lists/* \
 && python3 --version
