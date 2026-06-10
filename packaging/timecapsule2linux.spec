Name:           timecapsule2linux
Version:        1.0.0
Release:        1%{?dist}
Summary:        Apple Time Capsule AFP FUSE Mount Client
License:        GPLv2
URL:            https://github.com/aniva/timecapsule2linux
Requires:       libgcrypt, gmp, fuse3, glib2

%description
Patched afpfs-ng client with FUSE3 support, mount helper script, and systemd service templates.

%install
mkdir -p %{buildroot}/usr
cp -r %{_pkg_stage}/usr/* %{buildroot}/usr/
mkdir -p %{buildroot}/usr/share/timecapsule2linux
cp %{_workspace}/mount-timecapsule.sh.template %{buildroot}/usr/share/timecapsule2linux/mount-timecapsule.sh
cp %{_workspace}/timecapsule.service.template %{buildroot}/usr/share/timecapsule2linux/timecapsule.service

%files
/usr/bin/afp*
/usr/bin/mount_afpfs
/usr/lib64/libafpclient.so*
/usr/lib64/libafpsl.so*
/usr/share/timecapsule2linux/mount-timecapsule.sh
/usr/share/timecapsule2linux/timecapsule.service

%post
/sbin/ldconfig

%postun
/sbin/ldconfig
