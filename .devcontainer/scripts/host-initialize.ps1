# Runs on the HOST (Windows) before every container start — see
# devcontainer.json's initializeCommand. Works for either Podman or Docker:
# the netavark workaround below only applies when Podman is actually the
# active engine, and is a harmless no-op under Docker (which doesn't have
# this bug). This is what lets ONE devcontainer.json serve both — switching
# engines is just the two dev.containers.dockerPath/dockerComposePath
# settings in VS Code, nothing in this repo needs to change.
try {
    $podman = Get-Command podman -ErrorAction SilentlyContinue
    if ($podman) {
        # Podman/netavark bug: an "internal: true" network's FORWARD-accept
        # rule only covers OTHER netavark networks, not itself, so
        # workspace<->proxy traffic gets silently dropped. The chain this
        # patches only exists while a container is attached to an internal
        # network, so this launches a short-lived watcher (already
        # provisioned at /root/.netfix.sh on the VM — see README) that waits
        # for THIS "up" call to create it and patches it within ~1-2s, then
        # self-terminates. Adjust the machine name below if
        # `podman machine list` ever shows a different one.
        # Podman 6 replaced the iptables backend with native nftables, so
        # the chain the watcher patches no longer exists there; the watcher
        # then logs that and exits without changing anything (see README
        # step 3.5). Just surface which major version we're on.
        # Self-heal the Docker-API named pipe. After an unclean shutdown/sleep
        # Podman can leave a stale unix socket in %TEMP%\podman; win-sshproxy
        # then fails to bind ("Only one usage of each socket address"), the
        # \\.\pipe\podman-machine-agentic pipe never appears, and
        # podman-compose fails with "failed to connect to the docker API".
        # `podman ps` still works (SSH fallback), which hides the problem.
        # Fix: if the pipe is missing, drop the stale socket and restart the
        # machine so the proxy re-binds. No-op when the pipe exists.
        $machine = 'podman-machine-agentic'
        if (-not (Test-Path "\\.\pipe\$machine")) {
            Write-Host "Podman API pipe '$machine' missing - removing stale socket and restarting the machine..."
            & podman machine stop $machine 2>&1 | Out-Null
            Get-ChildItem (Join-Path $env:TEMP 'podman') -Filter '*-api.sock' -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            & podman machine start $machine 2>&1 | Out-Null
        }

        $server = (& podman version --format '{{.Server.Version}}' 2>$null)
        if ($server -and $server -match '^(\d+)\.' -and [int]$Matches[1] -ge 6) {
            Write-Host "Podman ${server}: iptables-nft netfix watcher is expected to be a no-op (see README 3.5)."
        }
        & podman machine ssh podman-machine-agentic -- "nohup /root/.netfix.sh >/tmp/netfix.log 2>&1 & disown; exit 0" 2>$null
    }
} catch {
    # Never let this block "up" — if podman machine isn't running, isn't
    # configured, or anything else goes wrong here, just skip it.
}
exit 0
