{ config, lib, ... }: {
  options = {
    role = lib.mkOption { type = lib.types.enum [ "first" "server" "agent" ]; };
  };
  config = lib.mkMerge [
    {
      networking.firewall.allowedTCPPorts = [
        6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
      ];

      networking.firewall.allowedUDPPorts = [
        8472 # k3s, flannel: required if using multi-node for inter-node networking
      ];

      services.k3s = {
        enable = true;
        extraFlags = toString [ ];
        tokenFile = "/run/secrets/k3s/token";
        clusterInit = true;
      };
    }

    (lib.mkIf (config.role == "first") {
      services.k3s.role = "server";
      networking.firewall.allowedTCPPorts = [
        2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      ];
    })

    (lib.mkIf (config.role == "server") {
      services.k3s.role = "server";
      networking.firewall.allowedTCPPorts = [
        2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
      ];
    })

    (lib.mkIf (config.role == "agent") { services.k3s.role = "agent"; })
  ];
}
