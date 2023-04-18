#!/bin/bash
MAX_ATTEMPTS=24
function install_operator()
{
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-gitops-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: openshift-gitops-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
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
oc apply -f - <<EOF
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: app-${1}
EOF

#create appproject
oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: app-${1}
  namespace: openshift-gitops
spec:
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  description: app-${1}
  destinations:
  - namespace: '*'
    server: '*'
  sourceRepos:
  - '*'
EOF

oc apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: app-${1}
  namespace: openshift-gitops
spec:
  generators:
  - clusters: {}
  template:
    metadata:
      name: app-${1}
    spec:
      destination:
        namespace: app-${1}
        server: https://kubernetes.default.svc
      ignoreDifferences:
      - jsonPointers:
        - /imagePullSecrets
        - /secrets
        kind: ServiceAccount
      project: app-${1}
      source:
        helm:
          valueFiles:
          - values.yaml
          - configmap.yaml
          - secrets.yaml
        path: devops/${1}
        repoURL: https://github.com/challenge-devsu/app.git
        targetRevision: ${2}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - Replace=false
        - PruneLast=true
EOF
}

install_operator
create_argo_things "dev" "develop"
create_argo_things "prd" "main"