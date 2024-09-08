{
  config = {
    sops.defaultSopsFile = ../secrets/secrets.yaml;
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.secrets."k3s/token" = { restartUnits = [ "k3s.service" ]; };
  };
}
