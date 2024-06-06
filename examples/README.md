# Examples

I've included some examples in here, but to deploy them, once you've connected/authenticated to your Nomad cluster, simply run `nomad run [JOBSPEC]`:

- `nomad run ./nginx.nomad` to start an NGINX webserver:
```
==> 2024-06-05T11:00:19-04:00: Monitoring evaluation "092a3b3c"
    2024-06-05T11:00:19-04:00: Evaluation triggered by job "nginx"
    2024-06-05T11:00:19-04:00: Evaluation within deployment: "09b5a33c"
    2024-06-05T11:00:19-04:00: Allocation "edace9e6" created: node "b840261d", group "nginx"
    2024-06-05T11:00:19-04:00: Evaluation status changed: "pending" -> "complete"
==> 2024-06-05T11:00:19-04:00: Evaluation "092a3b3c" finished with status "complete"
==> 2024-06-05T11:00:19-04:00: Monitoring deployment "09b5a33c"
  ✓ Deployment "09b5a33c" successful

    2024-06-05T11:00:38-04:00
    ID          = 09b5a33c
    Job ID      = nginx
    Job Version = 0
    Status      = successful
    Description = Deployment completed successfully

    Deployed
    Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
    nginx       1        1       1        0          2024-06-05T15:10:36Z
```
