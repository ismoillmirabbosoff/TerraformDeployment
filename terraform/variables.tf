variable "do_token" {}

variable "cluster_name" {
    type = string
    default = "quantum-k8s-cluster"
}
variable "cluster_region" {
    type = string
    default = "nyc1"
}
variable "cluster_version" {
    type = string
    default = "1.27.9-do.0"
}

variable "node_size" {
    type = string
    default = "s-4vcpu-8gb-amd"
}

variable "mongodb_replica_count" {
    type = string
    default = "1"
}

variable "nginx_svc_name" {
    type = string
    default = "nginx-ingress-ingress-nginx-controller"
}
