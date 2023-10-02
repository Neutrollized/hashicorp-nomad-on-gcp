data "google_compute_image" "consul_server" {
  family  = "custom-consul-server"
  project = var.project_id
}

data "google_compute_image" "nomad_server" {
  family  = "custom-nomad-server"
  project = var.project_id
}

data "google_compute_image" "nomad_client" {
  family  = "custom-nomad-client"
  project = var.project_id
}


###---------------------------
# Consul Servers
#-----------------------------
resource "google_compute_region_instance_template" "consul_server" {
  name        = "consul-server-template"
  description = "Managed by Terraform."

  tags = [var.consul_server_tag]

  instance_description = "Consul server"
  machine_type         = var.consul_server_machine_type
  can_ip_forward       = true

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.consul_server.self_link
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
  }

  metadata = {
    startup-script = <<-EOF
  IP=$(curl -s -H "Metadata-Flavor: Google" "metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")

  sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/server.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/server.hcl
  sed -i -e 's/{SERVER_COUNT}/${var.consul_server_count}/g' /etc/consul.d/server.hcl

  sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{CONSUL_SERVER_TAG}/${var.consul_server_tag}/g' /etc/consul.d/consul.hcl

  systemctl enable consul

  systemctl start consul
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
}

resource "google_compute_region_instance_group_manager" "consul_server" {
  name               = "consul-server-igm"
  base_instance_name = "consul-server"
  region             = var.region
  target_size        = var.consul_server_count
  wait_for_instances = true

  named_port {
    name = "consul-ui"
    port = 8500
  }

  version {
    name              = google_compute_region_instance_template.consul_server.name
    instance_template = google_compute_region_instance_template.consul_server.id
  }
}


#------------------
# Consul LB
#------------------
resource "google_compute_global_address" "consul" {
  name        = "consul-ext-ip"
  description = "External IP for Consul LB"

  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "consul" {
  provider = google-beta

  name                  = "consul-l7-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.consul.id
  ip_address            = google_compute_global_address.consul.id
}

# http proxy
resource "google_compute_target_http_proxy" "consul" {
  provider = google-beta

  name    = "consul-l7-target-http-proxy"
  url_map = google_compute_url_map.consul.id
}

resource "google_compute_url_map" "consul" {
  provider = google-beta

  name            = "consul-l7-url-map"
  default_service = google_compute_backend_service.consul.id
}

resource "google_compute_health_check" "consul" {
  provider = google-beta

  name        = "consul-tcp-healthcheck"
  description = "Health check via tcp"

  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port_name          = "consul-ui"
    port_specification = "USE_NAMED_PORT"
  }
}

resource "google_compute_backend_service" "consul" {
  provider = google-beta

  name                  = "consul-backend"
  health_checks         = [google_compute_health_check.consul.id]
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "consul-ui"

  backend {
    group = google_compute_region_instance_group_manager.consul_server.instance_group
  }
}


###---------------------------
# Nomad Servers
#-----------------------------
resource "google_compute_region_instance_template" "nomad_server" {
  name        = "nomad-server-template"
  description = "Managed by Terraform."

  tags = [var.nomad_server_tag]

  instance_description = "Nomad server"
  machine_type         = var.nomad_server_machine_type
  can_ip_forward       = true

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
  }

  // Create a new boot disk from an image
  disk {
    source_image = data.google_compute_image.nomad_server.self_link
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
  }

  metadata = {
    startup-script = <<-EOF
  IP=$(curl -s -H "Metadata-Flavor: Google" "metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")

  sed -i -e 's/{DATACENTER}/${var.consul_dc}/g' /etc/consul.d/consul.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{CONSUL_SERVER_TAG}/${var.consul_server_tag}/g' /etc/consul.d/consul.hcl

  sed -i -e 's/{DATACENTER}/${var.nomad_dc}/g' /etc/nomad.d/server.hcl
  sed -i -e 's/{REGION}/${var.region}/g' /etc/nomad.d/server.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/nomad.d/server.hcl
  sed -i -e 's/{SERVER_COUNT}/${var.nomad_server_count}/g' /etc/nomad.d/server.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.nomad_gossip_key}/g' /etc/nomad.d/server.hcl

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
    google_compute_region_instance_group_manager.consul_server
  ]
}

resource "google_compute_region_instance_group_manager" "nomad_server" {
  name               = "nomad-server-igm"
  base_instance_name = "nomad-server"
  region             = var.region
  target_size        = var.nomad_server_count
  wait_for_instances = true

  named_port {
    name = "nomad-ui"
    port = 4646
  }

  version {
    name              = google_compute_region_instance_template.nomad_server.name
    instance_template = google_compute_region_instance_template.nomad_server.id
  }
}


#------------------
# Nomad LB
#------------------
resource "google_compute_global_address" "nomad" {
  name        = "nomad-ext-ip"
  description = "External IP for Nomad LB"

  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# forwarding rule
resource "google_compute_global_forwarding_rule" "nomad" {
  provider = google-beta

  name                  = "nomad-l7-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.nomad.id
  ip_address            = google_compute_global_address.nomad.id
}

# http proxy
resource "google_compute_target_http_proxy" "nomad" {
  provider = google-beta

  name    = "nomad-l7-target-http-proxy"
  url_map = google_compute_url_map.nomad.id
}

resource "google_compute_url_map" "nomad" {
  provider = google-beta

  name            = "nomad-l7-url-map"
  default_service = google_compute_backend_service.nomad.id
}

resource "google_compute_health_check" "nomad" {
  provider = google-beta

  name        = "nomad-tcp-healthcheck"
  description = "Health check via tcp"

  timeout_sec         = 5
  check_interval_sec  = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  tcp_health_check {
    port_name          = "nomad-ui"
    port_specification = "USE_NAMED_PORT"
  }
}

resource "google_compute_backend_service" "nomad" {
  provider = google-beta

  name                  = "nomad-backend"
  health_checks         = [google_compute_health_check.nomad.id]
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "nomad-ui"

  backend {
    group = google_compute_region_instance_group_manager.nomad_server.instance_group
  }
}


###---------------------------
# Nomad Clients
#-----------------------------
resource "google_compute_region_instance_template" "nomad_client" {
  name        = "nomad-client-template"
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
  name               = "nomad-client-igm"
  base_instance_name = "nomad-client"
  region             = var.region
  target_size        = var.nomad_client_count

  version {
    name              = google_compute_region_instance_template.nomad_client.name
    instance_template = google_compute_region_instance_template.nomad_client.id
  }
}
