job "spring-music" {
  datacenters = ["gcp-ca-east"]

  group "spring-music" {
    network {
      port "access" { static = 28080 }
    }

    task "spring-music" {
      driver = "java"

      config {
        jar_path    = "spring-music-1.0.jar"
        jvm_options = ["-Xmx1024M", "-Xms1024M"]
        args        = ["--server.port=${NOMAD_PORT_access}"]
      }

      resources {
        cpu    = 500
        memory = 1152
      }

      artifact {
        source      = "https://storage.googleapis.com/public-file-server/spring-music-1.0.jar"
        mode        = "file"
        destination = "spring-music-1.0.jar"
      }

      service {
        name     = "spring-music"
        port     = "access"
        tags     = ["spring", "java"]
      }
    }
  }
}
