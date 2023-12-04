###---------------------------
# Nomad Clients
#-----------------------------
resource "google_compute_region_instance_template" "nomad_client" {
  name        = "nomad-client-template-${var.nomad_dc}"
  description = "Managed by Terraform."

  tags = [var.nomad_client_tag]

  instance_description = "Nomad client"
  machine_type         = var.nomad_client_machine_type
  can_ip_forward       = true

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.nomad_client.self_link
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"

    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
  IP=$(curl -s -H "Metadata-Flavor: Google" "metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")

  sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{CONSUL_SERVER_TAG}/${var.consul_server_tag}/g' /etc/consul.d/consul.hcl

  sed -i -e 's/{DATACENTER}/${var.nomad_dc}/g' /etc/nomad.d/client.hcl
  sed -i -e 's/{REGION}/${var.region}/g' /etc/nomad.d/client.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/nomad.d/client.hcl

  systemctl enable consul
  systemctl enable nomad

  systemctl start consul
  systemctl start nomad
  EOF
  }

  lifecycle {
    create_before_destroy = true
  }

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.nomad.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_region_instance_group_manager.nomad_server
  ]
}

resource "google_compute_region_instance_group_manager" "nomad_client" {
  name               = "nomad-client-igm-${var.nomad_dc}"
  base_instance_name = "nomad-client"
  region             = var.region
  target_size        = var.nomad_client_count

  named_port {
    name = "fabio-lb"
    port = 9999
  }

  version {
    name              = google_compute_region_instance_template.nomad_client.name
    instance_template = google_compute_region_instance_template.nomad_client.id
  }
}


#------------------
# Nomad LB
#------------------
resource "google_compute_global_address" "nomad_client" {
  count       = var.enable_fabio_lb ? 1 : 0
  name        = "nomad-client-ext-ip-${var.nomad_dc}"
  description = "External IP for Nomad LB"

  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "nomad_client" {
  provider = google-beta

  count                 = var.enable_fabio_lb ? 1 : 0
  name                  = "nomad-client-l7-forwarding-rule-${var.nomad_dc}"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.nomad_client[count.index].id
  ip_address            = google_compute_global_address.nomad_client[count.index].id
}

# http proxy
resource "google_compute_target_http_proxy" "nomad_client" {
  provider = google-beta

  count   = var.enable_fabio_lb ? 1 : 0
  name    = "nomad-client-l7-target-http-proxy-${var.nomad_dc}"
  url_map = google_compute_url_map.nomad_client[count.index].id
}

resource "google_compute_url_map" "nomad_client" {
  provider = google-beta

  count           = var.enable_fabio_lb ? 1 : 0
  name            = "nomad-client-l7-url-map-${var.nomad_dc}"
  default_service = google_compute_backend_service.nomad_client[count.index].id
}

resource "google_compute_health_check" "nomad_client" {
  provider = google-beta

  count       = var.enable_fabio_lb ? 1 : 0
  name        = "nomad-client-tcp-healthcheck-${var.nomad_dc}"
  description = "Health check via tcp"

  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port_name          = "fabio-lb"
    port_specification = "USE_NAMED_PORT"
  }
}

resource "google_compute_backend_service" "nomad_client" {
  provider = google-beta

  count                 = var.enable_fabio_lb ? 1 : 0
  name                  = "nomad-client-backend-${var.nomad_dc}"
  health_checks         = [google_compute_health_check.nomad_client[count.index].id]
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "fabio-lb"

  backend {
    group = google_compute_region_instance_group_manager.nomad_client.instance_group
  }
}
