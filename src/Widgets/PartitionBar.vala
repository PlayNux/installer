// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2018 playnux LLC. (https://playnux.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Michael Aaron Murphy <michael@system76.com>
 */

public class Installer.PartitionBar : Gtk.EventBox {
    public Gtk.Box container;

    public uint64 start;
    public uint64 end;
    public uint64 used;
    public new string path;
    public string? vg;

    public Gtk.Label label;
    public Gtk.Popover menu;
    public Distinst.FileSystem filesystem;

    public signal void decrypted (InstallerDaemon.LuksCredentials credential);

    public PartitionBar (InstallerDaemon.Partition part, string parent_path,
                         uint64 sector_size, bool lvm, SetMount set_mount,
                         UnsetMount unset_mount, MountSetFn mount_set) {
        start = part.start_sector;
        end = part.end_sector;

        var usage = part.sectors_used;
        if (usage.tag == 1) {
            used = usage.value;
        } else {
            used = end - start;
        }

        path = part.device_path;
        filesystem = part.filesystem;
        vg = (Distinst.FileSystem.LVM == filesystem)
            ? part.current_lvm_volume_group
            : null;
        tooltip_text = path;

        var style_context = get_style_context ();
        style_context.add_class (Distinst.strfilesys (filesystem));

        container = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        if (filesystem == Distinst.FileSystem.LUKS) {
            menu = new DecryptMenu (path);
            ((DecryptMenu)menu).decrypted.connect ((creds) => decrypted (creds));
        } else {
            menu = new PartitionMenu (path, parent_path, filesystem, lvm,
                                      set_mount, unset_mount, mount_set, this);
        }

        menu.relative_to = container;
        menu.position = Gtk.PositionType.BOTTOM;

        add (container);
        add_events (Gdk.EventMask.BUTTON_PRESS_MASK);
        button_press_event.connect (() => {
            show_popover ();
            return true;
        });
    }

    class construct {
        set_css_name ("block");
    }

    construct {
        hexpand = true;
    }

    public uint64 get_size () {
        return end - start;
    }

    public double get_percent (uint64 disk_sectors) {
        return (((double) this.get_size () / (double) disk_sectors));
    }

    public int calculate_length (int alloc_width, uint64 disk_sectors) {
        var request = alloc_width * get_percent (disk_sectors);
        if (request < 20) request = 20;
        return (int) request;
    }

    public void show_popover () {
        menu.popup ();
    }
}
