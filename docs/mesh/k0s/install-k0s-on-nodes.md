# Install K0s on nodes

## Installation

### Pre-steps

Install k0sctl in the computer

```console
wget https://github.com/k0sproject/k0sctl/releases/download/v0.15.4/k0sctl-linux-x64 && \
sudo mv k0sctl-linux-x64 /usr/local/bin/k0sctl && \
sudo chmod +x /usr/local/bin/k0sctl
```
### Actually install the K0s

Generate the configuration

```console
k0sctl init --k0s > k0sctl.yaml
```

> Probably the configuration is already created inside k0s directory

Authorize 'root' user to login using password on all the servers iterating on them executing the following commands:

> Take into account that the default username may change depending on the distribution. 
> This username is commonly 'ubuntu' on odroid M1 boards and 'orangepi' on Orange Pi 5

```console
ssh server-username@compute-XX.internal.place

sudo passwd
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

Authorize your public SSH key on remote servers to configure

```console
ssh-copy-id root@compute-01.internal.place && \
ssh-copy-id root@compute-02.internal.place && \
ssh-copy-id root@compute-03.internal.place && \
ssh-copy-id root@compute-04.internal.place && \
ssh-copy-id root@compute-05.internal.place
```

Apply k0s config to the servers

```console
env SSH_KNOWN_HOSTS=/dev/null k0sctl apply --config k0sctl.yaml
```

> Some SBC manufacturers set the same machine ID for all the boards. This is problematic as K0s needs them 
> to be different between machines. To change it just delete it with 
> `rm -f /etc/machine-id && rm /var/lib/dbus/machine-id` and regenerate it with `dbus-uuidgen --ensure=/etc/machine-id`
> [Reference here](https://unix.stackexchange.com/a/403054)

Configure the kubeconfig file to access the cluster

```console
mkdir -p ~/.kube/clusters
k0sctl kubeconfig --config k0sctl-spc.yaml > ~/.kube/clusters/home-ops

export KUBECONFIG=$(find ~/.kube/clusters -type f | sed ':a;N;s/\n/:/;ba')
```

## FAQ:

### Applying thrown error like: 'ssh dial: ssh: handshake failed: host key mismatch: knownhosts: key mismatch'

This is because you have used the same IP before but have installed the operating system again which changes the host's ssh host key. 
The same happens if you try to ssh root@192.168.122.144.

Solution 1 - Remove the keys from ~/.ssh/known_hosts file:

```console
ssh-keygen -R root@compute-01.internal.place && \
ssh-keygen -R root@compute-02.internal.place && \
ssh-keygen -R root@compute-03.internal.place && \
ssh-keygen -R root@compute-04.internal.place && \
ssh-keygen -R root@compute-05.internal.place
```

Solution 2 - Configure the address range to not use host key checking:

```console
# ~/.ssh/config
Host 192.168.122.*
UserKnownHostsFile=/dev/null
```

Solution 3 - Disable host key checking while running k0sctl:

```console
env SSH_KNOWN_HOSTS=/dev/null k0sctl apply -c k0sctl.yaml
```

### K0s can not apply because 'same ID found'

Some SBC manufacturers set the same machine ID for all the boards. This is problematic as K0s needs them
to be different between machines. To change it just delete it with `rm -f /etc/machine-id && rm /var/lib/dbus/machine-id` 
and regenerate it executing `dbus-uuidgen --ensure=/etc/machine-id`

> [Reference here](https://unix.stackexchange.com/a/403054)

### How do I reset a node?

There is a command combo for this: 

```console
k0s stop
k0s reset --debug --verbose
```

The previous should work, but the problem is sometimes it get stuck, so the first thing is to look for the PID of the
`k0s` process and kill it. After it, you need to remove some directories executing the following commands:

```console
sudo rm -rf /etc/k0s
sudo rm -rf /var/lib/k0s
```

After it, you can re-apply the config and the node will automatically be configured