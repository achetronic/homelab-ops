# Homelab Ops

<img src="https://raw.githubusercontent.com/achetronic/homelab-ops/main/docs/img/logo.png" alt="Homelab Ops Logo (Main) logo." align="center" width="144px" height="144px"/>

[//]: # (![GitHub]&#40;https://img.shields.io/github/license/achetronic/homelab-ops&#41;)

![YouTube Channel Subscribers](https://img.shields.io/youtube/channel/subscribers/UCeSb3yfsPNNVr13YsYNvCAw?label=achetronic&link=http%3A%2F%2Fyoutube.com%2Fachetronic)
![X (formerly Twitter) Follow](https://img.shields.io/twitter/follow/achetronic?style=flat&logo=twitter&link=https%3A%2F%2Ftwitter.com%2Fachetronic)

Mono repository to manage infrastructure present at my home

> Consider [contributing](#how-to-contribute)

## 📖 Overview

This is how I manage my home lab. From infrastructure code managing base things such as: internal domains in the router 
or VMs on hypervisor; to how I manage Kubernetes clusters over that. Glue automations between all the technologies 
are covered too, as I'm too lazy to do the same twice.

## 📐 Diagram

TBD

## 🧁 Hardware

| Device      | Count | OS Disk Size | Data Disk Size | CPU Arch | CPU cores  | Ram  | Operating System              | Purpose             |
|-------------|-------|--------------|----------------|----------|------------|------|-------------------------------|---------------------|
| Generic     | 1     | 128G NVMe    | -              | AMD64    | 4c (4th)   | 8GB  | OPNsense                      | Router              |
| Generic     | 1     | 128G NVMe    | -              | AMD64    | 8c (16th)  | 32GB | Ubuntu (KVM + Qemu + Libvirt) | Virtualization Host |
| Generic     | 1     | 256G NVMe    | 3x1TB HDD      | AMD64    | 8c (16th)  | 16GB | TrueNAS Scale                 | NAS                 |
| Odroid M1   | 3     | 256G NVMe    | -              | ARM64    | 4c (4th)   | 8GB  | Ubuntu                        | Kubernetes master   |
| Orange Pi 5 | 2     | 256G NVMe    | -              | ARM64    | 8c (8th)   | 16GB | Ubuntu                        | Kubernetes worker   |

## 🛰️ Networking

| Name                 | CIDR                                                                                          | IP range          |
|----------------------|-----------------------------------------------------------------------------------------------|-------------------|
| Compute Nodes        | `192.168.2.10/31`, `192.168.2.12/30`, `192.168.2.16/29`, `192.168.2.24/30`, `192.168.2.28/31` | 192.168.2.10 - 29 |
| Storage Nodes        | `192.168.2.30/31`, `192.168.2.32/29`, `192.168.2.40/32`                                       | 192.168.2.30 - 40 |
| Kubernetes LBs (BGP) | `192.168.2.60/30`, `192.168.2.64/28`, `192.168.2.80/32`                                       | 192.168.2.60 - 80 |
| -                    | -                                                                                             | -                 |
| Kubernetes pods      | `10.90.0.0/16`                                                                                |                   |
| Kubernetes services  | `10.96.0.0/16`                                                                                |                   |

## ☁️ Cloud resources

While most of my infrastructure and workloads are self-hosted, I do rely upon the cloud for certain key parts of my setup. 
This saves me from having to worry about several things:

* Dealing with chicken/egg scenarios
* Services I critically need to monitor my cluster

The alternative solution to these problems would be to host a Kubernetes cluster in the cloud and deploy applications 
like [Hashicorp Vault], [Ntfy], and [Gatus]. 

However, maintaining another cluster and monitoring another group of workloads is a lot more time and effort, 
which is not worth for a homelab.

| Service      | Use                                           | Cost         |
|--------------|-----------------------------------------------|--------------|
| [Gitlab]     | Storing Terraform states. Storing secrets (*) | Free         |
| [Cloudflare] | Domain, DNS and proxy management              | Free         |
| [GitHub]     | Hosting this repository and CI/CD             | Free         |
|              |                                               | Total: $0/mo |

* *: This repo uses **Gitlab project's CI/CD variables** as a vault for infrastructure secrets, as Gitlab allows 
   storing and retrieving them by calling the API.

## 🏗️ Infrastructure

I use [Terraform] to provision resources in several systems. 

Some of them, need credentials. To know how credentials are retrieved, see [Cloud Resources](#-cloud-resources)

> Due to recent changes in the Terraform license, this repository will use [OpenTofu]
> in the near future as a replacement.

### Terragrunt

[Terragrunt] is a Terraform wrapper that provides extra tools for keeping Terraform configurations dry. 

This allowed me to improve the UX related to how Terraform use environment variables or state backends
and do less dirty tricks on Terraform code.

### Router

Code is used to manage router's stuff related to my rack. The key is treating the router as a networking cloud provider.

* Internal domains assigned to specific machines: 
  * ARM64 SBCs, hypervisor, VMs: `compute-xx.internal.place`
  * NAS: `storage-xx.internal.place`

* Internal domains assigned to Kubernetes
  * Ingress Controller `*.tools.internal.place`

* Firewall rules: forward Wireguard traffic to Wireguard server

* More things in the future. Some of them are already configured (ie: BGP to point k8s LBs to the right machines) but
  provider currently in use is not supporting them yet. 

This could change in the future as it depends on the evolution of this [OPNsense Terraform provider]:

You can inspect the code [here](infrastructure/terraform/opnsense)

### Virtual Machines

Code is also used to create VMs on the hypervisor. Hypervisor is using very simple and robust virtualization
technologies like KVM, Qemu and Libvirt. The main advantage of managing it directly with code is using the most
available resources for the actual VMs.

VMs were previously managed using [metal-cloud], an opensource Terraform module crafted on my own to declare 
groups of VMs with ease on hosts that are using that stack. Those VMs are configured with cloud-init.

> Hey! I keep developing [metal-cloud], so if you find some bug, or whatever, please, open an issue there

Some months ago I decided to migrate my Kubernetes clusters to [Talos] (immutable, configured through an API). 
So currently I am using a different module due to Talos requires that machines are configured in a different way.

You can inspect the code [here](infrastructure/terraform/vms)

## 🐳 Kubernetes

My cluster is currently using [Talos], and its configurations are applied through the official [Talos Terraform provider], 
as it allows creating and configuring clusters without intermediate manual intervention.

### Primary

Primary cluster is called `kubernetes-01` and is running on AMD64 VMs machines hosted on a Linux hypervisor 
(KVM + QEMU + Libvirt) as compatibility is important for me. This is a semi hyper-converged cluster as workloads are 
sharing the same available resources while I have a separate server for data storage.

> I will increase resiliency in the near future spreading VMs across several hypervisors

### Secondary

Secondary cluster is called `kubernetes-02` and is provisioned overtop VMs as a temporary alternative 
for doing crazy experiments before optimizing whatever is needed.

## 🤖 Automations

It's a super common practice to use a makefile and Bash scripts to automate everything. 
However, this is not the best way to manage automation for this repository, as there are modern ways to 
do exactly the same. The requirements for a candidate are:

* Able to use Bash scripts where needed
* Replacing makefile with something easier to read
* Using YAML manifests

Bingo! I decided to use [Taskfile]

Just install the CLI from its [releases page](https://github.com/go-task/task/releases) and execute the following
command from the root of the repository to list available tasks I have created for this repository:

```console
task -l
```

To see the scripts executed under the hoods, it's only needed to look into the right [place](Taskfile.yaml) 
(or [places](.taskfiles))

The way I organized the files implies being able to execute commands present on files into [.taskfiles](.taskfiles) 
directory in an independent way. At the same time, they can be combined to craft complex commands in the global scope. 
This complex commands is what I call `glue` commands.
This way things are not mixed everywhere.

## How to use it

Every good story starts with something small. This time is about bootstrapping everything that is needed: 

```console
task global:init
```

After that, it's needed to connect with Gitlab

```console
task gitlab:login
```

What about getting some superpowers to provision infrastructure getting secrets from Gitlab?

```console
task gitlab:generate-supertoken TOKEN_NAME=supertoken

task terragrunt:apply-opnsense GITLAB_ACCESS_TOKEN_NAME=supertoken
task terragrunt:apply-vms GITLAB_ACCESS_TOKEN_NAME=supertoken
```

The story ending is about discovery the rest of really well documented tasks

```console
task -l
```

Once you have finished, don't forget about revoking your superpowers

```console
task gitlab:revoke-token TOKEN_NAME=supertoken
task global:cleanup
```

## How to contribute

This repository is the final result of continuous failures so is intended to be used as a reference. 
Because of that, code collaborations are not allowed at this point, but there are other ways to collaborate:

* 🔖 Open issues to discuss what can be improved
* 🧲 Fork the repository: use it or modify it for your own infrastructure with the half of the effort
* 🌟 Give a star to make it more visible to others

## License

Copyright 2022.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Special mention

This project was done using IDEs from JetBrains. They helped us to develop faster, so we recommend them a lot! 🤓

<img src="https://resources.jetbrains.com/storage/products/company/brand/logos/jb_beam.png" alt="JetBrains Logo (Main) logo." width="150">

[//]: #

[Taskfile]: <https://taskfile.dev/>
[Terragrunt]: <https://terragrunt.gruntwork.io/>
[metal-cloud]: <https://github.com/achetronic/metal-cloud>
[OPNsense Terraform provider]: <https://registry.terraform.io/providers/browningluke/opnsense/latest/docs>
[Talos Terraform provider]: <https://registry.terraform.io/providers/siderolabs/talos/latest/docs>
[Talos]: <https://www.talos.dev/>
[OpenTofu]: <https://github.com/opentofu/opentofu>
[Terraform]: <https://github.com/hashicorp/terraform>
[Hashicorp Vault]: <https://www.vaultproject.io/>
[Gitlab]: <https://gitlab.com>
[Cloudflare]: <https://www.cloudflare.com/>
[GitHub]: <https://github.com/>
[Ntfy]: <https://ntfy.sh/>
[Gatus]: <https://gatus.io/>
