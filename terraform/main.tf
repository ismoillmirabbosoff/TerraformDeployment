terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.34.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.25.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.12.1"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}


provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.quantum_k8s_cluster.endpoint
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.quantum_k8s_cluster.kube_config.0.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "doctl"
    args = [
      "kubernetes",
      "cluster",
      "kubeconfig",
      "exec-credential",
      "--version=v1beta1",
      digitalocean_kubernetes_cluster.quantum_k8s_cluster.id
    ]
  }
}

provider "helm" {
  debug = true

  kubernetes {
    config_path            = "./kubeconfig"
    host                   = digitalocean_kubernetes_cluster.quantum_k8s_cluster.endpoint
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.quantum_k8s_cluster.kube_config.0.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "doctl"
      args = [
        "kubernetes",
        "cluster",
        "kubeconfig",
        "exec-credential",
        "--version=v1beta1",
        digitalocean_kubernetes_cluster.quantum_k8s_cluster.id
      ]
    }
  }
}

resource "digitalocean_kubernetes_cluster" "quantum_k8s_cluster" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.cluster_version
  tags    = ["k8s"]

  node_pool {
    name       = "worker-node"
    size       = var.node_size
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
  }
}


resource "helm_release" "cert-manager" {
  depends_on = [ digitalocean_kubernetes_cluster.quantum_k8s_cluster ]
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}


resource "helm_release" "nginx_ingress" {
  depends_on = [ digitalocean_kubernetes_cluster.quantum_k8s_cluster ]
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  
  set {
    name  = "controller.publishService.enabled"
    value = "true"
  }
}


resource "helm_release" "postgresql" {
  depends_on = [digitalocean_kubernetes_cluster.quantum_k8s_cluster]
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  
  values = [ "${file("../postgresql/psql-values.yml")}" ]
}

data "kubernetes_service_v1" "ingress_svc" {
  depends_on = [ helm_release.nginx_ingress ]
  metadata {
    name = var.nginx_svc_name
  }
}

output "my-kubeconfig" {
  value     = digitalocean_kubernetes_cluster.quantum_k8s_cluster.kube_config.0.raw_config
  sensitive = true
}
