# dotfiles

Arch Linux + Hyprland + Quickshell dotfiles.

## Notes

The greeter runs as the `greeter` user. `install.sh` creates `/var/lib/greeter`
via `files/root/etc/tmpfiles.d/bn-greetd.conf` and grants that user ACL access
to `~/.config/quickshell`. ACLs are machine-local and are not captured by
`sync.sh`.
