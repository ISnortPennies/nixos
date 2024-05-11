inputs@{
  unstable,
  self,
  disko,
  ...
}:
let
  inherit (unstable) lib;
in
# Only good use case for rec
rec {

  needsSystem =
    output:
    builtins.elem output [
      "defaultPackage"
      "devShell"
      "devShells"
      "formatter"
      "legacyPackages"
      "packages"
    ];

  constructInputs' =
    system: inputs:
    lib.pipe inputs [
      (lib.filterAttrs (_: lib.isType "flake"))
      (lib.mapAttrs (_: lib.mapAttrs (name: value: if needsSystem name then value.${system} else value)))
    ];

  listNixFilesRecursive =
    path:
    builtins.filter (lib.hasSuffix ".nix") (map toString (lib.filesystem.listFilesRecursive path));

  listNixFilesRecursiveDiscardStringContext =
    x: listNixFilesRecursive (builtins.unsafeDiscardStringContext x);

  fixModuleSystem =
    file:
    lib.pipe file [
      builtins.readFile
      (builtins.replaceStrings (lib.singleton "#_file") (lib.singleton ''_file = "${file}";''))
      (builtins.toFile (builtins.baseNameOf file))
    ];

  mkModules =
    path:
    lib.listToAttrs (
      map (name: {
        name = lib.pipe name [
          (lib.removeSuffix ".nix")
          (lib.removePrefix "${path}/")
        ];
        value = fixModuleSystem name;
      }) (listNixFilesRecursiveDiscardStringContext path)
    );

  gerg-utils =
    config: outputs:
    lib.foldAttrs lib.mergeAttrs { } (
      map (
        system:
        let
          pkgs =
            if config == { } then
              unstable.legacyPackages.${system}
            else
              import unstable { inherit system config; };
        in
        lib.mapAttrs (name: value: if needsSystem name then { ${system} = value pkgs; } else value) outputs
      ) [ "x86_64-linux" ]
    );

  mkHosts =
    system: names:
    lib.genAttrs names (
      name:
      # Whats lib.nixosSystem? never heard of her
      lib.evalModules {
        specialArgs.modulesPath = "${unstable}/nixos/modules";

        modules =
          let
            importWithInputs' = map (x: import x (constructInputs' system inputs));
          in
          builtins.concatLists [
            (importWithInputs' (builtins.attrValues self.nixosModules))
            (importWithInputs' (
              map fixModuleSystem (listNixFilesRecursiveDiscardStringContext "${self}/hosts/${name}")
            ))
            (import "${unstable}/nixos/modules/module-list.nix")
            (lib.singleton {
              networking.hostName = name;
              nixpkgs.hostPlatform = system;
            })
            (lib.optionals (self.diskoConfigurations ? "disko-${name}") [
              self.diskoConfigurations."disko-${name}"
              disko.nixosModules.default
            ])
          ];
      }
    );
  mkDisko =
    names:
    lib.listToAttrs (
      map (name: {
        name = "disko-${name}";
        value.disko.devices = import "${self}/disko/${name}.nix" lib;
      }) names
    );

  /*
    /<name> -> packages named by directory
    /<name>/call.nix ->  callPackage override imported via import <file> pkgs
    call.nix example
      pkgs: {
        inherit (pkgs.python3Packages) callPackage;
        args = {};
     }

    /<name>/package.nix -> the package itself
  */
  mkPackages =
    path: pkgs:
    lib.pipe path [
      builtins.readDir
      (lib.filterAttrs (_: v: v == "directory"))
      (lib.mapAttrs (
        n: _:
        let
          callPackage = lib.callPackageWith (
            pkgs
            // {
              inputs = constructInputs' pkgs.stdenv.hostPlatform.system inputs;
              # maybe add self?
              # inherit self;
              # npins sources if i need them
              # sources = import ./npins;
            }
          );
        in

        if builtins.pathExists "${path}/${n}/call.nix" then
          let
            x = import "${path}/${n}/call.nix" pkgs;
          in
          x.callPackage "${path}/${n}/package.nix" x.args
        else
          callPackage "${path}/${n}/package.nix" { }

      ))
    ];
}
