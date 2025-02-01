provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("C:/Users/kirub/Prathap/k8s_the_hard_way/vms/service-account.json")
}
