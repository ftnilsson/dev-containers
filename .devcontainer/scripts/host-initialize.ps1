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
        & podman machine ssh podman-machine-agentic -- "nohup /root/.netfix.sh >/tmp/netfix.log 2>&1 & disown; exit 0" 2>$null
    }
} catch {
    # Never let this block "up" — if podman machine isn't running, isn't
    # configured, or anything else goes wrong here, just skip it.
}
exit 0
