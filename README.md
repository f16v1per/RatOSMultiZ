# RatOS Multi-Sample Z Home Patch

This repo contains a small RatOS Klipper patch for multi-sample `G28 Z` homing via `probe:z_virtual_endstop`.

It targets RatOS Klipper `ratos/v2.1.x` around commit `2817b348`.

## Install On A RatOS Pi

```bash
cd ~
git clone -b v2.1.x https://github.com/f16v1per/RatOSMultiZ.git
~/RatOSMultiZ/install-multisample-z-home.sh
```

If you already cloned it:

```bash
cd ~/RatOSMultiZ
git pull
./install-multisample-z-home.sh
```

The script patches `~/klipper` by default. To target another checkout:

```bash
KLIPPER_DIR=/path/to/klipper ./install-multisample-z-home.sh
```

## Probe Config

Add the settings you want to your `[probe]` section:

```ini
[probe]
z_home_samples: 3
z_home_samples_result: median
z_home_samples_tolerance: 0.05
z_home_samples_tolerance_retries: 2
```

Optional speed and retract overrides:

```ini
z_home_speed: 5
z_home_lift_speed: 10
z_home_retract_dist: 2
```

Then restart Klipper after saving config changes.

