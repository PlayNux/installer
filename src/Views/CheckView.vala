/*-
 * Copyright 2016-2022 playnux, Inc. (https://playnux.io)
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
 * Authored by: Corentin Noël <corentin@playnux.io>
 */

public class Installer.CheckView : AbstractInstallerView {
    // We have to do it step by step because the vala compiler has overflows with big numbers.
    public const uint64 ONE_GB = 1000 * 1000 * 1000;
    // Minimum 15 GB
    public const uint64 MINIMUM_SPACE = 15 * ONE_GB;
    // Minimum 1.2 GHz
    public const int MINIMUM_FREQUENCY = 1200 * 1000;
    // Minimum 1GB
    public const uint64 MINIMUM_MEMORY = 1 * ONE_GB;

    public signal void next_step ();

    private bool enough_space = true;
    private bool minimum_specs = true;
    private bool vm = false;

    private int frequency = 0;
    private uint64 memory = 0;

    public CheckView () {
        Object (cancellable: true);
    }

    construct {
        var image = new Gtk.Image.from_icon_name ("computer-fail", Gtk.IconSize.DIALOG) {
            valign = Gtk.Align.END
        };

        var title_label = new Gtk.Label (_("System Requirements")) {
            valign = Gtk.Align.START
        };
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        var space_view = new CheckView (
            _("Not Enough Space"),
            _("%s of storage or more is required to install %s.").printf (GLib.format_size (MINIMUM_SPACE), Utils.get_pretty_name ()),
            "drive-harddisk"
        );

        var vm_view = new CheckView (
            _("Virtual Machine"),
            _("Some parts of %s may run slowly, freeze, or not function properly.").printf (Utils.get_pretty_name ()),
            "computer"
        );

        var specs_view = new CheckView (
            _("Your Device May Be Too Slow"),
            _("This may cause it to run slowly or freeze."),
            "application-x-firmware"
        );
        specs_view.attach (get_comparison_grid (), 1, 2);

        var message_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 32) {
            valign = Gtk.Align.CENTER
        };

        content_area.column_homogeneous = true;
        content_area.margin_start = content_area.margin_end = 12;
        content_area.valign = Gtk.Align.CENTER;
        content_area.attach (image, 0, 0);
        content_area.attach (title_label, 0, 1);
        content_area.attach (message_box, 1, 0, 1, 2);

        var ignore_button = new Gtk.Button.with_label (_("Ignore"));
        ignore_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
        ignore_button.clicked.connect (() => next_step ());

        action_area.add (ignore_button);

        enough_space = get_has_enough_space ();
        vm = get_vm ();

        frequency = get_frequency ();
        if (frequency < MINIMUM_FREQUENCY && frequency > 0) {
            minimum_specs = false;
        }

        memory = get_mem_info ();
        if (memory < MINIMUM_MEMORY) {
            minimum_specs = false;
        }

        if (!enough_space) {
            message_box.add (space_view);
            ignore_button.sensitive = false;
        }

        if (vm) {
            message_box.add (vm_view);
        }

        if (!minimum_specs) {
            message_box.add (specs_view);
        }

        show_all ();
    }

    // If all the requirements are met, skip this view (return true);
    public bool check_requirements () {
        return enough_space && minimum_specs && !vm;
    }

    private static bool get_has_enough_space () {
        var loop = new MainLoop ();
        InstallerDaemon.DiskInfo? disks = null;

        Daemon.get_default ().get_disks.begin (false, (obj, res) => {
            try {
                disks = ((Daemon)obj).get_disks.end (res);
            } catch (Error e) {
                critical ("Unable to get disks list: %s", e.message);
            } finally {
                loop.quit ();
            }
        });

        loop.run ();

        if (disks == null) {
            return false;
        }

        foreach (unowned InstallerDaemon.Disk disk in disks.physical_disks) {
            uint64 size = disk.sectors * disk.sector_size;
            if (size > MINIMUM_SPACE) {
                return true;
            }
        }
        return false;
    }

    private int get_frequency () {
        var max_freq_file = GLib.File.new_for_path ("/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq");
        try {
            FileInputStream @is = max_freq_file.read ();
            DataInputStream dis = new DataInputStream (@is);
            string line;

            while ((line = dis.read_line ()) != null) {
                return int.parse (line);
            }
        } catch (Error e) {
            stdout.printf ("Error: %s\n", e.message);
        }

        return 0;
    }

    private uint64 get_mem_info () {
        File file = File.new_for_path ("/proc/meminfo");
        try {
            DataInputStream dis = new DataInputStream (file.read ());
            string? line;
            string name = "MemTotal:";
            while ((line = dis.read_line (null, null)) != null) {
                if (line.has_prefix (name)) {
                    var number = line.replace ("kB", "").replace (name, "").strip ();
                    return uint64.parse (number) * 1000;
                }
            }
        } catch (Error e) {
            warning (e.message);
        }

        return 0;
    }

    private static bool get_vm () {
        File file = File.new_for_path ("/proc/cpuinfo");
        try {
            DataInputStream dis = new DataInputStream (file.read ());
            string? line;
            while ((line = dis.read_line (null, null)) != null) {
                if (line.has_prefix ("flags") && line.contains ("hypervisor")) {
                    return true;
                }
            }
        } catch (Error e) {
            critical (e.message);
        }

        return false;
    }

    private class CheckView : Gtk.Grid {
        public CheckView (string title, string description, string icon_name) {
            var image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DND) {
                valign = Gtk.Align.START
            };

            var title_label = new Gtk.Label (title) {
                hexpand = true,
                max_width_chars = 1,
                wrap = true,
                xalign = 0
            };
            title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            var description_label = new Gtk.Label (description) {
                max_width_chars = 1, // Make Gtk wrap, but not expand the window
                wrap = true,
                xalign = 0
            };

            column_spacing = 12;

            attach (image, 0, 0, 1, 2);
            attach (title_label, 1, 0);
            attach (description_label, 1, 1);

            show_all ();
        }
    }

    private Gtk.Grid get_comparison_grid () {
        var recommended_label = new Gtk.Label (_("Recommended:")) {
            hexpand = true,
            xalign = 0
        };
        recommended_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        var your_device_label = new Gtk.Label (_("Your Device:")) {
            hexpand = true,
            xalign = 0
        };
        your_device_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

        var processor_1 = new Gtk.Label (_("Processor:")) {
            xalign = 1
        };

        var processor_2 = new Gtk.Label (_("Processor:")) {
            xalign = 1
        };

        var processor_val_1 = new Gtk.Label (get_frequency_string (MINIMUM_FREQUENCY)) {
            xalign = 0
        };

        var processor_val_2 = new Gtk.Label (get_frequency_string (frequency)) {
            xalign = 0
        };

        var memory_1 = new Gtk.Label (_("Memory:")) {
            xalign = 1
        };

        var memory_2 = new Gtk.Label (_("Memory:")) {
            xalign = 1
        };

        var memory_val_1 = new Gtk.Label (GLib.format_size (MINIMUM_MEMORY)) {
            xalign = 0
        };

        var memory_val_2 = new Gtk.Label (GLib.format_size (memory)) {
            xalign = 0
        };

        var comparison_grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_top = 12,
            row_spacing = 6
        };
        comparison_grid.attach (recommended_label, 0, 0, 2);
        comparison_grid.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 2, 0, 1, 5);
        comparison_grid.attach (your_device_label, 3, 0, 2, 1);
        comparison_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 5);
        comparison_grid.attach (processor_1, 0, 2);
        comparison_grid.attach (processor_val_1, 1, 2);
        comparison_grid.attach (processor_2, 3, 2);
        comparison_grid.attach (processor_val_2, 4, 2);
        comparison_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 3, 5);
        comparison_grid.attach (memory_1, 0, 4);
        comparison_grid.attach (memory_val_1, 1, 4);
        comparison_grid.attach (memory_2, 3, 4);
        comparison_grid.attach (memory_val_2, 4, 4);

        return comparison_grid;
    }

    private static string get_frequency_string (int freq) {
        if (freq >= 1000000) {
            return "%.1f GHz".printf (((float)freq) / 1000000);
        } else if (freq >= 1000) {
            return "%.1f MHz".printf (((float)freq) / 1000);
        } else {
            return "%d kHz".printf (freq);
        }
    }
}
