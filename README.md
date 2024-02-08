# otterize-csi-spiffe

## Prerequisites

* Kubernetes
* Helm
* [cmctl](https://cert-manager.io/docs/reference/cmctl/)

## Setup instructions

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
