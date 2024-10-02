# Tetragon on Nomad
`nomad run tetragon.nomad` to deploy Tetragon service.  Other YAML files included here are examples of Tracing Policies. 

See my [Medium article](https://medium.com/@glen.yu/can-you-run-tetragon-on-hashicorp-nomad-part-1-8d51b2d23ee3) for a more detailed guide to running Tetragon on Nomad.


## Setup
I have an accompanying [repo](https://github.com/Neutrollized/packer-gcp-with-githubactions) which builds the GCE VM Images used in this deployment.  It various configs in there already includes the settings neccessary for this Nomad deployment.  Below are some notes to help you understand why they're there:

### Privleged settings
```
      config {
        image = "quay.io/cilium/tetragon:v1.1.0"
        args  = [
          "--export-filename",
          "/var/log/tetragon/tetragon.log",
        ]

        privileged   = true
        #network_mode = "host"
        #pid_mode     = "host" 
      }
```
- `privileged = true` is required (also requires a [setting](https://developer.hashicorp.com/nomad/tutorials/stateful-workloads/stateful-workloads-csi-volumes?in=nomad%2Fstateful-workloads#enable-privileged-docker-jobs) in the Nomad client's config to be enabled)
- `network_mode` and `pid_mode` can both be left disabled/default (which I recommend as it would be good security practice since it's not necessary)

### Volume mount
There are a couple of required **host** volume mounts which need to be specified in the Nomad client's config in order for it to be mounted in the container.  One is read-only, other is read-write:

- `/sys/kernel/btf/vmlinux` (read-only)
- `/var/log/tetragon/` (read-write, to persist logs)


### Networking
Unlike Kubernetes, which has separate/secondary pod and services CIDRs, Nomad operate on a node level.  As such, the Tetragon agents operate independently of each other.  If you want to see the events for a particular node, you have to check the export stdout logs for that particular node (or look at your central logging -- in my example, that's GCP's [Cloud Logging](https://cloud.google.com/logging) service).

Hence, you don't need a network section as Tetragon agents don't talk to each other per se:
```
    network {
      port "gprc" { to = 54321 }
      port "operator" { to = 2113 }
      port "metrics" { to = 2112 }
    }
```


## Tracing Policies
For the most part, Tetragon Tracing Policies written for Kubernetes will work the same in Nomad with some differences:
- Nomad namespaces aren't recognized, so Tracing Policies are **cluster wide**
- policies involving networking need to be tested as fundamental differences in how networking operates in Nomad vs. Kubernetes can cause unexpected behavior
- Docker's bridge network subnet CIDR needs to be included/accounted for when creating Tracing Policies involving source and destination addresses 
- Blocking Internet egress will prevent Nomad job deployments as well as the block occurs at a node level in Nomad vs in Kubernetes.  The workaround is to add another requirement to the policy to specify that the source address has to come from Docker's bridge network

### Deployment
Tracing Policy deployment is very simple and simply requires the policies to be in a specific folder location within the Tetragon agent when it starts.  While you *can* run Tetragon as a systemd service, this makes updating policies a bit more tedious vs redeploying the Nomad jobspec.

The way I chose to do this is put my Tracing Policies in a public GCS bucket and use Nomad's [artifact](https://developer.hashicorp.com/nomad/docs/job-specification/artifact) block to pull down the files to the `local/` directory and then mount each file (policy) into the desired path. 


## Google Cloud Logging
The logs are sent to GCP via the google-fluentd to Cloud Logging:
```
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
```

You can query for specific entries from GCE VM logs by querying their respective policy names:
```
resource_type="gce_instance"
jsonPayload.log:"\"policy_name\":\"block-internet-egress\""
```

The query above searches for entries where the `jsonPayload.log` contains `"policy_name":"block-internet-egress"`.  Alternatively, you can query for all entries where the policy name begins with `block-`:
```
resource_type="gce_instance"
jsonPayload.log:"\"policy_name\":\"block-"
```
