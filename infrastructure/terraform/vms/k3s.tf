locals {
  control_plane_nodes = {
    for instanceName, instanceData in local.instances :
    instanceName => instanceData if strcontains(instanceName, "master")
  }

  worker_nodes = {
    for instanceName, instanceData in local.instances :
    instanceName => instanceData if strcontains(instanceName, "worker")
  }
}

module "k3s" {
  source = "xunleii/k3s/module"
  version = "3.4.0"

  depends_on = [module.compute-01-virtual-machines]

  #depends_on_    = hcloud_server.agents
  k3s_version    = "v1.28.5+k3s1"
  cluster_domain = "cluster.local"
  cidr = {
    pods     = "10.90.0.0/16"
    services = "10.96.0.0/16"
  }
  drain_timeout  = "30s"
  managed_fields = ["label", "taint"] // ignore annotations

#  global_flags = [
#    "--flannel-iface ens10",
#    "--kubelet-arg cloud-provider=external" // required to use https://github.com/hetznercloud/hcloud-cloud-controller-manager
#  ]



  servers = {
    for instanceName, instanceData in local.control_plane_nodes :
    instanceName => {
      ip = instanceData.networks[0].address
      connection = {
        timeout     = "60s"
        type        = "ssh"
        host        = instanceData.networks[0].address
        user        = module.compute-01-virtual-machines.instances_information[instanceName].user
        password    = module.compute-01-virtual-machines.instances_information[instanceName].password
        #private_key = trimspace(module.compute-01-virtual-machines.)
      }
      flags = [
        "--disable-cloud-controller",
        "--tls-san=kubernetes-01.internal.place",
        "--disable-helm-controller",
        "--disable=traefik",
        "--disable=local-storage",
        "--disable=servicelb"
      ]
      #annotations = { "server_id" : i } // theses annotations will not be managed by this module
    }
  }

  agents = {
    for instanceName, instanceData in local.worker_nodes :
    instanceName => {
      name = instanceName
      ip   = instanceData.networks[0].address
      connection = {
        timeout     = "60s"
        type        = "ssh"
        host        = instanceData.networks[0].address
        user        = module.compute-01-virtual-machines.instances_information[instanceName].user
        password    = module.compute-01-virtual-machines.instances_information[instanceName].password
      }

      #labels = { "node.kubernetes.io/pool" = hcloud_server.agents[i].labels.nodepool }
      #taints = { "dedicated" : hcloud_server.agents[i].labels.nodepool == "gpu" ? "gpu:NoSchedule" : null }


    }
  }
}
