{pkgs}:
pkgs.stdenv.mkDerivation {
  pname = "xcode";
  version = "16.2";
  # You can't download this from Apple because they require auth
  # and it'a against TOS to host this file publicly.
  # You can get it here: https://download.developer.apple.com/Developer_Tools/Xcode_16.2/Xcode_16.2.xip
  # TODO: option to download from "private corporate network"
  src = pkgs.fetchurl {
    url = "https://www.dropbox.com/scl/fi/vgn8fvlgmufv1b2kffn02/Xcode_16.2.xip?rlkey=rgyc648v6sg453ak7ndn236vu&st=bfg4fsk3&dl=0";
    # Same hash as nixpkgs (which just pretends globally installed xcode isn't globally installed)
    # https://github.com/NixOS/nixpkgs/blob/995d7da02d6d3c46773ee549c919e6d53169000e/pkgs/os-specific/darwin/xcode/default.nix#L104
    # sha256 = "sha256-wQjNuFZu/cN82mEEQbC1MaQt39jLLDsntsbnDidJFEs=";
    # FIXME: why is it different?!
    sha256 = "sha256-DjZ9But8M06hQ7raXkQi9WaIqr/1cb7fDSrZQ0tykN4=";
  };
  dontStrip = true;
  nativeBuildInputs = [pkgs.xar pkgs.pbzx pkgs.cpio];
  unpackPhase = ''
    xar -xf $src
    pbzx -n Content | cpio -i
  '';
  installPhase = ''
    mkdir -p $out/Applications
    cp -R Xcode.app $out/Applications/
    
    # Ensure all permissions are correct (important for simulators)
    chmod -R u+w $out/Applications/Xcode.app
    
    # Create bin directory and symlink tools
    mkdir -p $out/bin
    for tool in $out/Applications/Xcode.app/Contents/Developer/usr/bin/*; do
      ln -s $tool $out/bin/
    done
    
    # Make sure simulator components are properly installed and accessible
    if [ -d "$out/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform" ]; then
      echo "iOS Simulator platform found, ensuring proper permissions"
      chmod -R u+w $out/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform
      
      # Ensure SDK paths are correct
      echo "Checking iOS Simulator SDK"
      ls -l $out/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs || echo "No SDKs found"
    else
      echo "WARNING: iOS Simulator platform not found!"
    fi
  '';
  meta = with pkgs.lib; {
    description = "Xcode IDE for macOS";
    homepage = "https://developer.apple.com/xcode/";
    platforms = platforms.darwin;
  };
}
