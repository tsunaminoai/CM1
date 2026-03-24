{
  description = "CM1 Numerical Model — Cloud Model 1";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    zig-overlay,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [zig-overlay.overlays.default];
        };

        # Zig 0.15.2 — pinned version
        zig = pkgs.zigpkgs."0.15.2";

        # Common build inputs for all CM1 variants
        commonNativeBuildInputs = [
          zig
          pkgs.gfortran
          pkgs.gcc
          pkgs.openmpi
          pkgs.netcdf
          pkgs.netcdffortran
        ];

        # Common runtime data files installation
        installDataFiles = ''
          mkdir -p $out/share/cm1/run
          cp -r $src/run/LANDUSE.TBL $out/share/cm1/run/ 2>/dev/null || true
          cp -r $src/run/RRTMG_LW_DATA $out/share/cm1/run/ 2>/dev/null || true
          cp -r $src/run/RRTMG_SW_DATA $out/share/cm1/run/ 2>/dev/null || true
          cp -r $src/run/namelist.input $out/share/cm1/run/ 2>/dev/null || true
          cp -r $src/run/config_files $out/share/cm1/run/ 2>/dev/null || true
          cp -r $src/soundings $out/share/cm1/ 2>/dev/null || true
        '';

        # Helper to build a CM1 variant
        mkCm1 = {
          pname,
          zigFlags ? "",
          extraBuildInputs ? [],
          description,
        }:
          pkgs.stdenv.mkDerivation {
            inherit pname;
            version = "21.1.0";
            src = ./.;

            nativeBuildInputs = commonNativeBuildInputs;
            buildInputs = extraBuildInputs;

            # Zig needs writable cache directories
            preBuild = ''
              export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
              export HOME="$TMPDIR"
            '';

            buildPhase = ''
              runHook preBuild
              mkdir -p "$TMPDIR/zig-cache"
              zig build ${zigFlags} \
                --cache-dir "$TMPDIR/zig-cache" \
                --global-cache-dir "$TMPDIR/zig-global-cache" \
                -p "$out"
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              ${installDataFiles}
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              inherit description;
              homepage = "https://www2.mmm.ucar.edu/people/bryan/cm1/";
              license = licenses.mit;
              platforms = platforms.linux ++ platforms.darwin;
              mainProgram = "cm1.exe";
            };
          };
      in {
        # ════════════════════════════════════════════════════════════════
        # Packages
        # ════════════════════════════════════════════════════════════════
        packages = rec {
          # ── Serial (single-process) build ────────────────────────────
          cm1 = mkCm1 {
            pname = "cm1";
            zigFlags = "-Dgfortran-libdir=${pkgs.gfortran.cc.lib}/lib";
            description = "CM1 Numerical Model (Cloud Model 1) for atmospheric research";
          };

          # ── MPI build ────────────────────────────────────────────────
          cm1-mpi = mkCm1 {
            pname = "cm1-mpi";
            zigFlags = "-Dmpi=true";
            extraBuildInputs = [pkgs.openmpi];
            description = "CM1 Numerical Model with MPI support";
          };

          # ── NetCDF build ─────────────────────────────────────────────
          cm1-netcdf = mkCm1 {
            pname = "cm1-netcdf";
            zigFlags = "-Dnetcdf=true -Dnetcdf-base=${pkgs.netcdffortran} -Dgfortran-libdir=${pkgs.gfortran.cc.lib}/lib";
            extraBuildInputs = [pkgs.netcdf pkgs.netcdffortran];
            description = "CM1 Numerical Model with NetCDF output support";
          };

          # ── Full-featured build (MPI + NetCDF + OpenMP) ──────────────
          cm1-full = mkCm1 {
            pname = "cm1-full";
            zigFlags = "-Dmpi=true -Dnetcdf=true -Dopenmp=true -Dnetcdf-base=${pkgs.netcdffortran}";
            extraBuildInputs = [pkgs.openmpi pkgs.netcdf pkgs.netcdffortran];
            description = "CM1 Numerical Model (full: MPI + NetCDF + OpenMP)";
          };

          default = cm1;
        };

        # ════════════════════════════════════════════════════════════════
        # Development Shell
        # ════════════════════════════════════════════════════════════════
        devShells.default = pkgs.mkShell {
          name = "cm1-dev";

          packages = [
            zig
            pkgs.gfortran
            pkgs.gcc
            pkgs.openmpi
            pkgs.netcdf
            pkgs.netcdffortran
          ];

          shellHook = ''
            echo "🌩️  CM1 development environment"
            echo "   zig:      $(zig version)"
            echo "   gfortran: $(gfortran --version | head -1)"
            echo ""
            echo "Build commands:"
            echo "   zig build                                # serial build"
            echo "   zig build -Dmpi=true                     # MPI build"
            echo "   zig build -Dnetcdf=true                  # NetCDF build"
            echo "   zig build -Dmpi=true -Dnetcdf=true       # MPI + NetCDF"
            echo "   zig build -Ddebug=true                   # debug build"
            echo ""
            echo "Nix build commands:"
            echo "   nix build .#cm1          # serial"
            echo "   nix build .#cm1-mpi      # MPI"
            echo "   nix build .#cm1-netcdf   # NetCDF"
            echo "   nix build .#cm1-full     # MPI + NetCDF + OpenMP"
          '';

          NETCDFBASE = "${pkgs.netcdffortran}";
        };
      }
    );
}
