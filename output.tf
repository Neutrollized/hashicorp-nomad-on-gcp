output "consul_url" {
  value = "http://${google_compute_global_forwarding_rule.consul.ip_address}"
}

output "nomad_url" {
  value = "http://${google_compute_global_forwarding_rule.nomad.ip_address}"
}

output "nomad_url_fabio_lb" {
  value = var.enable_fabio_lb ? "http://${google_compute_global_forwarding_rule.nomad_client[0].ip_address}" : "N/A - Fabio LB not enabled"
}
