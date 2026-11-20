{ self, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
        let
          homes = [
            self.homeConfigurations."amunoz@oppy".config
            self.nixosConfigurations.oppy.config.home-manager.users.amunoz
          ];
          validHome =
            home:
            let
              atuin = home.programs.atuin;
              executable = lib.getExe atuin.package;
              keyPath = atuin.settings.key_path or "${home.home.homeDirectory}/.local/share/atuin/key";
              service = home.systemd.user.services.atuin-daemon.Service;
              packageNames = map lib.getName home.home.packages;
            in
            lib.versionAtLeast (lib.getVersion atuin.package) "18.24"
            && atuin.enable
            && atuin.daemon.enable
            && atuin.settings.threads.capture
            && !atuin.settings.threads.capture_tools
            && atuin.settings.daemon.sync_frequency == 300
            && toString home.home.file.".local/bin/atuin".source == executable
            && lib.toList service.ExecStart == [ "${executable} daemon start" ]
            && service.UMask == "0077"
            && builtins.any (command: lib.hasSuffix "-s ${keyPath}" command) service.ExecStartPre
            && builtins.elem "ExecStart=${executable} daemon start" (
              lib.splitString "\n"
                home.xdg.configFile."systemd/user/atuin-daemon.service.d/10-home-manager-package.conf".text
            )
            && builtins.elem "atuin-mcp" packageNames
            && builtins.elem "awscli2" packageNames;
        in
        {
          atuin-session-sync =
            assert lib.assertMsg (builtins.all validHome homes)
              "Oppy Atuin session sync configuration regressed";
            pkgs.runCommand "atuin-session-sync" { } ''
              touch "$out"
            '';
        }
      );
    };
}
