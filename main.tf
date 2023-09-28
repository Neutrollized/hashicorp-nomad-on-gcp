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
  can_ip_forward       = false

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

    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
  IP=$(curl -s -H "Metadata-Flavor: Google" "metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")

  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/server.hcl
  sed -i -e 's/{SERVER_COUNT}/${var.consul_server_count}/g' /etc/consul.d/server.hcl

  sed -i -e 's/{CLOUD}/gcp/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{ENV}/${var.environment}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{REGION}/${var.region}/g' /etc/consul.d/consul.hcl
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


###---------------------------
# Nomad Servers
#-----------------------------
resource "google_compute_region_instance_template" "nomad_server" {
  name        = "nomad-server-template"
  description = "Managed by Terraform."

  tags = [var.nomad_server_tag]

  instance_description = "Nomad server"
  machine_type         = var.nomad_server_machine_type
  can_ip_forward       = false

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

    access_config {}
  }

  metadata = {
    startup-script = <<-EOF
  IP=$(curl -s -H "Metadata-Flavor: Google" "metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")

  sed -i -e 's/{CLOUD}/gcp/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{ENV}/${var.environment}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{REGION}/${var.region}/g' /etc/consul.d/consul.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{CONSUL_SERVER_TAG}/${var.consul_server_tag}/g' /etc/consul.d/consul.hcl

  sed -i -e 's/{CLOUD}/gcp/g' /etc/nomad.d/server.hcl
  sed -i -e 's/{ENV}/${var.environment}/g' /etc/nomad.d/server.hcl
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


###---------------------------
# Nomad Clients
#-----------------------------
resource "google_compute_region_instance_template" "nomad_client" {
  name        = "nomad-client-template"
  description = "Managed by Terraform."

  tags = [var.nomad_client_tag]

  instance_description = "Nomad client"
  machine_type         = var.nomad_client_machine_type
  can_ip_forward       = false

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

  sed -i -e 's/{CLOUD}/gcp/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{ENV}/${var.environment}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{REGION}/${var.region}/g' /etc/consul.d/consul.hcl
  sed -i -e "s/{PRIVATE_IPV4}/$${IP}/g" /etc/consul.d/consul.hcl
  sed -i -e 's/{GOSSIP_KEY}/${var.consul_gossip_key}/g' /etc/consul.d/consul.hcl
  sed -i -e 's/{CONSUL_SERVER_TAG}/${var.consul_server_tag}/g' /etc/consul.d/consul.hcl

  sed -i -e 's/{CLOUD}/gcp/g' /etc/nomad.d/client.hcl
  sed -i -e 's/{ENV}/${var.environment}/g' /etc/nomad.d/client.hcl
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
