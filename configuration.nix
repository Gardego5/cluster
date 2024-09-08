{ modulesPath, ... }: {
  imports = [ "${modulesPath}/virtualisation/amazon-image.nix" ];
  system.stateVersion = "24.11";
  ec2.efi = true;
  nix.extraOptions = "experimental-features = nix-command flakes";
}
