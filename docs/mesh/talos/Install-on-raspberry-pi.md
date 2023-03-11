git add# Add additional certificate SANs to Kubernetes with Talos Linux


## Short introduction

This guide will explain how to add additional cluster certificates. This is useful if you want to access the Kubernetes API outside of the network where it is installed, for example over a DNS record.

{{< admonition tip >}}
You can do this before installing Talos, or if you have already installed it, do it with `talosctl edit machineconfig`.
{{< /admonition >}}

## Configuration

This configuration has to be done only on the **control plane** node, as we are not configuring the API server on worker nodes. Here is the configuration (click to expand):

```yaml
cluster:
  apiServer:
        # Extra certificate subject alternative names for the API server's certificate.
        certSANs:
            - 192.168.0.241
            - example.com # This is the additional certificate.
```

