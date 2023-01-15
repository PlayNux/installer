# Installer

> Note: this is the installer for playnux OS 2 and newer. For the playnux OS 1 and older installer, see [Ubiquity](https://wiki.ubuntu.com/Ubiquity).

An installer for an open-source operating system
## Building, Testing, and Installation

You'll need the following dependencies:

 - meson
 - desktop-file-utils
 - gettext
 - gparted
 - libgnomekbd-dev
 - libgranite-dev >= 0.5
 - libgtk-3-dev
 - libgee-0.8-dev
 - libhandy-1-dev
 - libjson-glib-dev
 - libpwquality-dev
 - libxml2-dev
 - libxml2-utils
 - [distinst](https://github.com/pop-os/distinst/)
 - valac

Run the `autobuild` script to build and clean up.Alternatively you can do the following:

Run `meson build` to configure the build environment. Change to the build directory and run `ninja test` to build and run automated tests.

    meson build --prefix=/usr
    cd build
    ninja test

To install, use `ninja install`, then execute with `io.playnux.installer`. Note that listing drives and actually installing requires root.

    sudo ninja install
    io.playnux.installer

You can also use `--test` mode for development to disable destructive behaviors like installing, restarting, and shutting down:

    io.playnux.installer --test

For debug messages, set the `G_MESSAGES_DEBUG` environment variable, e.g. to `all`:

    G_MESSAGES_DEBUG=all io.playnux.installer

