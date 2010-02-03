/***
  This file is part of systemd.

  Copyright 2010 Lennart Poettering

  systemd is free software; you can redistribute it and/or modify it
  under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  systemd is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with systemd; If not, see <http://www.gnu.org/licenses/>.
***/

using Gtk;
using GLib;
using DBus;
using Pango;

public class LeftLabel : Label {
        public LeftLabel(string? text = null) {
                if (text != null)
                        set_markup("<b>%s</b>".printf(text));
                set_alignment(1, 0);
                set_padding(6, 0);
        }
}

public class RightLabel : Label {
        public RightLabel(string? text = null) {
                set_text_or_na(text);
                set_alignment(0, 1);
                set_ellipsize(EllipsizeMode.START);
                set_selectable(true);
        }

        public void set_text_or_na(string? text = null) {
                if (text == null || text == "")
                        set_markup("<i>n/a</i>");
                else
                        set_text(text);
        }
}

public class MainWindow : Window {

        private TreeView unit_view;
        private TreeView job_view;

        private ListStore unit_model;
        private ListStore job_model;

        private Button start_button;
        private Button stop_button;
        private Button restart_button;
        private Button reload_button;
        private Button cancel_button;

        private Connection bus;
        private Manager manager;

        private RightLabel unit_id_label;
        private RightLabel unit_description_label;
        private RightLabel unit_load_state_label;
        private RightLabel unit_active_state_label;
        private RightLabel unit_load_path_label;
        private RightLabel unit_active_enter_timestamp_label;
        private RightLabel unit_active_exit_timestamp_label;
        private RightLabel unit_can_start_label;
        private RightLabel unit_can_reload_label;

        private RightLabel job_id_label;
        private RightLabel job_state_label;
        private RightLabel job_type_label;

        public MainWindow() throws DBus.Error {
                title = "systemdadm";
                position = WindowPosition.CENTER;
                set_default_size(1000, 700);
                set_border_width(12);
                destroy.connect(Gtk.main_quit);

                Notebook notebook = new Notebook();
                add(notebook);

                Box unit_vbox = new VBox(false, 6);
                notebook.append_page(unit_vbox, new Label("Units"));
                unit_vbox.set_border_width(12);

                Box job_vbox = new VBox(false, 6);
                notebook.append_page(job_vbox, new Label("Jobs"));
                job_vbox.set_border_width(12);


                unit_model = new ListStore(6, typeof(string), typeof(string), typeof(string), typeof(string), typeof(string), typeof(string), typeof(string));
                job_model = new ListStore(5, typeof(string), typeof(string), typeof(string), typeof(string), typeof(string), typeof(string));

                unit_view = new TreeView.with_model(unit_model);
                job_view = new TreeView.with_model(job_model);

                unit_view.cursor_changed.connect(unit_changed);
                job_view.cursor_changed.connect(job_changed);

                unit_view.insert_column_with_attributes(-1, "Unit", new CellRendererText(), "text", 0);
                unit_view.insert_column_with_attributes(-1, "Description", new CellRendererText(), "text", 1);
                unit_view.insert_column_with_attributes(-1, "Load State", new CellRendererText(), "text", 2);
                unit_view.insert_column_with_attributes(-1, "Active State", new CellRendererText(), "text", 3);
                unit_view.insert_column_with_attributes(-1, "Job", new CellRendererText(), "text", 4);

                job_view.insert_column_with_attributes(-1, "Job", new CellRendererText(), "text", 0);
                job_view.insert_column_with_attributes(-1, "Unit", new CellRendererText(), "text", 1);
                job_view.insert_column_with_attributes(-1, "Type", new CellRendererText(), "text", 2);
                job_view.insert_column_with_attributes(-1, "State", new CellRendererText(), "text", 3);

                ScrolledWindow scroll = new ScrolledWindow(null, null);
                scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
                scroll.set_shadow_type(ShadowType.IN);
                scroll.add(unit_view);
                unit_vbox.pack_start(scroll, true, true, 0);

                scroll = new ScrolledWindow(null, null);
                scroll.set_policy(PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
                scroll.set_shadow_type(ShadowType.IN);
                scroll.add(job_view);
                job_vbox.pack_start(scroll, true, true, 0);

                unit_id_label = new RightLabel();
                unit_description_label = new RightLabel();
                unit_load_state_label = new RightLabel();
                unit_active_state_label = new RightLabel();
                unit_load_path_label = new RightLabel();
                unit_active_enter_timestamp_label = new RightLabel();
                unit_active_exit_timestamp_label = new RightLabel();
                unit_can_start_label = new RightLabel();
                unit_can_reload_label = new RightLabel();

                job_id_label = new RightLabel();
                job_state_label = new RightLabel();
                job_type_label = new RightLabel();

                Table unit_table = new Table(9, 2, false);
                unit_table.set_row_spacings(6);
                unit_table.set_border_width(12);
                unit_vbox.pack_start(unit_table, false, true, 0);

                Table job_table = new Table(2, 2, false);
                job_table.set_row_spacings(6);
                job_table.set_border_width(12);
                job_vbox.pack_start(job_table, false, true, 0);

                unit_table.attach(new LeftLabel("Id:"), 0, 1, 0, 1, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_id_label, 1, 2, 0, 1, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Description:"), 0, 1, 1, 2, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_description_label, 1, 2, 1, 2, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Load State:"), 0, 1, 2, 3, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_load_state_label, 1, 2, 2, 3, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Active State:"), 0, 1, 3, 4, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_active_state_label, 1, 2, 3, 4, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Load Path:"), 0, 1, 4, 5, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_load_path_label, 1, 2, 4, 5, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Active Enter Timestamp:"), 0, 1, 5, 6, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_active_enter_timestamp_label, 1, 2, 5, 6, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Active Exit Timestamp:"), 0, 1, 6, 7, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_active_exit_timestamp_label, 1, 2, 6, 7, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Can Start/Stop:"), 0, 1, 7, 8, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_can_start_label, 1, 2, 7, 8, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(new LeftLabel("Can Reload:"), 0, 1, 8, 9, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                unit_table.attach(unit_can_reload_label, 1, 2, 8, 9, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);

                job_table.attach(new LeftLabel("Id:"), 0, 1, 0, 1, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                job_table.attach(job_id_label, 1, 2, 0, 1, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                job_table.attach(new LeftLabel("State:"), 0, 1, 1, 2, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                job_table.attach(job_state_label, 1, 2, 1, 2, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                job_table.attach(new LeftLabel("Type:"), 0, 1, 2, 3, AttachOptions.FILL, AttachOptions.FILL, 0, 0);
                job_table.attach(job_type_label, 1, 2, 2, 3, AttachOptions.EXPAND|AttachOptions.FILL, AttachOptions.FILL, 0, 0);

                ButtonBox bbox = new HButtonBox();
                bbox.set_layout(ButtonBoxStyle.START);
                bbox.set_spacing(6);
                unit_vbox.pack_start(bbox, false, true, 0);

                start_button = new Button.with_mnemonic("_Start");
                stop_button = new Button.with_mnemonic("Sto_p");
                reload_button = new Button.with_mnemonic("_Reload");
                restart_button = new Button.with_mnemonic("Res_tart");

                start_button.clicked.connect(on_start);
                stop_button.clicked.connect(on_stop);
                reload_button.clicked.connect(on_reload);
                restart_button.clicked.connect(on_restart);

                bbox.pack_start(start_button, false, true, 0);
                bbox.pack_start(stop_button, false, true, 0);
                bbox.pack_start(restart_button, false, true, 0);
                bbox.pack_start(reload_button, false, true, 0);

                bbox = new HButtonBox();
                bbox.set_layout(ButtonBoxStyle.START);
                bbox.set_spacing(6);
                job_vbox.pack_start(bbox, false, true, 0);

                cancel_button = new Button.with_mnemonic("_Cancel");

                cancel_button.clicked.connect(on_cancel);

                bbox.pack_start(cancel_button, false, true, 0);

                bus = Bus.get(BusType.SESSION);

                manager = bus.get_object (
                                "org.freedesktop.systemd1",
                                "/org/freedesktop/systemd1",
                                "org.freedesktop.systemd1") as Manager;

                clear_unit();
                populate_unit_model();
                populate_job_model();
        }

        public void populate_unit_model() throws DBus.Error {
                unit_model.clear();

                var list = manager.list_units();

                foreach (var i in list) {
                        TreeIter iter;

                        unit_model.append(out iter);
                        unit_model.set(iter,
                                       0, i.id,
                                       1, i.description,
                                       2, i.load_state,
                                       3, i.active_state,
                                       4, i.job_type != "" ? "→ %s".printf(i.job_type) : "",
                                       5, i.unit_path);
                }
        }

        public void populate_job_model() throws DBus.Error {
                job_model.clear();

                var list = manager.list_jobs();

                foreach (var i in list) {
                        TreeIter iter;

                        job_model.append(out iter);
                        job_model.set(iter,
                                      0, "%u".printf(i.id),
                                      1, i.name,
                                      2, "→ %s".printf(i.type),
                                      3, i.state,
                                      4, i.job_path);
                }
        }

        public Unit? get_current_unit() {
                TreePath p;
                unit_view.get_cursor(out p, null);

                if (p == null)
                        return null;

                TreeIter iter;
                string path;

                unit_model.get_iter(out iter, p);
                unit_model.get(iter, 5, out path);

                return bus.get_object (
                                "org.freedesktop.systemd1",
                                path,
                                "org.freedesktop.systemd1.Unit") as Unit;
        }

        public void unit_changed() {
                Unit u = get_current_unit();

                if (u == null)
                        clear_unit();
                else
                        show_unit(u);
        }

        public void clear_unit() {
                start_button.set_sensitive(false);
                stop_button.set_sensitive(false);
                reload_button.set_sensitive(false);
                restart_button.set_sensitive(false);

                unit_id_label.set_text_or_na();
                unit_description_label.set_text_or_na();
                unit_load_state_label.set_text_or_na();
                unit_active_state_label.set_text_or_na();
                unit_load_path_label.set_text_or_na();
                unit_active_enter_timestamp_label.set_text_or_na();
                unit_active_exit_timestamp_label.set_text_or_na();
                unit_can_reload_label.set_text_or_na();
                unit_can_start_label.set_text_or_na();
        }

        public void show_unit(Unit unit) {
                unit_id_label.set_text_or_na(unit.id);
                unit_description_label.set_text_or_na(unit.description);
                unit_load_state_label.set_text_or_na(unit.load_state);
                unit_active_state_label.set_text_or_na(unit.active_state);
                unit_load_path_label.set_text_or_na(unit.load_path);

                uint64 t = unit.active_enter_timestamp;
                if (t > 0) {
                        TimeVal tv = { (long) (t / 1000000), (long) (t % 1000000) };
                        unit_active_enter_timestamp_label.set_text_or_na(tv.to_iso8601());
                } else
                        unit_active_enter_timestamp_label.set_text_or_na();

                t = unit.active_exit_timestamp;
                if (t > 0) {
                        TimeVal tv = { (long) (t / 1000000), (long) (t % 1000000) };
                        unit_active_exit_timestamp_label.set_text_or_na(tv.to_iso8601());
                } else
                        unit_active_exit_timestamp_label.set_text_or_na();

                bool b = unit.can_start;
                start_button.set_sensitive(b);
                stop_button.set_sensitive(b);
                restart_button.set_sensitive(b);
                unit_can_start_label.set_text_or_na(b ? "Yes" : "No");

                b = unit.can_reload;
                reload_button.set_sensitive(b);
                unit_can_reload_label.set_text_or_na(b ? "Yes" : "No");
        }

        public Job? get_current_job() {
                TreePath p;
                job_view.get_cursor(out p, null);

                if (p == null)
                        return null;

                TreeIter iter;
                string path;

                job_model.get_iter(out iter, p);
                job_model.get(iter, 4, out path);

                return bus.get_object (
                                "org.freedesktop.systemd1",
                                path,
                                "org.freedesktop.systemd1.Job") as Job;
        }

        public void job_changed() {
                Job j = get_current_job();

                if (j == null)
                        clear_job();
                else
                        show_job(j);
        }

        public void clear_job() {
                job_id_label.set_text_or_na();
                job_state_label.set_text_or_na();
                job_type_label.set_text_or_na();
        }

        public void show_job(Job job) {
                job_id_label.set_text_or_na("%u".printf(job.id));
                job_state_label.set_text_or_na(job.state);
                job_type_label.set_text_or_na(job.job_type);
        }

        public void on_start() {
                Unit u = get_current_unit();

                if (u == null)
                        return;

                try {
                        u.start("replace");
                } catch (DBus.Error e) {
                        message("%s", e.message);
                }
        }

        public void on_stop() {
                Unit u = get_current_unit();

                if (u == null)
                        return;

                try {
                        u.stop("replace");
                } catch (DBus.Error e) {
                        message("%s", e.message);
                }
        }

        public void on_reload() {
                Unit u = get_current_unit();

                if (u == null)
                        return;

                try {
                        u.reload("replace");
                } catch (DBus.Error e) {
                        message("%s", e.message);
                }
        }

        public void on_restart() {
                Unit u = get_current_unit();

                if (u == null)
                        return;

                try {
                        u.restart("replace");
                } catch (DBus.Error e) {
                        message("%s", e.message);
                }
        }

        public void on_cancel() {
                Job j = get_current_job();

                if (j == null)
                        return;

                try {
                        j.cancel();
                } catch (DBus.Error e) {
                        message("%s", e.message);
                }
        }
}

int main (string[] args) {
        Gtk.init(ref args);

        try {
                MainWindow window = new MainWindow();
                window.show_all();
        } catch (DBus.Error e) {
                message("%s", e.message);
        }

        Gtk.main();
        return 0;
}