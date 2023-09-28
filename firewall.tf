data "google_netblock_ip_ranges" "health-checkers" {
  range_type = "health-checkers"
}


#------------------------------
# Firewall rules
#------------------------------
resource "google_compute_firewall" "lb_health_check" {
  name        = "allow-health-check"
  network     = "default"
  description = "Allow health checks from GCP LBs"

  direction = "INGRESS"

  allow {
    protocol = "tcp"
  }

  # https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
  source_ranges = data.google_netblock_ip_ranges.health-checkers.cidr_blocks_ipv4
}


resource "google_compute_firewall" "consul" {
  name        = "allow-consul"
  network     = "default"
  description = "Allow health checks from GCP LBs"

  direction = "INGRESS"

  # https://developer.hashicorp.com/consul/docs/install/ports#ports-table
  allow {
    protocol = "tcp"
    ports    = ["8300-8302", "8500-8503", "8600", "21000", "21255"]
  }

  allow {
    protocol = "udp"
    ports    = ["8301-8302", "8600"]
  }

  source_ranges = ["0.0.0.0/0"]
  #source_tags = [var.consul_server_tag, var.nomad_server_tag, var.nomad_client_tag]
  #target_tags = [var.consul_server_tag, var.nomad_server_tag, var.nomad_client_tag]
}

resource "google_compute_firewall" "nomad" {
  name        = "allow-nomad"
  network     = "default"
  description = "Allow health checks from GCP LBs"

  direction = "INGRESS"

  # https://developer.hashicorp.com/nomad/docs/install/production/requirements#ports-used
  allow {
    protocol = "tcp"
    ports    = ["4646-4648"]
  }

  allow {
    protocol = "udp"
    ports    = ["4648"]
  }

  source_ranges = ["0.0.0.0/0"]
  #source_tags = [var.consul_server_tag, var.nomad_server_tag, var.nomad_client_tag]
  #target_tags = [var.consul_server_tag, var.nomad_server_tag, var.nomad_client_tag]
}

resource "google_compute_firewall" "nomad_jobs" {
  name        = "allow-nomad-jobs"
  network     = "default"
  description = "Allow health checks from GCP LBs"

  direction = "INGRESS"

  # FabioLB ports 9998 and 9999
  # Nomad task dynamic port range 20000-32000
  allow {
    protocol = "tcp"
    ports    = ["9998-9999", "20000-32000"]
  }

  source_ranges = ["0.0.0.0/0"]
}
