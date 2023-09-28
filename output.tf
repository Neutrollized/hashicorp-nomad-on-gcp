output "nomad_bootstrap_command" {
  value = <<EOT
gcloud compute instances list 

gcloud compute ssh [NOMAD_SERVER_NAME] --zone [NOMAD_SERVER_ZONE] --project ${var.project_id} --command "nomad acl bootstrap"
EOT
}
