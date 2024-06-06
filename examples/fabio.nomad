job "fabio" {
  datacenters = ["gcp-ca-east"]
  type = "system"

  group "fabio" {
    network {
      port "ui" { static = 9998 }
      port "lb" { static = 9999 }
    }

    task "fabio" {
      driver = "docker"

      env {
        FABIO_proxy_strategy = "rr"
      }

      config {
        # https://hub.docker.com/r/fabiolb/fabio/tags
        image = "fabiolb/fabio:1.6.3"
        network_mode = "host"
        ports = ["lb", "ui"]
      }

      resources {
        cpu    = 200
        memory = 128
      }
    }
  }
}
