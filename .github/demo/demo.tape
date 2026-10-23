# README demo for gitbasher. Re-record from the repo root with:
#   vhs .github/demo/demo.tape
# Needs vhs (https://github.com/charmbracelet/vhs), ttyd and ffmpeg.
# setup.sh builds gitb from this checkout and a throwaway repo in /tmp.

Output .github/commit.gif

Set Shell bash
Set FontFamily "JetBrains Mono"
Set FontSize 16
Set Width 1400
Set Height 860
Set Padding 24
Set Theme "Catppuccin Mocha"
Set TypingSpeed 55ms
Set Framerate 12
Set PlaybackSpeed 1.0

Hide
Type ".github/demo/setup.sh /tmp/gitb-demo && source /tmp/gitb-demo/rc && clear"
Enter
Sleep 1s
Show

# 1. Start a feature branch
Type "gitb branch new"
Sleep 400ms
Enter
Sleep 1.2s
Type "feat/add-todo"
Sleep 500ms
Enter
Sleep 2s
# "Push the new branch?" — no, gitb push will do it after the commits
Type "n"
Sleep 1.5s
Ctrl+L

# 2. What changed?
Type "gitb status"
Sleep 400ms
Enter
Sleep 2.5s
Ctrl+L

# 3. Stage everything, split by scope into conventional commits
Type "gitb commit fast"
Sleep 400ms
Enter
Sleep 2.5s
Type "1"
Sleep 800ms
Type "add POST /todos endpoint"
Sleep 500ms
Enter
Sleep 2.5s
Type "1"
Sleep 800ms
Type "strike through finished todos"
Sleep 500ms
Enter
Sleep 3s
Ctrl+L

# 4. Push (creates the branch on the remote)
Type "gitb push"
Sleep 400ms
Enter
Sleep 2s
Type "y"
Sleep 3.5s
Ctrl+L

# 5. Browse history
Type "gitb log"
Sleep 400ms
Enter
Sleep 4s
Type "0"
Enter
Sleep 1s
