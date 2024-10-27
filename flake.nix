{
  description = "Test VM";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-24.05";
    unstable.url = "nixpkgs/nixos-unstable";
    axumServer = {
      url = "path:./svc";
    };
  };
  outputs =
    {
      self,
      unstable,
      nixpkgs,
      axumServer,
    }:
    let
      my_modules = [
        ./base.nix
        ./vm.nix
        ./svc-module.nix
        ./kube.nix
      ];
      applyOverlay = pkgs: pkgs.extend axumServer.overlays.default;
      unstable-pkgs = unstable.legacyPackages.x86_64-linux;
      linux-pkgs = applyOverlay nixpkgs.legacyPackages.x86_64-linux;
      darwin-pkgs = applyOverlay nixpkgs.legacyPackages.aarch64-darwin;
      linux-guest-pkgs = applyOverlay nixpkgs.legacyPackages.aarch64-linux;
      tester =
        {
          host-pkgs,
          guest-pkgs,
          name,
        }:
        host-pkgs.testers.runNixOSTest {
          inherit name;

          nodes.machine =
            { config, pkgs, ... }:
            {
              imports = my_modules;

              users.users.alice = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                packages = [ pkgs.tree ];
              };
            };
          testScript = ''
            machine.wait_for_unit("default.target");
            machine.succeed("su -- alice -c 'which tree'")
            machine.succeed("su -- test -c 'which jq'")
            result = machine.succeed("ps aux | grep svc")
            print(result)
            # Testing GET
            result = machine.succeed("${guest-pkgs.curl}/bin/curl http://localhost:3000 -X GET")
            assert result == "Hello, You!"

          '';
        };
    in
    {
      nixosConfigurations.linuxVM = unstable.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ { nixpkgs.overlays = [ axumServer.overlays.default ]; } ] ++ my_modules;
      };
      packages.x86_64-linux.vm = self.nixosConfigurations.linuxVM.config.system.build.vm;
      packages.x86_64-linux.test = tester {
        host-pkgs = linux-pkgs;
        guest-pkgs = linux-pkgs;
        name = "VM Test (linux)";
      };

      nixosConfigurations.darwinVM = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          { nixpkgs.overlays = [ axumServer.overlays.default ]; }
          # This VM will use the host /nix/store thus avoid 'Exec format error'
          { virtualisation.vmVariant.virtualisation.host.pkgs = darwin-pkgs; }
        ] ++ my_modules;
      };
      packages.aarch64-darwin.vm = self.nixosConfigurations.darwinVM.config.system.build.vm;
      packages.aarch64-darwin.test = tester {
        host-pkgs = darwin-pkgs;
        guest-pkgs = linux-guest-pkgs;
        name = "VM Test (darwin)";
      };
      packages.x86_64-linux.test-rke2 = unstable-pkgs.testers.runNixOSTest {
        name = "rke2-single-node";

        nodes.machine =
          { pkgs, ... }:
          {
            networking.firewall.enable = false;
            networking.useDHCP = false;
            networking.defaultGateway = "192.168.1.1";
            networking.interfaces.eth1.ipv4.addresses = pkgs.lib.mkForce [
              {
                address = "192.168.1.1";
                prefixLength = 24;
              }
            ];

            virtualisation.memorySize = 1536;
            virtualisation.diskSize = 4096;

            services.rke2 = {
              enable = true;
              role = "server";
              package = pkgs.rke2;
              nodeIP = "192.168.1.1";
              disable = [
                "rke2-coredns"
                "rke2-metrics-server"
                "rke2-ingress-nginx"
              ];
              extraFlags = [ "--cluster-reset" ];
            };
          };

        testScript =
          let
            kubectl = "${linux-pkgs.kubectl}/bin/kubectl --kubeconfig=/etc/rancher/rke2/rke2.yaml";
            ctr = "${linux-pkgs.containerd}/bin/ctr -a /run/k3s/containerd/containerd.sock";
            pauseImage = linux-pkgs.dockerTools.streamLayeredImage {
              name = "test.local/pause";
              tag = "local";
              contents = linux-pkgs.buildEnv {
                name = "rke2-pause-image-env";
                paths = with linux-pkgs; [
                  tini
                  (hiPrio coreutils)
                  busybox
                ];
              };
              config.Entrypoint = [
                "/bin/tini"
                "--"
                "/bin/sleep"
                "inf"
              ];
            };
            testPodYaml = linux-pkgs.writeText "test.yaml" ''
              apiVersion: v1
              kind: Pod
              metadata:
                name: test
              spec:
                containers:
                - name: test
                  image: test.local/pause:local
                  imagePullPolicy: Never
                  command: ["sh", "-c", "sleep inf"]
            '';
          in
          ''
            start_all()

            machine.wait_for_unit("rke2")
            machine.succeed("${kubectl} cluster-info")
            machine.wait_until_succeeds(
              "${pauseImage} | ${ctr} -n k8s.io image import -"
            )

            machine.wait_until_succeeds("${kubectl} get serviceaccount default")
            machine.succeed("${kubectl} apply -f ${testPodYaml}")
            machine.succeed("${kubectl} wait --for 'condition=Ready' pod/test")
            machine.succeed("${kubectl} delete -f ${testPodYaml}")

            machine.shutdown()
          '';
      };

    };
}
