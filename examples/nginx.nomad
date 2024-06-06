job "nginx" {
  datacenters = ["gcp-ca-east"]

  group "nginx" {
    count = 1
    
    network {
      port "http"  { to = 80 }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:latest"
        ports = ["http"]
      }

      service {
        name = "nginx"
        tags = ["nginx", "webserver"]
        port = "http"
        check {
          name     = "HTTP check"
          type     = "http"
          interval = "10s"
          timeout  = "2s"
          path     = "/"
          method   = "GET"
        }
      }
    }

  }

}
