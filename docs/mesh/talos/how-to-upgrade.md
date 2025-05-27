# Upgrading process

## Short introduction

Upgrading process is not well-documented on their website. I think they forgot to explain things for non talos developers.
Basically, I took the adventage of Talos being super hard to break (Yay for that!) to do some experiments and document
this for myself in the future

## Process

1. Be completely sure about following points:

   * Your `talosconfig.yaml` file includes, as endpoints, the domains or IPs pointing to your master nodes.
     Their Terraform provider tends to include only the machine hostnames. Get `talosconfig` from terraform outputs, 
     and change the endpoints to add mentioned domains.

     Spoiler: this is not valid because you are out of the machine, obviously. Remember this point as `talosctl`
     endpoints are read from the file.

   * Your Kubernetes cluster certificate must include `localhost` and `127.0.0.1` in its SANS. `talosctl` seems to perform
     some calls to the API, and it is THAT api which triggers all the process. Are those Talos machines-related certificates
     the same as used by Kubernetes? I dunno cause Talos is hermetic, but when they are not included, the process fails.

   * You MUST have odd number of etcd members to proceed: at least 3. This seems to be obvious but there is not a reminder
     at ANY part of the process. I started upgrading the workers, everything fine until started with the control-plane nodes:
     got an error from Talos: process can potentially break etcd quorum (and stopped)

2. Upgrade `talosctl` to the version you want. If possible upgrade minor by minor. By experience, you can jump all the
   patch versions at once.

3. Right AFTER previous points, you can trigger the following command:

   ```console
   talosctl --talosconfig talosconfig.yaml -n compute-13.internal.place upgrade --image ghcr.io/siderolabs/installer:v1.6.1
   ```

   > ONE NODE AT A TIME, if not, you can break the cluster
   > [Docs here](https://www.talos.dev/v1.8/talos-guides/upgrading-talos/)

4. Remember upgrading Talos version is not upgrading your Kuberneter cluster. To do that, just
   [follow this guide](https://www.talos.dev/v1.8/kubernetes-guides/upgrading-kubernetes/)