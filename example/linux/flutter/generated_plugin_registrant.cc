//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <universal_file_previewer/file_previewer_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) universal_file_previewer_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FilePreviewerPlugin");
  file_previewer_plugin_register_with_registrar(universal_file_previewer_registrar);
}
