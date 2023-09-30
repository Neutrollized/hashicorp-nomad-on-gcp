output "consul_url" {
  value = "http://${google_compute_global_forwarding_rule.consul.ip_address}"
}

output "nomad_url" {
  value = "http://${google_compute_global_forwarding_rule.nomad.ip_address}"
}
