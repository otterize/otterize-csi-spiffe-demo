# Otterize with cert-manager CSI Driver SPIFFE

This is a demo repository that builds upon the Kubecon EU 2023 [talk](https://kccnceu2023.sched.com/event/1HyVN/cert-manager-can-do-spiffe-solving-multi-cloud-workload-identity-using-a-de-facto-standard-tool-thomas-meadows-jetstack-joshua-van-leeuwen-diagrid) of [Josh van Leeuwen](https://github.com/JoshVanL) and [Thomas Meadows](https://github.com/ChaosInTheCRD) where they presented how you could leverage cert-manager with its CSI Driver SPIFFE to authenticate to AWS by using IAM Roles Anywhere. The prior work they did for the talk can be found in the following [GitHub repository](https://github.com/JoshVanL/kubecon-2023-spiffe).

This demo will setup cert-manager and its [CSI Driver SPIFFE](https://cert-manager.io/docs/usage/csi-driver-spiffe/) in a non-AWS Kubernetes cluster. [Otterize](https://docs.otterize.com/overview/installation) will be setup in the same Kubernetes cluster and will use the cert-manager CSI Driver SPIFFE to authenticate to AWS and [automate](https://docs.otterize.com/features/aws-iam/tutorials/aws-iam-eks) creation of AWS roles and policies of different workloads running in that non-AWS Kubernetes clysters.

## Prerequisites

* [Helm](https://helm.sh/docs/intro/install/)
* [cmctl](https://cert-manager.io/docs/reference/cmctl/)
* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

## Setup

1. Setup cert-manager and disable the automated `certificateRequest` approver. We disable the automated `certificateRequest` approver as we want to let CSI Driver SPIFFE manage the approver for SPIFFE certificates.

    ```bash
    helm repo add jetstack https://charts.jetstack.io --force-update

    helm upgrade -i -n cert-manager cert-manager jetstack/cert-manager \
      --set extraArgs={--controllers='*\,-certificaterequests-approver'} \
      --set installCRDs=true \
      --create-namespace
    ```

1. Setup a self-signed issuer and generate your own signing CA. This signing CA will need to be manually approved as we disabled the automated approver in the previous step.

    ```bash
    kubectl apply -f issuer.yaml
    cmctl approve -n cert-manager \
      $(kubectl get cr -n cert-manager -ojsonpath='{.items[0].metadata.name}')
    ```

1. Install the cert-manager CSI Driver SPIFFE. This uses the modified version of cert-manager CSI Driver SPIFFE that automatically authenticates to AWS.

    ```bash
    helm upgrade -i -n cert-manager cert-manager-csi-driver-spiffe jetstack/cert-manager-csi-driver-spiffe -f values.yaml --wait
    ```

1. We need to prepare a few bits directly on the AWS side to allow Otterize to connect from our Kubernetes cluster to AWS. The Terraform will setup the following:

    * Retrieve the public key of your CA from your Kubernetes cluster and define it as a trust anchor for IAM Roles Anywhere.
    * Setup IAM policy, role and IAM Role Anywhere policy for both the Otterize credentials and intents operator.
    * It will deploy all of this in the `eu-west-2` AWS region (you can change it in the variables, but don't forget to do the same in later steps)

    ```bash
    cd otterize-aws
    terraform init
    terraform apply
    cd ..
    ```

1. Capture the Terraform Outputs for later use

1. Setup Otterize with AWS Integration

    ```bash
    helm upgrade --install otterize otterize/otterize-kubernetes -n otterize-system --create-namespace \
        --set intentsOperator.operator.mode=defaultActive  \
        --set credentialsOperator.operator.repository=public.ecr.aws/e3b4k2v5 \
        --set credentialsOperator.operator.image=ekstutorial  \
        --set credentialsOperator.operator.tag=creds-operator-rolesanywhere \
        --set global.aws.enabled=true \
        --set intentsOperator.aws.roleARN=<otterize-intents-operator-role-arn from Terraform output> \
        --set credentialsOperator.aws.roleARN=<otterize-credentials-operator-role-arn from Terraform output>
    ```

1. Run these commands to update resources necessary for the Otterize operator to function, this will be moved to the Helm chart soon.

    ```bash
    kubectl label mutatingwebhookconfiguration/otterize-credentials-operator-mutating-webhook-configuration app.kubernetes.io/component=credentials-operator app.kubernetes.io/part-of=otterize
    ```

1. Give Otterize Kubernetes Service Accounts (intents and credentials operators) the permission to create cert-manager certificaterequests. This is required as the cert-manager CSI SPIFFE Driver impersonates the Kubernetes Service Account through the [CSI Token Request](https://kubernetes-csi.github.io/docs/token-requests.html)

    ```bash
    kubectl apply -f rbac.yaml
    ```

1. To make Otterize work with the cert-manager CSI driver, we need to patch both the intents and credentials controllers of Otterize. **Make sure to add the correct values you got from your Terraform outputs into this patch file.**. This patch will do the following:

    * Add the cert-manager CSI Driver SPIFFE to both the credentials and intents controller
    * Set the necessary references to the AWS IAM roles & AWS IAM Anywhere Trust Anchor & profiles

    ```bash
    kubectl patch deployment credentials-operator-controller-manager -n otterize-system --patch-file credentials-operator-patch.yaml
    kubectl patch deployment intents-operator-controller-manager -n otterize-system --patch-file intents-operator-patch.yaml
    ```

1. Create S3 bucket and deploy demo application

    ```bash
    export BUCKET_NAME=otterize-tutorial-bucket-`date +%s`
    echo $BUCKET_NAME
    aws s3api create-bucket --bucket $BUCKET_NAME --region eu-west-2 --create-bucket-configuration LocationConstraint=eu-west-2
    kubectl create namespace otterize-tutorial-iam
    kubectl apply -n otterize-tutorial-iam -f https://docs.otterize.com/code-examples/aws-iam-eks/client-and-server.yaml
    kubectl patch deployment -n otterize-tutorial-iam server --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/containers/0/env\", \"value\": [{\"name\": \"BUCKET_NAME\", \"value\": \"$BUCKET_NAME\"}]}]"
    ```

1. Watch logs of the server and look at credentials errors. The errors are normal as we haven't let Otterize know it needs to manage access for this workload to AWS.

    ```bash
    kubectl logs -f -n otterize-tutorial-iam deploy/server
    ```

1. Add the label to let Otterize create the IAM role and create an Otterize ClientIntent. **Make sure to change to the correct S3 Bucket Name in the ClientIntent.**

    ```bash
    kubectl patch deployment -n otterize-tutorial-iam server -p '{"spec": {"template":{"metadata":{"labels":{"credentials-operator.otterize.com/create-aws-role":"true"}}}} }'
    kubectl apply -f intent.yaml
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
