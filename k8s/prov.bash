#!/bin/bash

PROFILE_NAME:="dev"
LB_ADRESSES:=""
PROFILE:="dev"
INFRA_PATH:="infra"
APP_PATH:="apps"
NAMESPACE:="default"
APP_REPO:=""
INFRA_REPO:="https://github.com/turkelk/sh2-infra-apps"

errorExit () {
    echo -e "\nERROR: $1"; echo
    exit 1
}

usage () {
    cat << END_USAGE
 <options>
--repo              : [required] A git repo for application
--lb                : [required] Adresses for load balancers
--profile pr        : [optional] A profile name. Default is dev. Could be sit, uat, prod
--infra-path ip     : [optional] A custom infra app of apps path. Default is infra
--app-path app      : [optional] A custom business app of apps path. Default is apps
--ns                : [optional] A namespace to install argo apps. Default is default
--infra-repo        : [optional] A repo for infra
END_USAGE

    exit 1
}

processOptions () {
    # if [ $# -eq 0 ]; then
    #     usage
    # fi

    while [[ $# > 0 ]]; do
        case "$1" in
            --repo)
                APP_REPO=${2}; shift 2
            ;;
            --lb)
                LB_ADRESSES=${2}; shift 2
            ;;
            --profile)
                PROFILE=${2}; shift 2
            ;;
            --infra-path)
                INFRA_PATH=${2}; shift 2
            ;;
            --app-path)
                APP_PATH=${2}; shift 2
            ;; 
            --ns)
                NAMESPACE=${2}; shift 2
            ;;  
            --repo)
                APP_REPO=${2}; shift 2
            ;;  
            --infra-repo)
                INFRA_REPO=${2}; shift 2
            ;;                                                   
            -h | --help)
                usage
            ;;
            *)
                usage
            ;;
        esac
    done
}

startMinikube() {
  minikube start \
    --profile ${PROFILE} \
    --addons registry \
    --addons ingress \
    --addons metallb \
    --disk-size 40G \
    --memory 6G \
    --driver virtualbox

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses: [${LB_ADRESSES}]
EOF
}

# Install argocd
installArgo () {
  kubectl --context="${PROFILE_NAME}" create namespace argocd
  kubectl --context="${PROFILE_NAME}"  apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  kubectl --context="${PROFILE_NAME}" wait --for=condition=ready pod -l app=blog 
  # --timeout=60s
}

# Install argocd cli 
installArgoCli () {
  curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  chmod +x /usr/local/bin/argocd
}

# Create infra apps
argoLogin () {
  argocd login cd.argoproj.io --core
}
  
# Create infra apps
createInfraApps () {
  argocd app create infra \
  --repo {INFRA_REPO} \
  --path ${INFRA_PATH} \
  --dest-namespace {NAMESPACE} \
  --dest-server https://kubernetes.default.svc
  # --helm-set replicaCount=2
}

# Create business apps
createApps () {
  argocd app create apps \
  --repo {APP_REPO} \
  --path ${APP_PATH} \
  --dest-namespace {NAMESPACE} \
  --dest-server https://kubernetes.default.svc
}

main () {
    echo -e "\nRunning"

    echo "PROFILE_NAME: ${PROFILE_NAME}"
    echo "LB_ADRESSES:  ${LB_ADRESSES}"
    echo "PROFILE:      ${PROFILE}"
    echo "INFRA_PATH:   ${INFRA_PATH}"
    echo "APP_PATH:     ${APP_PATH}"
    echo "NAMESPACE:    ${NAMESPACE}"
    echo "GIT_REPO:     ${GIT_REPO}"    

    startMinikube    
    installArgo
    argoLogin
    installArgoCli
    createApps
    createInfraApps
}


processOptions $*
main

