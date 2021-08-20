class Unit < Formula
  desc "Dynamic web and application server"
  homepage "https://unit.nginx.org"
  url "https://unit.nginx.org/download/unit-1.25.0.tar.gz"
  sha256 "4ab4f05a934dd00628c0e067f7d0c5ba62bb55e9e2e7a333fa3764a180b9765d"
  head "https://hg.nginx.org/unit", using: :hg

  depends_on "openssl@1.1"
  depends_on "pcre2"

  def install
    system "./configure",
              "--prefix=#{prefix}",
              "--sbindir=#{bin}",
              "--log=#{var}/log/unit/unit.log",
              "--pid=#{var}/run/unit/unit.pid",
              "--control=unix:#{var}/run/unit/control.sock",
              "--modules=#{HOMEBREW_PREFIX}/lib/unit/modules",
              "--state=#{var}/state/unit",
              "--tmp=/tmp",
              "--openssl",
              "--cc-opt=-I#{Formula["openssl@1.1"].opt_prefix}/include",
              "--ld-opt=-L#{Formula["openssl@1.1"].opt_prefix}/lib"

    system "make"
    system "make", "install", "libunit-install"
  end

  def post_install
    (lib/"unit/modules").mkpath
    (var/"log/unit").mkpath
    (var/"run/unit").mkpath
    (var/"state/unit/certs").mkpath
  end

  test do
    require "socket"

    server = TCPServer.new(0)
    port = server.addr[1]
    server.close

    expected_output = "Hello world!"
    (testpath/"index.html").write expected_output
    (testpath/"unit.conf").write <<~EOS
      {
        "routes": [ { "action": { "share": "#{testpath}" } } ],
        "listeners": { "*:#{port}": { "pass": "routes" } }
      }
    EOS

    system bin/"unitd", "--log", "#{testpath}/unit.log",
                        "--control", "unix:#{testpath}/control.sock",
                        "--pid", "#{testpath}/unit.pid",
                        "--state", "#{testpath}/state"
    sleep 3

    pid = File.open(testpath/"unit.pid").gets.chop.to_i

    system "curl", "-s", "--unix-socket", "#{testpath}/control.sock",
                    "-X", "PUT",
                    "-d", "@#{testpath}/unit.conf", "127.0.0.1/config"

    assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")
  ensure
    Process.kill("TERM", pid)
  end
end
