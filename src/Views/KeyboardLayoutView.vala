/*-
 * Copyright 2017-2021 elementary, Inc. (https://elementary.io)
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
 */

public class KeyboardLayoutView : AbstractInstallerView {
    public signal void next_step ();

    private VariantWidget input_variant_widget;
    private GLib.Settings keyboard_settings;

    construct {
        keyboard_settings = new GLib.Settings ("org.gnome.desktop.input-sources");

        var image = new Gtk.Image.from_icon_name ("input-keyboard", Gtk.IconSize.DIALOG) {
            valign = Gtk.Align.END
        };

        var title_label = new Gtk.Label (_("Select Keyboard Layout")) {
            valign = Gtk.Align.START
        };
        title_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        input_variant_widget = new VariantWidget ();

        var keyboard_test_entry = new Gtk.Entry () {
            placeholder_text = _("Type to test your layout"),
            secondary_icon_activatable = true,
            secondary_icon_name = "input-keyboard-symbolic",
            secondary_icon_tooltip_text = _("Show keyboard layout")
        };

        var stack_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            row_spacing = 12
        };
        stack_grid.add (input_variant_widget);
        stack_grid.add (keyboard_test_entry);

        content_area.column_homogeneous = true;
        content_area.margin_end = 12;
        content_area.margin_start = 12;
        content_area.attach (image, 0, 0);
        content_area.attach (title_label, 0, 1);
        content_area.attach (stack_grid, 1, 0, 1, 2);

        var back_button = new Gtk.Button.with_label (_("Back"));

        var next_button = new Gtk.Button.with_label (_("Select")) {
            sensitive = false
        };
        next_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        action_area.add (back_button);
        action_area.add (next_button);

        input_variant_widget.main_listbox.set_sort_func ((row1, row2) => {
            return ((LayoutRow) row1).layout.description.collate (((LayoutRow) row2).layout.description);
        });

        input_variant_widget.variant_listbox.set_sort_func ((row1, row2) => {
            if (((VariantRow) row1).code == null) {
                return -1;
            }

            if (((VariantRow) row2).code == null) {
                return 1;
            }

            return ((VariantRow) row1).description.collate (((VariantRow) row2).description);
        });

        input_variant_widget.variant_listbox.row_activated.connect (() => {
            next_button.activate ();
        });

        back_button.clicked.connect (() => ((Gtk.Stack) get_parent ()).visible_child = previous_view);

        next_button.clicked.connect (() => {
            unowned Gtk.ListBoxRow row = input_variant_widget.main_listbox.get_selected_row ();
            if (row != null) {
                var layout = ((LayoutRow) row).layout;
                unowned Configuration configuration = Configuration.get_default ();
                configuration.keyboard_layout = layout.name;

                unowned Gtk.ListBoxRow vrow = input_variant_widget.variant_listbox.get_selected_row ();
                if (vrow != null) {
                    unowned string variant = ((VariantRow) vrow).code;
                    configuration.keyboard_variant = variant;
                } else if (layout.variants == null) {
                    configuration.keyboard_variant = null;
                } else {
                    row.activate ();
                    return;
                }
            } else {
                warning ("next_button enabled when no keyboard selected");
                next_button.sensitive = false;
                return;
            }

            next_step ();
        });

        input_variant_widget.main_listbox.row_activated.connect ((row) => {
            var layout = ((LayoutRow) row).layout;
            if (layout.variants == null) {
                return;
            }

            input_variant_widget.clear_variants ();
            input_variant_widget.variant_listbox.add (new VariantRow (null, _("Default")));
            layout.variants.foreach ((key, val) => {
                input_variant_widget.variant_listbox.add (new VariantRow (key, val));
            });

            input_variant_widget.variant_listbox.select_row (input_variant_widget.variant_listbox.get_row_at_index (0));

            input_variant_widget.show_variants (_("Input Language"), "<b>%s</b>".printf (layout.description));
        });

        input_variant_widget.variant_listbox.row_selected.connect (() => {
            string layout_string = "us";

            unowned Gtk.ListBoxRow row = input_variant_widget.main_listbox.get_selected_row ();
            if (row != null) {
                layout_string = ((LayoutRow) row).layout.name;

                unowned Gtk.ListBoxRow vrow = input_variant_widget.variant_listbox.get_selected_row ();
                if (vrow != null) {
                    string variant = ((VariantRow) vrow).code;
                    if (variant != null && variant != "") {
                        layout_string += "+" + variant;
                    }
                }
            }

            if (!Installer.App.test_mode) {
                Variant[] entries = { new Variant ("(ss)", "xkb", layout_string) };
                var sources = new Variant.array (new VariantType ("(ss)"), entries);
                keyboard_settings.set_value ("sources", sources);
                keyboard_settings.set_value ("current", (uint)0);
            }
        });

        input_variant_widget.main_listbox.row_selected.connect ((row) => {
            next_button.sensitive = true;
        });

        keyboard_test_entry.icon_release.connect (() => {
            var layout = new LayoutWidget ();

            string layout_string;
            unowned Gtk.ListBoxRow row = input_variant_widget.main_listbox.get_selected_row ();
            if (row != null) {
                layout_string = ((LayoutRow) row).layout.name;

                unowned Gtk.ListBoxRow vrow = input_variant_widget.variant_listbox.get_selected_row ();
                if (vrow != null) {
                    string variant = ((VariantRow) vrow).code;
                    layout_string += "\t" + variant;
                }
            } else {
                layout_string = "us";
            }

            layout.set_layout (layout_string);

            var popover = new Gtk.Popover (keyboard_test_entry);
            popover.add (layout);
            popover.show_all ();
        });

        var ctx = new Rxkb.Context (Rxkb.ContextFlags.NO_FLAGS);
        ctx.parse_default_ruleset ();
        unowned Rxkb.Layout? rxkb_layout;

        var layouts = new HashTable<string, Layout?> (str_hash, str_equal);
        for (rxkb_layout = ctx.get_first_layout (); rxkb_layout != null; rxkb_layout = rxkb_layout.next ()) {
            unowned var layout_name = rxkb_layout.get_name ();
            unowned Layout? layout = layouts.get (layout_name);
            if (layout == null) {
                var new_layout = Layout () {
                    name = layout_name,
                };

                layouts.insert (new_layout.name, new_layout);
                layout = layouts.get (layout_name);
            }

            if (rxkb_layout.get_variant () == null) {
                layout.description = rxkb_layout.get_description ();
            } else {
                if (layout.variants == null) {
                    layout.variants = new GLib.HashTable<string, string> (str_hash, str_equal);
                }

                layout.variants.insert (rxkb_layout.get_variant (), rxkb_layout.get_description ());
            }
        }

        foreach (unowned var layout in layouts.get_values ()) {
            input_variant_widget.main_listbox.add (new LayoutRow (layout));
        }

        show_all ();

        Idle.add (() => {
            string? country = Configuration.get_default ().country;
            if (country != null) {
                string default_layout = country.down ();

                foreach (weak Gtk.Widget child in input_variant_widget.main_listbox.get_children ()) {
                    if (child is LayoutRow) {
                        weak LayoutRow row = (LayoutRow) child;
                        if (row.layout.name == default_layout) {
                            input_variant_widget.main_listbox.select_row (row);
                            row.grab_focus ();
                            break;
                        }
                    }
                }
            }
        });
    }

    private struct Layout {
        public string name;
        public string? description;
        public GLib.HashTable<string, string>? variants;
    }

    private class LayoutRow : Gtk.ListBoxRow {
        public Layout layout { get; construct; }

        public LayoutRow (Layout layout) {
            Object (layout: layout);
        }

        construct {
            unowned string layout_description = dgettext ("xkeyboard-config", layout.description);

            var label = new Gtk.Label (layout.variants != null ? layout_description : _("%s…").printf (layout_description)) {
                ellipsize = Pango.EllipsizeMode.END,
                margin = 6,
                xalign = 0
            };
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            add (label);
            show_all ();
        }
    }

    private class VariantRow : Gtk.ListBoxRow {
        public string? code { get; construct; }
        public string description { get; construct; }

        public VariantRow (string? code, string description) {
            Object (
                code: code,
                description: description
            );
        }

        construct {
            var label = new Gtk.Label (dgettext ("xkeyboard-config", description)) {
                ellipsize = Pango.EllipsizeMode.END,
                margin = 6,
                xalign = 0
            };
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);

            add (label);
            show_all ();
        }
    }
}
