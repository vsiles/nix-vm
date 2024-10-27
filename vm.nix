{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  # Define your QEMU kernel parameters
  boot.kernelParams = [ "console=ttyS0" ];
  virtualisation.vmVariant.virtualisation.graphics = false;
  virtualisation.diskSize = 16 * 1024;
  virtualisation.memorySize = 4 * 1024;
  virtualisation.cores = 2;

  virtualisation.qemu = {
    options = [ "-nographic" ];
  };

  virtualisation.fileSystems = {
    "/" = {
      autoResize = true;
    };
  };
}
