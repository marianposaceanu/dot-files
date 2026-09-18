class Ripgrep < Formula
  desc "Search tool like grep and The Silver Searcher"
  homepage "https://github.com/BurntSushi/ripgrep"
  url "https://github.com/BurntSushi/ripgrep/archive/refs/tags/15.2.0.tar.gz"
  sha256 "7605249d3eb0d5f170e3414498e3344e26b1e7a147aec518b57090b80036a562"
  license "Unlicense"
  compatibility_version 1
  head "https://github.com/BurntSushi/ripgrep.git", branch: "master"

  livecheck do
    url :stable
    strategy :github_latest
  end


  depends_on "asciidoctor" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "pcre2"

  deny_network_access!

  def fetch
    system "cargo", "fetch", "--locked", "--target", "host-tuple"
  end

  # ── native build (bootstrap/native/brew_native.sh) ──
  # stdenv so the real clang sees our CFLAGS; superenv would strip them.
  env :std

  def install
    ENV["RUSTFLAGS"] = "-C target-cpu=apple-m4"
    ENV.append_to_cflags "-O3 -mcpu=apple-m4" # for the bundled pcre2 C build
    system "cargo", "install", "--profile", "release-lto", *std_cargo_args(features: "pcre2")

    generate_completions_from_executable(bin/"rg", "--generate", shell_parameter_format: "complete-")
    (man1/"rg.1").write Utils.safe_popen_read(bin/"rg", "--generate", "man")
  end

  test do
    (testpath/"Hello.txt").write("Hello World!")
    system bin/"rg", "Hello World!", testpath
  end
end
