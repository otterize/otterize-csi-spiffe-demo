# otterize-csi-spiffe

## Prerequisites

* Kubernetes
* Helm
* [cmctl](https://cert-manager.io/docs/reference/cmctl/)
* AWS CLI

## Setup instructions for cert-manager CSI Driver SPIFFE with Otterize

1. Setup cert-manager

    ```bash
    helm repo add jetstack https://charts.jetstack.io --force-update

    helm upgrade -i -n cert-manager cert-manager jetstack/cert-manager \
      --set extraArgs={--controllers='*\,-certificaterequests-approver'} \
      --set installCRDs=true \
      --create-namespace
    ```

1. Deploy and approve issuer (this is due to disabling the auto-approver)

    ```bash
    kubectl apply -f issuer.yaml
    cmctl approve -n cert-manager \
      $(kubectl get cr -n cert-manager -ojsonpath='{.items[0].metadata.name}')
    ```

1. Install CSI Driver SPIFFE

    ```bash
    helm upgrade -i -n cert-manager cert-manager-csi-driver-spiffe jetstack/cert-manager-csi-driver-spiffe -f values.yaml --wait
    ```

1. Setup AWS config

    ```bash
    # Modify variable.tf to match your config first
    cd otterize-aws
    terraform init
    terraform apply
    cd ..
    ```

1. Setup Otterize with AWS Integration

    ```bash
    helm upgrade --install otterize otterize/otterize-kubernetes -n otterize-system --create-namespace \
        --set global.otterizeCloud.credentials.clientId=<client-id>> \
        --set global.otterizeCloud.credentials.clientSecret=<client-secret> \
        --set intentsOperator.operator.mode=defaultActive  \
        --set credentialsOperator.operator.repository=public.ecr.aws/e3b4k2v5 \
        --set credentialsOperator.operator.image=ekstutorial  \
        --set credentialsOperator.operator.tag=creds-operator-rolesanywhere \
        --set global.aws.enabled=true \
        --set intentsOperator.aws.roleARN=<AWS ARN for intents operator role> \
        --set credentialsOperator.aws.roleARN=<AWS ARN for credential operator role>
    ```

1. Run these commands to update resources necessary for the operator to function (will be part of the Helm chart)

    ```bash
    kubectl label mutatingwebhookconfiguration/otterize-credentials-operator-mutating-webhook-configuration app.kubernetes.io/component=credentials-operator app.kubernetes.io/part-of=otterize
    ```

1. Give Otterize Kubernetes Service Accounts the permission to create cert-manager certificaterequests

    ```bash
    kubectl apply -f rbac.yaml
    ```

1. Patch the CSI Driver SPIFFE in the intents-controller and the credentials-controller and add environment variable to set the trust anchor on the credentials operator (make sure to change the arns)

    ```bash
    kubectl patch deployment credentials-operator-controller-manager -n otterize-system --patch-file credentials-operator-patch.yaml
    kubectl patch deployment intents-operator-controller-manager -n otterize-system --patch-file intents-operator-patch.yaml
    ```

1. Create S3 bucket and deploy demo application

    ```bash
    export BUCKET_NAME=otterize-tutorial-bucket-`date +%s`
    echo $BUCKET_NAME
    aws s3api create-bucket --bucket $BUCKET_NAME --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2
    kubectl create namespace otterize-tutorial-iam
    kubectl apply -n otterize-tutorial-iam -f https://docs.otterize.com/code-examples/aws-iam-eks/client-and-server.yaml
    kubectl patch deployment -n otterize-tutorial-iam server --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env\", \"value\": [{\"name\": \"BUCKET_NAME\", \"value\": \"$BUCKET_NAME\"}]}]"
    ```

1. Watch logs of the server and look at credentials errors

    ```bash
    kubectl logs -f -n otterize-tutorial-iam deploy/server
    ```

1. Add the label to let Otterize create the role

    ```bash
    kubectl patch deployment -n otterize-tutorial-iam server -p '{"spec": {"template":{"metadata":{"labels":{"credentials-operator.otterize.com/create-aws-role":"true"}}}} }'
    ```

## Setup instructions for cert-manager CSI Driver SPIFFE only

1. Setup cert-manager

    ```bash
    helm repo add jetstack https://charts.jetstack.io --force-update

    helm upgrade -i -n cert-manager cert-manager jetstack/cert-manager \
      --set extraArgs={--controllers='*\,-certificaterequests-approver'} \
      --set installCRDs=true \
      --create-namespace
    ```

1. Deploy and approve issuer (this is due to disabling the auto-approver)

    ```bash
    kubectl apply -f issuer.yaml
    cmctl approve -n cert-manager \
      $(kubectl get cr -n cert-manager -ojsonpath='{.items[0].metadata.name}')
    ```

1. Install CSI Driver SPIFFE

    ```bash
    helm upgrade -i -n cert-manager cert-manager-csi-driver-spiffe jetstack/cert-manager-csi-driver-spiffe -f values.yaml --wait
    ```

1. Make the AWS connection
      * Make sure to create a file `ca.pub` in the `terraform` folder with your CA public key. You can extract that from the TLS secret.
      * Make sure to update the variables.tf
      * Save the output variables for use in the next step

      ```bash
      cd terraform
      terraform init
      terraform apply
      cd ..
      ```

1. Deploy an application with CSI driver enabled
    * Make sure to replace the AWS specific ARNs with yours

    ```bash
    kubectl apply -f sandbox.yaml
    ```

1. Exec into pod

    ```bash
    kubectl exec -n sandbox -it <pod-name> -- /bin/bash
    ```

1. Get S3 file

    ```bash
    aws s3 cp s3://<bucket-name>/test.txt test.txt
    ```
