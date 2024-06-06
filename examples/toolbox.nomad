job "toolbox" {
  datacenters = ["gcp-ca-east"]

  # this is a busybox container with some additional tools
  # on here typically used for debugging
  group "toolbox" {
    count = 1
    
    task "toolbox" {
      driver = "docker"

      config {
        image = "jacobmammoliti/toolbox"
      }
    }

  }
}
