class Gitbasher < Formula
  desc "Simple bash utility that makes git easy to use"
  homepage "https://github.com/maxbolgarin/gitbasher"
  url "https://github.com/maxbolgarin/gitbasher/archive/refs/tags/v3.0.0.tar.gz"
  sha256 ""  # Will be calculated during release
  license "MIT"
  head "https://github.com/maxbolgarin/gitbasher.git", branch: "main"

  depends_on "bash" => :build
  depends_on "git"

  def install
    # Build the single gitb executable
    system "make", "build"

    # Install the binary
    bin.install "dist/gitb"
  end

  def caveats
    <<~EOS
      gitbasher has been installed as 'gitb'

      Get started:
        cd your-project
        gitb              # See all commands
        gitb doctor       # Check your setup
        gitb commit       # Make a commit

      Documentation: https://github.com/maxbolgarin/gitbasher

      If zsh tries to autocorrect 'gitb' to 'git', add this to your ~/.zshrc:
        alias gitb='nocorrect gitb'
    EOS
  end

  test do
    # Test that the binary exists and runs
    assert_match "gitbasher", shell_output("#{bin}/gitb --version 2>&1", 0)

    # Test doctor command (should work outside git repos)
    system "#{bin}/gitb", "doctor"
  end
end
