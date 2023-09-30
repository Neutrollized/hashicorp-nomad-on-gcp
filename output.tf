output "consul_url" {
  value = "http://${google_compute_global_forwarding_rule.consul.ip_address}"
}

output "nomad_url" {
  value = "http://${google_compute_global_forwarding_rule.nomad.ip_address}"
}

output "bootstrapping_nomad" {
  value = <<EOT
gcloud compute instances list 

gcloud compute ssh [NOMAD_SERVER_NAME] --zone [NOMAD_SERVER_ZONE] --project ${var.project_id} --command "nomad acl bootstrap"
EOT
}
