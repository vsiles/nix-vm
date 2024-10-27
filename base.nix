{ pkgs, ... }:
{
  system.stateVersion = "24.05";

  # Configure networking
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;
  networking.networkmanager.enable = true;
  # networking.firewall.enable = false;

  services.openssh.settings = {
    enable = true;
    AllowedUsers = [ "test" ];
    PermitRootLogin = "yes"; # Allow root login (use with caution)
    PasswordAuthentication = true; # Allow password authentication (or consider using keys)
  };

  # Create user "test"
  services.getty.autologinUser = "test";
  users.users.test.isNormalUser = true;

  # Enable passwordless ‘sudo’ for the "test" user
  users.users.test.extraGroups = [ "wheel" ];
  security.sudo.wheelNeedsPassword = false;

  # Add system wide packages here
  environment.systemPackages = with pkgs; [
    neovim
    tree
    jq
    tmux
    wget
    curl
  ];

  programs.git = {
    enable = true;
    config = {
      user.email = "some.email@foo.org";
      user.name = "Some User Name";
      init.defaultBranch = "main";
    };
  };

  # Bash is the default shell in nix, no need to enable it
  programs.bash = {
    interactiveShellInit = ''
      echo "Hello, welcome to your nixos/linux VM!"
      echo "Use 'sudo poweroff' to turn the VM down and exit QEMU."
      echo "IP: $(ip -4 addr show)"
    '';
  };
}
