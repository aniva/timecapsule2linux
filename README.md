# timecapsule2linux

[![Build Packages](https://github.com/aniva/timecapsule2linux/actions/workflows/build-packages.yml/badge.svg)](https://github.com/aniva/timecapsule2linux/actions/workflows/build-packages.yml)

A lightweight, robust client configuration and patched FUSE build to easily mount legacy **Apple Time Capsule** shares on modern Linux distributions (Debian, Ubuntu, Fedora, CentOS, RHEL, etc.).

---

## The Challenge

Modern Linux kernels have completely deprecated and disabled **SMBv1** and **NTLMv1** authentication protocols due to severe security vulnerabilities. Since Apple Time Capsules rely on SMBv1 for Windows file sharing, standard `mount -t cifs` commands fail with `Protocol not supported` or `Invalid argument` on modern kernels (5.15+).

## The Solution

Instead of compromising your kernel's security policies by re-enabling obsolete SMBv1 features globally, this project utilizes **AFP (Apple Filing Protocol)** natively in user-space via **FUSE (Filesystem in Userspace)**. 

We compile and package a modern fork of **`afpfs-ng`** (updated for `libfuse3` support) and apply a critical **write compatibility patch** that promotes write-only file descriptors (`O_WRONLY`) to read-write (`AFP_OPENFORK_ALLOWREAD | AFP_OPENFORK_ALLOWWRITE`) at the protocol layer. This resolves the `kFPMiscErr` (-5014) rejection that Apple Time Capsule servers throw when files are opened in write-only modes.

---

## Features

- **Patched FUSE Client:** Fixes the FUSE write-only open bug natively.
- **Easy Installer:** Shell script to handle compilation, installation, and registration automatically.
- **Lifecycle Controls:** A clean helper script to manage manual mounts, status checks, and unmounts.
- **Auto-Mount on Login:** Systemd user service to automatically connect to your Time Capsule when your user session starts.
- **Pre-Built Packages:** Automated builds for Debian/Ubuntu (`.deb`) and Fedora/RHEL (`.rpm`).

---

## Installation

### Option A: Using Pre-Built Packages (Recommended)

1. Download the latest `.deb` or `.rpm` package from the [Releases](https://github.com/aniva/timecapsule2linux/releases) tab.
2. Install the package:
   - **Debian / Ubuntu:**
     ```bash
     sudo apt install ./timecapsule2linux_*.deb
     ```
   - **Fedora / RHEL:**
     ```bash
     sudo dnf install ./timecapsule2linux-*.rpm
     ```

### Option B: Build & Install From Source

Clone the repository and run the automated installer:

```bash
git clone https://github.com/aniva/timecapsule2linux.git
cd timecapsule2linux
./install.sh
```

---

## Configuration

After installation, follow these steps to configure your mount details:

### 1. Configure Mount Script
If you used the pre-built package, copy the template script to your home directory:
```bash
mkdir -p ~/scripts
cp /usr/share/timecapsule2linux/mount-timecapsule.sh ~/scripts/mount-timecapsule.sh
chmod +x ~/scripts/mount-timecapsule.sh
```
*(If you installed from source, this file is automatically placed at `~/scripts/mount-timecapsule.sh`).*

Edit `~/scripts/mount-timecapsule.sh` and set your Time Capsule credentials and IP:
```bash
TC_IP="192.168.1.6"          # Your Time Capsule IP
TC_SHARE="Data"              # Volume name (default is 'Data')
TC_USER="admin"              # Username (default is 'admin')
TC_PASS="your_password"      # Device/Disk password
```

### 2. Test the Connection
Mount your Time Capsule manually to verify it connects:
```bash
~/scripts/mount-timecapsule.sh mount
```
You can check the mount status and list files:
```bash
~/scripts/mount-timecapsule.sh status
```
To unmount:
```bash
~/scripts/mount-timecapsule.sh unmount
```

### 3. Configure Autostart
If you used the pre-built package, copy the systemd service template:
```bash
mkdir -p ~/.config/systemd/user
cp /usr/share/timecapsule2linux/timecapsule.service ~/.config/systemd/user/
```
*(If you installed from source, this is automatically placed at `~/.config/systemd/user/timecapsule.service`).*

Enable and start the user service so the Time Capsule mounts automatically on user login:
```bash
systemctl --user daemon-reload
systemctl --user enable timecapsule.service
systemctl --user start timecapsule.service
```

---

## Real-World Performance Benchmarks

For reference, the following transfer speeds were measured on a physical Apple Time Capsule mounted over a local network using this FUSE AFP implementation (transferring a 2.0 GB test file):

- **Write Speed (Laptop $\rightarrow$ Time Capsule):** **`14.1 MB/s`** (~113 Mbps)
  - *Note:* The write speed is limited by the Time Capsule's internal CPU processing overhead when validating filesystem writes and syncs.
- **Read Speed (Time Capsule $\rightarrow$ Laptop):** **`60.9 MB/s`** (~487 Mbps)
  - *Note:* The read speed is fast and saturates about 50% of a Gigabit Ethernet link, making it perfect for media streaming and quick backup retrievals.

---

## Development & Packaging

To compile the binaries and generate packages locally:

1. Clone the repository.
2. Run the packaging script:
   ```bash
   ./package.sh
   ```
   This will build the patched client, run the test suites, and generate a `.deb` package (if `dpkg-deb` is installed) and an `.rpm` package (if `fpm` is installed).

---

## License

This project is licensed under the GPLv2 License.
