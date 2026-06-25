use shared/tags.nu [tag_info tag_ok]

# Keep the machine awake during long development sessions.
# Starts `caffeinate` bound to the current Nushell process and sends a periodic key code.
export def main [
  --interval-seconds (-i): int = 59 # Delay between key presses.
  --key-code (-k): int = 113 # Default key code (F15).
] {
  if $interval_seconds < 1 {
    error make --unspanned { msg: "--interval-seconds must be >= 1" }
  }

  let runner_pid = $nu.pid

  tag_info $"Starting keep-awake mode pid=($runner_pid), key_code=($key_code), interval=($interval_seconds)s"
  tag_info "Press Ctrl+C to stop."

  let caffeinate_job = (job spawn { ^caffeinate -i -w $runner_pid })
  tag_info $"Started caffeinate background job id=($caffeinate_job)"

  while true {
    ^osascript -e $"tell application \"System Events\" to key code ($key_code)"
    sleep ($interval_seconds | into duration --unit sec)
  }

  tag_ok "loop command exited"
}
