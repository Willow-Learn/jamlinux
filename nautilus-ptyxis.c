// SPDX-FileCopyrightText: 2025 Jake Dane <https://codeberg.org/jakedane>
// SPDX-License-Identifier: GPL-3.0-or-later

/*
 * nautilus-ptyxis.c - Nautilus extension to open directories in Ptyxis
 *
 * Build (Arch Linux): gcc -fPIC -shared nautilus-ptyxis.c -o libnautilus-ptyxis.so \
$(pkg-config --cflags --libs gio-2.0 glib-2.0 gobject-2.0 libnautilus-extension-4)
 * 
 * Install: copy libnautilus-ptyxis.so to /usr/lib/nautilus/extensions-4/ and restart Nautilus.
 */

#include <gio/gio.h>
#include <glib.h>
#include <glib-object.h>
#include <nautilus-extension.h>

// UI strings
static const char MENU_LABEL[] = "Open in Terminal";

// D-Bus call data 
static const char PTYXIS_BUS_NAME[] = "org.gnome.Ptyxis";
static const char PTYXIS_OBJECT_PATH[] = "/org/gnome/Ptyxis";
static const char PTYXIS_INTERFACE[] = "org.freedesktop.Application";
static const char PTYXIS_METHOD[] = "Open";

// Type declarations
typedef struct { GObject parent_instance; } NautilusPtyxis;
typedef struct { GObjectClass parent_class; } NautilusPtyxisClass;

G_DEFINE_TYPE(NautilusPtyxis, nautilus_ptyxis, G_TYPE_OBJECT);

// Callback function which opens the directory in a new Ptyxis window
static void
menu_activate_cb (NautilusMenuItem *item, gpointer user_data)
{
	const char *uri = (const char *) user_data;
	if (!uri) return;

	g_autoptr(GError) error = NULL;

	g_autoptr(GDBusConnection) conn = g_bus_get_sync(G_BUS_TYPE_SESSION, NULL, &error);
	if (!conn) {
		g_warning("Failed to get session bus: %s", error ? error->message : "(unknown)");
		return;
	}

	g_autoptr(GVariant) result = g_dbus_connection_call_sync(
		conn,
		PTYXIS_BUS_NAME,
		PTYXIS_OBJECT_PATH,
		PTYXIS_INTERFACE,
		PTYXIS_METHOD,
		g_variant_new_tuple(
			(GVariant *[]){
				g_variant_new_strv((const char *[]){ uri }, 1),
				g_variant_new("a{sv}", NULL)
			},
			2
		),
		NULL,
		G_DBUS_CALL_FLAGS_NONE,
		-1,
		NULL,
		&error
	);
	if (!result) {
		g_warning(
			"Failed to call %s.%s on %s: %s",
			PTYXIS_INTERFACE,
			PTYXIS_METHOD,
			PTYXIS_BUS_NAME,
			error ? error->message : "(unknown)"
		);
	}
}

// Helper function to add the "Open in Ptyxis" menu item 
static GList *
menu_add_ptyxis (const char *name, NautilusFileInfo *info)
{
	if (!name || !info) return NULL;

	// only local directories
	g_autofree char *uri_scheme = nautilus_file_info_get_uri_scheme(info);
	if (g_strcmp0(uri_scheme, "file") != 0 || !nautilus_file_info_is_directory(info))
		return NULL;

	char *uri = nautilus_file_info_get_uri(info);
	if (!uri) return NULL;

	NautilusMenuItem *item = nautilus_menu_item_new(name, MENU_LABEL, NULL, NULL);
	g_signal_connect_data(
		item,
		"activate",
		G_CALLBACK(menu_activate_cb),
		uri,
		(GClosureNotify) g_free,
		G_CONNECT_DEFAULT
	);
	return g_list_append(NULL, item);
}

/*
 * Nautilus MenuProvider implementation
 */

static GList *
nautilus_ptyxis_get_file_items (NautilusMenuProvider *provider, GList *files)
{
	// only single selection
	if (!files || g_list_next(files) != NULL) return NULL;
	return menu_add_ptyxis(
		"NautilusPtyxis::OpenDirectoryInPtyxis",
		NAUTILUS_FILE_INFO(files->data)
	);
}

static GList *
nautilus_ptyxis_get_background_items (
	NautilusMenuProvider *provider,
	NautilusFileInfo *current_folder
)
{
	if (!current_folder) return NULL;
	return menu_add_ptyxis("NautilusPtyxis::OpenBackgroundInPtyxis", current_folder);
}

static void
nautilus_ptyxis_menu_provider_interface_init (NautilusMenuProviderInterface *iface)
{
	iface->get_file_items = nautilus_ptyxis_get_file_items;
	iface->get_background_items = nautilus_ptyxis_get_background_items;
}

/*
 * Type initialization
 */

static void
nautilus_ptyxis_init (NautilusPtyxis *self)
{
}

static void
nautilus_ptyxis_class_init (NautilusPtyxisClass *klass)
{
}

/*
 * Nautilus Extension API entry points
 */

void
nautilus_module_initialize (GTypeModule *module)
{
	// first call initializes the type
	nautilus_ptyxis_get_type();

	static const GInterfaceInfo iface_info = {
		.interface_init = (GInterfaceInitFunc) nautilus_ptyxis_menu_provider_interface_init,
		.interface_finalize = NULL
	};
	g_type_module_add_interface(
		module,
		nautilus_ptyxis_get_type(),
		NAUTILUS_TYPE_MENU_PROVIDER,
		&iface_info
	);
}

void
nautilus_module_shutdown (void)
{
}

void
nautilus_module_list_types (const GType **types, int *num_types)
{
	g_assert(types != NULL);
	g_assert(num_types != NULL);

	static GType type_list[1] = { 0 };
	type_list[0] = nautilus_ptyxis_get_type();
	*types = type_list;
	*num_types = 1;
}

