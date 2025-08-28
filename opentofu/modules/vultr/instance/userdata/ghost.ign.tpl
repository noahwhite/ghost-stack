{
  "ignition": {
    "version": "3.4.0"
  },
  "storage": {
    "directories": [
      {
        "path": "/etc/ghost",
        "mode": 493
      },
      {
        "path": "/var/lib/ghost/content",
        "mode": 493
      }
    ],
    "filesystems": [
        {
            "device":   "/dev/vdb",
            "format":   "ext4",
            "label":    "ghost-storage"
        }
    ],
    "files": [
        {
            "path": "/etc/ghost.env",
            "mode": 384,
            "contents": {
                "source": "data:text/plain;charset=utf-8;base64,${ghost_env}"
            }
        },
        {
            "path": "/etc/systemd/system/ghost.service",
            "mode": 420,
            "contents": {
                "source": "data:text/plain;charset=utf-8;base64,${ghost_service}"
            }
        },
        {
            "path": "/etc/locksmith/locksmith.conf",
            "mode": 420,
            "contents": {
                "source": "data:text/plain;charset=utf-8;base64,UkVCT09UX1NUUkFURUdZPXJlYm9vdApMT0NLU01JVEhEX1JFQk9PVF9XSU5ET1dfU1RBUlQ9MDI6MDAKTE9DS1NNSVRIRF9SRUJPT1RfV0lORE9XX0xFTkdUSD0yaAo="
            }
        }
    ]
  },
  "systemd": {
    "units": [
      {
        "name": "var-lib-ghost-content.mount",
        "enabled": true,
        "contents": "[Mount]\nWhat=/dev/disk/by-label/ghost-storage\nWhere=/var/lib/ghost/content\nType=ext4\n\n[Install]\nRequiredBy=local-fs.target"
      },
      {
        "name": "docker.service",
        "enabled": true
      },
      {
        "name": "ghost.service",
        "enabled": true
      },
      {
        "name": "update-engine.service",
        "enabled": true
      },
      {
        "name": "locksmithd.service",
        "enabled": true
      }
    ]
  }
}