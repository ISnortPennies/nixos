inputs@{
  stable,
  self,
  disko,
  ...
}:
final: prev:
# Only good use case for rec
{
  wrench = prev.flip prev.pipe;

  needsSystem = prev.flip builtins.elem [
    "defaultPackage"
    "devShell"
    "devShells"
    "formatter"
    "legacyPackages"
    "packages"
  ];

  constructInputs' =
    system:
    final.wrench [
      (prev.filterAttrs (_: prev.isType "flake"))
      (prev.mapAttrs (
        _: prev.mapAttrs (name: value: if final.needsSystem name then value.${system} else value)
      ))
    ];

  listNixFilesRecursive = final.wrench [
    builtins.unsafeDiscardStringContext
    prev.filesystem.listFilesRecursive
    (builtins.filter (x: !prev.hasPrefix "_" (builtins.baseNameOf x) && prev.hasSuffix ".nix" x))
  ];

  mkModules =
    path:
    prev.pipe path [
      final.listNixFilesRecursive
      (map (name: {
        name = prev.pipe name [
          (prev.removeSuffix ".nix")
          (prev.removePrefix "${path}/")
        ];
        value = final.addSchizophreniaToModule name;
      }))
      builtins.listToAttrs
    ];

  addSchizophreniaToModule =
    x:
    let
      # the imported module
      imported = import x;
    in
    /*
      If the module isn't a function then
      it doesn't need arguments and error
      message locations will function correctly
    */
    if !prev.isFunction imported then
      x
    else
      let
        # all arguments defined in the module
        funcArgs = prev.functionArgs imported;
        /*
          The names of all arguments which will be
          available to be inserted into the module arguments
        */
        argNames = builtins.attrNames inputs ++ [
          "inputs"
          "inputs'"
          "self'"
          "_dir"
        ];

        /*
          arguments to be passed minus
          per system attributes
          for example flake-parts-esque inputs'
        */
        argsPre = {
          inherit inputs self;
          /*
            _dir is the "self" derived
            path to the directory containing the module
          */
          _dir = builtins.dirOf x;
        };

        /*
          arguments which will be inserted
          set to the before per-system values
        */
        providedArgs = prev.pipe funcArgs [
          (prev.filterAttrs (n: _: builtins.elem n argNames))
          (prev.mapAttrs (n: _: argsPre.${n} or { }))
        ];

        /*
          arguments which the module system
          not provided here. either to be
          provided by the module system or invalid
        */
        neededArgs = prev.filterAttrs (n: _: !builtins.elem n argNames) funcArgs;
      in
      {
        __functionArgs = neededArgs // {
          /*
            always require pkgs to be passed
            to derive system from pkgs.stdenv.system
          */
          pkgs = false;
        };

        __functor =
          /*
            args is specialArgs + _module.args which are needed
            and always pkgs
          */
          _: args:
          imported (
            /*
              take module system provided arguments
              filter them so only the required ones are passed
            */
            (prev.filterAttrs (n: _: neededArgs ? ${n}) args)
            # add needed arguments
            // (
              providedArgs
              # add system dependent arguments
              // (
                let
                  inputs' = final.constructInputs' args.pkgs.stdenv.system inputs;

                  actuallyAllArgs = inputs' // {
                    inherit inputs';
                    self' = inputs'.self;
                    inherit (inputs) self;
                  };
                in
                prev.filterAttrs (n: _: providedArgs ? ${n}) actuallyAllArgs
              )
            )
          )
          # add _file to the final module attribute set
          // {
            _file = x;
          };
      };

  gerg-utils =
    pkgsf: outputs:
    prev.pipe
      [
        "x86_64-linux"
        "aarch64-linux"
      ]
      [
        (map (
          system:
          builtins.mapAttrs (
            name: value: if final.needsSystem name then { ${system} = value (pkgsf system); } else value
          ) outputs
        ))
        (prev.foldAttrs prev.mergeAttrs { })
      ];

  mkHosts =
    system:
    prev.flip prev.genAttrs (
      hostName:
      # Whats prev.nixosSystem? never heard of her
      prev.evalModules {
        specialArgs.modulesPath = "${stable}/nixos/modules";

        modules = builtins.concatLists [
          (builtins.attrValues self.nixosModules)
          (map final.addSchizophreniaToModule (final.listNixFilesRecursive "${self}/hosts/${hostName}"))
          (import "${stable}/nixos/modules/module-list.nix")
          (prev.singleton {
            networking = {
              inherit hostName;
            };
            nixpkgs.hostPlatform = system;
          })
          (prev.optionals (self.diskoConfigurations ? "disko-${hostName}") [
            self.diskoConfigurations."disko-${hostName}"
            disko.nixosModules.default
          ])
        ];
      }
    );
  mkDisko = final.wrench [
    (map (name: {
      name = "disko-${name}";
      value.disko.devices = import "${self}/disko/${name}.nix" prev;
    }))
    builtins.listToAttrs
  ];

  /*
    /<name> -> packages named by directory
    /<name>/call.nix ->  callPackage override imported via import <file> pkgs
    call.nix example
      {python3Packages}: {
        inherit (python3Packages) callPackage;
        args = {};
     }

    /<name>/package.nix -> the package itself
    /<name>/wrapper.nix:
    a optional wrapper for the package
    which is callPackage'd with the original package
    as an argument named <name>-unwrapped
  */
  mkPackages =
    path: pkgs:
    prev.pipe path [
      builtins.readDir
      (prev.filterAttrs (_: v: v == "directory"))
      builtins.attrNames
      (map (
        n:
        let
          p = "${path}/${n}";

          callPackage =
            file: args:
            let
              defaultArgs =
                pkgs
                // (
                  let
                    inputs' = final.constructInputs' pkgs.stdenv.system inputs;
                  in
                  {
                    inherit inputs' inputs;
                    self' = inputs'.self;
                    inherit (inputs) self;
                    # npins sources if i ever use them
                    # sources = prev.mapAttrs (_: pkgs.npins.mkSource) (prev.importJSON "${self}/packages/sources.json").pins;
                  }
                );
              _callPackage = prev.callPackageWith defaultArgs;
              fullPath = "${p}/${file}.nix";
              callPath = "${p}/call.nix";
            in
            assert prev.assertMsg (builtins.pathExists fullPath)
              "File attempting to be callPackage'd '${fullPath}' does not exist";

            if builtins.pathExists callPath then
              let
                x = _callPackage callPath { };
              in
              x.callPackage or _callPackage fullPath (x.args or defaultArgs // args)

            else
              _callPackage fullPath args;
        in

        if builtins.pathExists "${p}/wrapper.nix" then
          # My distaste for rec grows ever stronger
          let
            set."${n}-unwrapped" = callPackage "package" { };
          in
          { ${n} = callPackage "wrapper" set; } // set
        else
          { ${n} = callPackage "package" { }; }

      ))
      prev.mergeAttrsList
    ];
}
