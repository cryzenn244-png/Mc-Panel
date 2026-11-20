# systemd service

The installer creates `/etc/systemd/system/mc-panel.service`, runs the app as the restricted `mc-panel` system user, and enables it at boot.

Commands:

```bash
sudo systemctl status mc-panel
sudo journalctl -u mc-panel -f
sudo systemctl restart mc-panel
sudo systemctl stop mc-panel
sudo systemctl start mc-panel
```

Config: `/etc/mc-panel/mc-panel.env`. After changing it, run `sudo systemctl restart mc-panel`.

The service is intended for a real Ubuntu/Debian host with systemd. It deliberately refuses to proceed when `systemctl` is unavailable, which is common in containers.
