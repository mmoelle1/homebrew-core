require "language/go"

class Packer < Formula
  desc "Tool for creating identical machine images for multiple platforms"
  homepage "https://packer.io"
  url "https://github.com/mitchellh/packer.git",
      :tag => "v0.10.1",
      :revision => "4e5f65131b5491ab44ff8aa0626abe4a85597ac0"

  bottle do
    cellar :any_skip_relocation
    sha256 "902816b50f011dbd181690be8f7039ad9677588a03f6192eb7f2cc9adf3dce4f" => :el_capitan
    sha256 "c6dff8d80564a24a629cc7ca6a3ac93cf17fedd213544d54eebb56ac1abbf296" => :yosemite
    sha256 "bf1e3c2e9ec4c9a541b6935dc74835b37ea41dd58ff8db702c8434e4647c03ac" => :mavericks
  end

  depends_on :hg => :build
  depends_on "go" => :build

  go_resource "github.com/mitchellh/gox" do
    url "https://github.com/mitchellh/gox.git",
      :revision => "6e9ee79eab7bb1b84155379b3f94ff9a87b344e4"
  end

  go_resource "github.com/mitchellh/iochan" do
    url "https://github.com/mitchellh/iochan.git",
      :revision => "87b45ffd0e9581375c491fef3d32130bb15c5bd7"
  end

  go_resource "golang.org/x/tools" do
    url "https://go.googlesource.com/tools.git",
      :revision => "8b3828f1c8f7c67e5ebb863a4c632937778eaaae"
  end

  def install
    ENV["XC_OS"] = "darwin"
    ENV["XC_ARCH"] = MacOS.prefer_64_bit? ? "amd64" : "386"
    ENV["GOPATH"] = buildpath
    # For the gox buildtool used by packer, which
    # doesn't need to be installed permanently.
    ENV.append_path "PATH", buildpath

    packerpath = buildpath/"src/github.com/mitchellh/packer"
    packerpath.install Dir["{*,.git}"]
    Language::Go.stage_deps resources, buildpath/"src"
    (buildpath/"bin").mkpath

    cd "src/github.com/mitchellh/gox" do
      system "go", "build"
      buildpath.install "gox"
    end

    cd "src/golang.org/x/tools/cmd/stringer" do
      system "go", "build"
      buildpath.install "stringer"
    end

    cd "src/github.com/mitchellh/packer" do
      # We handle this step above. Don't repeat it.
      inreplace "Makefile" do |s|
        s.gsub! "go get github.com/mitchellh/gox", ""
        s.gsub! "go get golang.org/x/tools/cmd/stringer", ""
      end

      system "make", "bin"
      bin.install Dir["bin/*"]
      zsh_completion.install "contrib/zsh-completion/_packer"
    end
  end

  test do
    minimal = testpath/"minimal.json"
    minimal.write <<-EOS.undent
      {
        "builders": [{
          "type": "amazon-ebs",
          "region": "us-east-1",
          "source_ami": "ami-59a4a230",
          "instance_type": "m3.medium",
          "ssh_username": "ubuntu",
          "ami_name": "homebrew packer test  {{timestamp}}"
        }],
        "provisioners": [{
          "type": "shell",
          "inline": [
            "sleep 30",
            "sudo apt-get update"
          ]
        }]
      }
    EOS
    system "#{bin}/packer", "validate", minimal
  end
end
