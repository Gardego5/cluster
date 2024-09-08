{ modulesPath, ... }: {
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  system.stateVersion = "24.11";
  ec2.efi = true;
  nix.extraOptions = "experimental-features = nix-command flakes";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets."k3s/token".restartUnits = [ "k3s.service" ];
  };
}
