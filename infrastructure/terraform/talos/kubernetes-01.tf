# Ref: https://github.com/siderolabs/contrib/blob/main/examples/terraform/basic/main.tf
# Ref: talosctl -n <IP> -e <IP>  disks --insecure

locals {

  ####################################################
  # TODO
  ####################################################
  kubernetes_01_reusable_vars = {
    cluster_name          = "kubernetes-01"
    controlplane_endpoint = "https://kubernetes-01.internal.place:6443"
    cert_sans = [
      # Authorize local hostnames as TalosCTL seems to use them to upgrade from inside
      "localhost",
      "127.0.0.1",

      # Authorize all the nodes' hostnames to query Kube Apiserver
      "compute-11.internal.place",
      "compute-13.internal.place",
      "compute-21.internal.place",
      "compute-22.internal.place",
      "compute-31.internal.place",
      "compute-32.internal.place",
      "kubernetes-01.internal.place",
    ]
    pod_subnets     = ["10.90.0.0/16"]
    service_subnets = ["10.96.0.0/16"]
  }

  ####################################################
  # TODO
  ####################################################
  kubernetes_01_config = {

    # TODO
    globals = {

      talos = {
        # Version contract used to generate the machine configuration. Talos 1.14
        # generates multi-document configs that conflict with the templates.
        config_version = "v1.13.13"
        # Full installer image reference. Talos 1.14 is only published through the
        # Image Factory, and the schematic is the empty one (no extensions).
        image = "factory.talos.dev/metal-installer/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba:v1.14.7"
      }

      # This determines the Kubernetes version launched by Talos.
      # Remember that each Talos version supports several Kubernetes versions.
      kubernetes = {
        version = "v1.33.0"
      }

      config = {
        cluster_name          = local.kubernetes_01_reusable_vars.cluster_name
        controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
      }
    }

    # TODO
    nodes_data = {
      controlplanes = {
        compute-11 = {
          node_address = "192.168.2.11"
          config_template_vars = {
            hostname              = "compute-11"
            install_disk          = "/dev/sda"
            cluster_name          = local.kubernetes_01_reusable_vars.cluster_name
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        },
        compute-21 = {
          node_address = "192.168.2.21"
          config_template_vars = {
            hostname              = "compute-21"
            install_disk          = "/dev/sda"
            cluster_name          = local.kubernetes_01_reusable_vars.cluster_name
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        }
        compute-31 = {
          node_address = "192.168.2.31"
          config_template_vars = {
            hostname              = "compute-31"
            install_disk          = "/dev/sda"
            cluster_name          = local.kubernetes_01_reusable_vars.cluster_name
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        }
      }
      workers = {
        compute-13 = {
          node_address = "192.168.2.13"
          config_template_vars = {
            hostname              = "compute-13"
            install_disk          = "/dev/sda"
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        },
        compute-22 = {
          node_address = "192.168.2.22"
          config_template_vars = {
            hostname              = "compute-22"
            install_disk          = "/dev/sda"
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        }
        compute-32 = {
          node_address = "192.168.2.32"
          config_template_vars = {
            hostname              = "compute-32"
            install_disk          = "/dev/sda"
            cert_sans             = local.kubernetes_01_reusable_vars.cert_sans
            pod_subnets           = local.kubernetes_01_reusable_vars.pod_subnets
            service_subnets       = local.kubernetes_01_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_01_reusable_vars.controlplane_endpoint
          }
        }
      }
    }
  }

}

# Create the workload resources in the target host through SSH
module "talos_kubernetes_01" {

  source = "../modules/talos-cluster"

  globals   = local.kubernetes_01_config.globals
  node_data = local.kubernetes_01_config.nodes_data
}

output "kubeconfig_kubernetes_01" {
  sensitive = true
  value     = module.talos_kubernetes_01.kubeconfig
}

output "talosconfig_kubernetes_01" {
  sensitive = true
  value     = module.talos_kubernetes_01.talosconfig
}
