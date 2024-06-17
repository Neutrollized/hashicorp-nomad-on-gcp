job "tetragon" {
  datacenters = ["gcp-ca-east"]
  type = "system"

  group "tetragon" {
    task "agent" {
      driver = "docker"

      # saved to local/ by default
      artifact {
        source      = "https://storage.googleapis.com/public-file-server/tetragon-tracing-policies/log-tcp-connect-and-close.yaml"
        mode        = "file"
        destination = "log-tcp-connect-and-close.yaml"
      }
      artifact {
        source      = "https://storage.googleapis.com/public-file-server/tetragon-tracing-policies/log-file-access.yaml"
        mode        = "file"
        destination = "log-file-access.yaml"
      }
      artifact {
        source      = "https://storage.googleapis.com/public-file-server/tetragon-tracing-policies/block-internet-egress.yaml"
        mode        = "file"
        destination = "block-internet-egress.yaml"
      }
      artifact {
        source      = "https://storage.googleapis.com/public-file-server/tetragon-tracing-policies/block-nginx-write-index.yaml"
        mode        = "file"
        destination = "block-nginx-write-index.yaml"
      }
      artifact {
        source      = "https://storage.googleapis.com/public-file-server/tetragon-tracing-policies/block-pkg-managers.yaml"
        mode        = "file"
        destination = "block-pkg-managers.yaml"
      }

      config {
        image = "quay.io/cilium/tetragon:v1.1.2"
        args  = [
          "--export-filename",
          "/var/log/tetragon/tetragon.log",
        ]

        privileged   = true
        #network_mode = "host"
        #pid_mode     = "host"

        volumes = [
#          "log-tcp-connect-and-close.yaml:/etc/tetragon/tetragon.tp.d/log-tcp-connect-and-close.yaml",
          "log-file-access.yaml:/etc/tetragon/tetragon.tp.d/log-file-access.yaml",
          "block-internet-egress.yaml:/etc/tetragon/tetragon.tp.d/block-internet-egress.yaml",
          "block-nginx-write-index.yaml:/etc/tetragon/tetragon.tp.d/block-nginx-write-index.yaml",
          "block-pkg-managers.yaml:/etc/tetragon/tetragon.tp.d/block-pkg-managers.yaml",
        ]
      }

      volume_mount {
        volume      = "sys-kernel-btf-vmlinux"
        destination = "/var/lib/tetragon/btf"
        read_only   = true
      }
      volume_mount {
        volume      = "var-log-tetragon"
        destination = "/var/log/tetragon/"
        read_only   = false
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "tetragon"
        tags = ["tetragon", "v1.1.2"]
      }
    }

    task "export-stdout" {
      driver = "docker"

      config {
        image = "quay.io/cilium/hubble-export-stdout:v1.0.4"
        privileged = false

        command = "export-stdout"
        args = ["/var/log/tetragon/tetragon.log"]

        logging {
          type = "fluentd"
          config {
            fluentd-address = "localhost:24224"
            tag = "tetragon"
          }
        }
      }

      volume_mount {
        volume      = "var-log-tetragon"
        destination = "/var/log/tetragon/"
        read_only   = false
      }

      resources {
        cpu    = 25
        memory = 32
      }
    }

    volume "sys-kernel-btf-vmlinux" {
      type      = "host"
      source    = "kernel-btf"
      read_only = true
    }
    volume "var-log-tetragon" {
      type      = "host"
      source    = "tetragon-logs"
      read_only = false
    }

  }
}
