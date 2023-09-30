# README
Deploying [HashiCorp Nomad](https://www.nomadproject.io/) cluster on Google Cloud [Compute Engine](https://cloud.google.com/compute) instances using custom VM images built using [Packer](https://www.packer.io/) as done in my repo [here](https://github.com/Neutrollized/packer-gcp-with-githubactions)

[Google Compute Image](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_image)

[Google Compute Region Instance Template](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_template)

[Google Compute Region Instance Group Manager](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_instance_group_manager)

[Google Cloud Load Balancing](https://cloud.google.com/load-balancing/docs/application-load-balancer)

This blueprint deploys a Consul server cluster, Nomad server cluster, and a few Nomad workers (or clients, as they're called) in the default VPC.

### Bootstrapping Nomad ACL
After deployment, you will have to ssh into the Nomad server to run `nomad acl bootstrap` to get the (root) bootstrap token. 

- example:
```console
gcloud compute ssh nomad-server-a1b2 \
  --zone northamerica-northeast1-c \
  --project myproject-123 \
  --command "nomad acl bootstrap"
```

- output:
```
Accessor ID  = 12345678-9abc-def1-2345-6789abcdef12
Secret ID    = abcdef12-3456-789a-bcde-f123456789ab
Name         = Bootstrap Token
Type         = management
Global       = true
Create Time  = 2023-09-03 04:30:12.602612696 +0000 UTC
Expiry Time  = <none>
Create Index = 15
Modify Index = 15
Policies     = n/a
Roles        = n/a
```

## NOTE
It can take a couple of minutes for the load balancer to confirm that all the backends are health and start serving traffic.  It may also take a few more for Consul to vote on a leader initially, so be patient.


## Additional Resources
- [Nomad the Hard Way](https://github.com/jacobmammoliti/nomad-the-hard-way)

If you would like to learn more about HashiCorp Nomad, check out my Medium articles below:
- [Getting started with HashiCorp Nomad just got easier in v1.4](https://medium.com/@glen.yu/getting-started-with-hashicorp-nomad-just-got-easier-in-v1-4-3ffd0ebf3ad3)
- [Migrating off of Cloud Foundry? Consider HashiCorp Nomad!](https://medium.com/@glen.yu/migrating-off-of-pivotal-cloud-foundry-consider-hashicorp-nomad-581ba603995f)
