class UniversalCtags < Formula
  desc "Maintained ctags implementation"
  homepage "https://ctags.io/"
  url "https://github.com/universal-ctags/ctags/releases/download/v6.2.1/universal-ctags-6.2.1.tar.gz"
  sha256 "2c63efe9e0e083dc50e6fdd8c5414781cc8873d8c8940cf553c01870ed962f8c"
  license "GPL-2.0-or-later"
  compatibility_version 1

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end


  head do
    url "https://github.com/universal-ctags/ctags.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
  end

  depends_on "docutils" => :build
  depends_on "pkgconf" => :build
  depends_on "python@3.14" => :build
  depends_on "jansson"
  depends_on "libyaml"
  depends_on "pcre2"

  uses_from_macos "libxml2"

  conflicts_with "ctags", because: "both install `ctags` binaries"

  # ── native build (bootstrap/native/brew_native.sh) ──
  # stdenv so the real clang sees our CFLAGS; superenv would strip them.
  env :std

  def install
    ENV.append_to_cflags "-O3 -mcpu=apple-m4"
    system "./autogen.sh" if build.head?
    system "./configure", *std_configure_args
    system "make"
    system "make", "install"
  end

  test do
    (testpath/"test.c").write <<~C
      #include <stdio.h>
      #include <stdlib.h>

      void func()
      {
        printf("Hello World!");
      }

      int main()
      {
        func();
        return 0;
      }
    C
    system bin/"ctags", "-R", "."
    assert_match(/func.*test\.c/, File.read("tags"))
  end
end
