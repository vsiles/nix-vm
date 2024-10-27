{ pkgs, config, ... }:
let
  configPath = "rancher/rke2/config.yaml";
in
{
  imports = [ ];

  # services.rke2 = {
  #   enable = false;
  #   # serverAddr = "https://127.0.0.1:6443";
  #   # cni = "cilium"; # TODO what is that ?
  #   role = "server";
  #   nodeName = "rke2-master";
  #   configPath = "/etc/" + configPath;
  # };

  # environment.etc."${configPath}" = {
  #   text = ''
  #     write-kubeconfig-mode: "0644"
  #     # tls-san:
  #     #   - "foo.local"
  #     token: ${token}
  #     node-label:
  #       - "foo=bar"
  #       - "something=amazing"
  #     debug: true
  #   '';
  # };

  environment.etc."vsiles-test.yaml" = {
    text = ''
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  containers:
    - name: hello-world-container
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - while true; do
            echo "Hello, World!";
            sleep 5;
          done
      resources:
        limits:
          memory: "32Mi"
          cpu: "100m"
    '';
  };

  # virtualisation = {
  #   docker.enable = true;
  #   containerd.enable = true;
  # };

  # services.etcd.enable = true;

  environment.systemPackages = [
    pkgs.kubectl
    pkgs.kubernetes-helm
    # pkgs.rke2
    pkgs.k9s
  ];

  networking.firewall.allowedTCPPorts = [
    6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
    # 2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
    # 2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
  ];
  networking.firewall.allowedUDPPorts = [
    # 8472 # k3s, flannel: required if using multi-node for inter-node networking
  ];
  services.k3s.enable = true;
  services.k3s.role = "server";
  services.k3s.extraFlags = toString [
    # "--debug" # Optionally add additional args to k3s
  ];
}
