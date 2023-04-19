#!/bin/bash
MAX_ATTEMPTS=24
function install_operator()
{
  oc apply -f files/installOperatorOpenshiftGitops.yaml
  for ((i=1; i<=MAX_ATTEMPTS; i++)); do
    operator_status=$(oc get pods -n openshift-operators -l control-plane=controller-manager -o jsonpath='{.items[*].status.phase}')
    if [ "$operator_status" == "Running" ]; then
        echo "OpenShift GitOps operator is running"
        return 0
    else
        echo "OpenShift GitOps operator is not running (status: $operator_status)"
    fi
    sleep 5
  done
  echo "Problem OpenShift GitOps operator is not running"
  exit 3
}

function create_argo_things ()
{
  ENV=${1}
  BRANCH=${2}
  cat files/project.yaml | sed "s/__ENV__/${ENV}/g" | oc apply -f - 
  cat files/appProject.yaml | sed "s/__ENV__/${ENV}/g" | oc apply -f -
  cat files/applicationSet.yaml | sed "s/__ENV__/${ENV}/g" | sed "s/__BRANCH__/${BRANCH}/g" | oc apply -f -
  
}

install_operator
create_argo_things "dev" "develop"
create_argo_things "prd" "main"