# Introduction

To maintain infrastructure, some order is needed. The following sections describe
IP ranges used (and their corresponding CIDRs) and for what. 


# Compute nodes

These nodes are described as those nodes used to deploy applications. 
They can be bare metal or VMs, and can work as standalone or as part of a cluster.

> Obviously, more computing nodes are expected than those used for storage, so the range is wider

## Range
192.168.2.10 - 192.168.2.29

## CIDR
192.168.2.10/31
192.168.2.12/30
192.168.2.16/29
192.168.2.24/30
192.168.2.28/31


# Storage nodes

These nodes are described as those nodes used to store data. These nodes can be VMs or bare metal too,
as they can be running something like SeaweedFS, Ceph or things like TrueNas. As it is for domestic usage,
TrueNAS is preferred to keep data maintenance lower.

## Range
192.168.30 - 192.168.2.40

## CIDR
192.168.2.30/31
192.168.2.32/29
192.168.2.40/32


# Kubernetes LoadBalancers

These IPs will be used to automatically provision Kubernetes LoadBalancers from inside the clusters. 
They are used mainly to expose ingress controllers

## Range
192.168.2.60 - 192.168.2.80

## CIDR
192.168.2.60/30
192.168.2.64/28
192.168.2.80/32

# Ref: https://www.ipaddressguide.com/cidr