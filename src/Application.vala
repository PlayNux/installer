// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016–2018 playnux LLC. (https://playnux.io)
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

public class Installer.App : Gtk.Application {
    public const OptionEntry[] INSTALLER_OPTIONS = {
        { "test", 't', 0, OptionArg.NONE, out test_mode, "Non-destructive test mode", null},
        { null }
    };

    public static bool test_mode;

    construct {
        application_id = "io.playnux.installer";
        flags = ApplicationFlags.FLAGS_NONE;
        Intl.setlocale (LocaleCategory.ALL, "");
        add_main_option_entries (INSTALLER_OPTIONS);
    }

    public override void activate () {
        var window = new MainWindow ();
        window.show_all ();
        this.add_window (window);

        weak Gtk.IconTheme default_theme = Gtk.IconTheme.get_default ();
        default_theme.add_resource_path ("/io/playnux/installer");

        var css_fallback = new Gtk.CssProvider ();
        css_fallback.load_from_resource ("io/playnux/installer/disk-bar-fallback.css");
        Gtk.StyleContext.add_provider_for_screen (
            Gdk.Screen.get_default (),
            css_fallback,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        Inhibitor.get_instance ().inhibit ();
    }
}

public static int main (string[] args) {
    var application = new Installer.App ();
    return application.run (args);
}
