#!/bin/bash

# Função para mostrar a mensagem de uso
show_usage() {
    echo -e     "Uso: \n\n      curl -sSL https://updatecrm.erpcon.com.br | sudo bash\n\n"
    echo -e "Exemplo: \n\n      curl -sSL https://updatecrm.erpcon.com.br | sudo bash\n\n"
}

# Função para sair com erro
show_error() {
    echo $1
    echo -e "\n\nAlterações precisam ser verificadas manualmente, procure suporte se necessário\n\n"
    exit 1
}

# Função para mensagem em vermelho
echored() {
   echo -ne "\033[41m\033[37m\033[1m"
   echo -n "$1"
   echo -e "\033[0m"
}

if ! [ -n "$BASH_VERSION" ]; then
   echo "Este script deve ser executado como utilizando o bash\n\n" 
   show_usage
   exit 1
fi

# Verifica se está rodando como root
if [[ $EUID -ne 0 ]]; then
   echo "Este script deve ser executado como root" 
   exit 1
fi

if [ -n "$1" ]; then
  BRANCH=$1
fi

CURBASE=$(basename ${PWD})
BACKEND_PUBLIC_VOL=$(docker volume list -q | grep -e "^${CURBASE}_backend_public$")
BACKEND_PRIVATE_VOL=$(docker volume list -q | grep -e "^${CURBASE}_backend_private$")
POSTGRES_VOL=$(docker volume list -q | grep -e "^${CURBASE}_postgres_data")

[ -f credentials.env ] && . credentials.env

[ -n "${DOCKER_REGISTRY}" ] && [ -n "${DOCKER_USER}" ] && [ -n "${DOCKER_PASSWORD}" ] && \
echo ${DOCKER_PASSWORD} | docker login ${DOCKER_REGISTRY} --username ${DOCKER_USER} --password-stdin

if [ -d chatcrm-docker-acme ] && [ -f chatcrm-docker-acme/docker-compose.yaml ] ; then
  cd chatcrm-docker-acme
elif [ -f docker-compose.yaml ] ; then
  ## nothing to do, already here
  echo -n "" > /dev/null
elif [ "${SUDO_USER}" = "root" ] ; then
  if [ -d /root/chatcrm-docker-acme ] ; then
    cd /root/chatcrm-docker-acme || exit 1
  else
    echo "Diretório chatcrm-docker-acme não encontrado"
    exit 1
  fi
else
  if [ -d /home/${SUDO_USER}/chatcrm-docker-acme ] ; then
      cd /home/${SUDO_USER}/chatcrm-docker-acme || exit 1
  else
      echo "Diretório chatcrm-docker-acme não encontrado"
      exit 1
  fi
fi

echo "Working on $PWD/chatcrm-docker-acme folder"

if ! [ -f docker-compose.yaml ] ; then
  echo "docker-compose.yaml não encontrado" > /dev/stderr
  exit 1
fi

if [ -n "${BRANCH}" ] ; then
  if ! git diff --quiet; then
    echo "Salvando alterações locais com git stash push"
    git stash push &> /dev/null
  fi

  echo "Atualizando repositório"
  git fetch

  echo "Alterando para a branch ${BRANCH}"
  if git rev-parse --verify ${BRANCH}; then
    git checkout ${BRANCH}
  else
    if ! git checkout --track origin/$BRANCH; then
      echo "Erro ao alternar para a branch ${BRANCH}"
      exit 1
    fi
  fi
fi

if git diff --quiet; then
  echo "Trazendo updates da branch ${BRANCH}"
  git pull &> /dev/null
else
  echored "                                               "
  echored "  A T E N Ç Ã O                                "
  echored "                                               "
  echored "  Você tem alterações locais, isso impede a    "
  echored "  obtenção de atualizações do repositório da   "
  echored "  stack.                                       "
  echored "                                               "
  echored "  É aconselhado reverter para voltar a seguir  "
  echored "  as configurações publicadas no projeto.      "
  echored "                                               "
  echored "  Aguarde 20 segundos para prosseguir...       "
  echored "                                               "
  echored "  ...ou Aperte CTRL-C para cancelar            "
  echored "                                               "
  sleep 20
fi

echo "Baixando novas imagens"
docker compose pull || show_error "Erro ao baixar novas imagens"

echo "Finalizando containers"
docker compose down || show_error "Erro ao finalizar containers"

echo "Inicializando containers"
docker compose up -d || show_error "Erro ao iniciar containers"

echo -e "\nSeu sistema já deve estar funcionando"

echo "Removendo imagens anteriores..."
docker system prune -af &> /dev/null

echo "Concluído"
