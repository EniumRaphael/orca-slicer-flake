{
  description = "Orca Slicer with NVIDIA Wayland support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
        };

        # 1. Le wrapper (ton script de lancement)
        orca-slicer-nvidia-wayland = pkgs.writeShellScriptBin "orca-slicer" ''
          if [ -n "$WAYLAND_DISPLAY" ]; then
            echo "Detected Wayland session"
            if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
              echo "NVIDIA GPU detected, applying Wayland workarounds..."
              
              if [ "$ORCA_SAFE_MODE" = "1" ]; then
                echo "Safe mode enabled"
              else
                export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json
                if [ -f "/run/opengl-driver/lib/dri/zink_dri.so" ]; then
                   export MESA_LOADER_DRIVER_OVERRIDE=zink
                   export GALLIUM_DRIVER=zink
                fi
                export WEBKIT_DISABLE_DMABUF_RENDERER=1
                export __GL_SYNC_TO_VBLANK=0
                export __GL_THREADED_OPTIMIZATIONS=1
              fi
            fi
          fi
          exec ${pkgs.orca-slicer}/bin/orca-slicer "$@"
        '';

        # 2. Le fichier Desktop
        orca-slicer-desktop = pkgs.makeDesktopItem {
          name = "orca-slicer-nvidia-wayland";
          desktopName = "Orca Slicer (NVIDIA Wayland)";
          exec = "orca-slicer %F"; # Utilise le nom du binaire dans le PATH
          icon = "orca-slicer";
          comment = "3D Slicer with NVIDIA Wayland support";
          categories = [ "Graphics" "3DGraphics" ];
          mimeTypes = [ "model/stl" "application/vnd.ms-3mfdocument" "x-scheme-handler/orcaslicer" ];
        };

        # 3. LE PAQUET FINAL (Correction de l'erreur Permission Denied)
        orca-slicer-full = pkgs.symlinkJoin {
          name = "orca-slicer-nvidia-wayland";
          paths = [
            orca-slicer-nvidia-wayland # Ton script (prioritaire)
            orca-slicer-desktop        # Ton raccourci bureau
            pkgs.orca-slicer           # Le vrai paquet (pour les icônes, ressources, etc.)
          ];

          postBuild = ''
            # On supprime le lien vers le binaire original pour ne pas avoir de conflit
            # et on s'assure que 'orca-slicer' pointe vers ton wrapper.
            rm -f $out/bin/orca-slicer
            ln -s ${orca-slicer-nvidia-wayland}/bin/orca-slicer $out/bin/orca-slicer
            
            # Les icônes sont déjà liées automatiquement par symlinkJoin 
            # car pkgs.orca-slicer est dans 'paths'. Pas besoin de 'cp'.
          '';
        };

      in
      {
        packages.default = orca-slicer-full;

        apps.default = {
          type = "app";
          program = "${orca-slicer-full}/bin/orca-slicer";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [ orca-slicer-full pkgs.nvitop pkgs.nvtopPackages.full ];
          shellHook = ''echo "Orca Slicer NVIDIA Dev Shell loaded."'';
        };
      }
    );
}
