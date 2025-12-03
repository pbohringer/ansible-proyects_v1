#!/bin/bash
set -e

#############################################
# CONFIGURACIÓN (MODIFICA ESTOS VALORES)
#############################################

EE_NAME="ee-vmware"
EE_VERSION="4.6"
REGISTRY_URL="registry.ejemplo.com/ee"
AAP_CONTROLLER_URL="https://aap-controller.ejemplo.com"
AAP_USERNAME="admin"
AAP_PASSWORD="MiPassword"
REGISTER_IN_AAP=true

#############################################
# GENERACIÓN DE ESTRUCTURA
#############################################

echo "📁 Creando estructura del EE..."
mkdir -p vmware-ee
cd vmware-ee

#############################################
# ARCHIVO execution-environment.yml
#############################################

echo "📝 Generando execution-environment.yml..."
cat << 'EOF' > execution-environment.yml
version: 3

images:
  base_image:
    name: registry.redhat.io/ansible-automation-platform-25/ee-supported-rhel8:latest

dependencies:
  galaxy: requirements.yml
  python: requirements.txt

options:
  package_manager_path: /usr/bin/microdnf

additional_build_steps:
  prepend: |
    RUN microdnf install -y git && microdnf clean all
EOF

#############################################
# ARCHIVO requirements.yml
#############################################

echo "📝 Generando requirements.yml..."
cat << 'EOF' > requirements.yml
collections:
  - name: vmware.vmware_rest
    version: 4.6.0

  - name: community.vmware
    version: 3.9.0
EOF

#############################################
# ARCHIVO requirements.txt
#############################################

echo "📝 Generando requirements.txt..."
cat << 'EOF' > requirements.txt
pyvmomi
requests
python-dateutil
urllib3
six
EOF

#############################################
# CONSTRUCCIÓN DEL EE
#############################################

echo "🏗️ Construyendo EE con ansible-builder..."
ansible-builder build -t ${EE_NAME}:${EE_VERSION}

#############################################
# PUSH AL REGISTRY
#############################################

echo "🔧 Etiquetando imagen..."
podman tag localhost/${EE_NAME}:${EE_VERSION} ${REGISTRY_URL}/${EE_NAME}:${EE_VERSION}

echo "📤 Subiendo al registry..."
podman push ${REGISTRY_URL}/${EE_NAME}:${EE_VERSION}

#############################################
# REGISTRO AUTOMÁTICO EN AAP (OPCIONAL)
#############################################

if [ "$REGISTER_IN_AAP" = true ]; then
  echo "📡 Registrando EE en AAP Controller vía API..."

  curl -sk -u "${AAP_USERNAME}:${AAP_PASSWORD}" \
    -H "Content-Type: application/json" \
    -X POST "${AAP_CONTROLLER_URL}/api/v2/execution_environments/" \
    -d "{
      \"name\": \"EE VMware ${EE_VERSION}\",
      \"image\": \"${REGISTRY_URL}/${EE_NAME}:${EE_VERSION}\",
      \"pull\": \"always\"
    }"
else
  echo "ℹ️ Registro en AAP desactivado."
fi

echo "✅ EE VMware creado y publicado exitosamente."
echo "👉 Imagen: ${REGISTRY_URL}/${EE_NAME}:${EE_VERSION}"
