screen/
└── tradingviewcodeeditor_screen.dart          # Main editor screen (layout utama)

hooks/
└── tradingview_hook.dart            # State: file tree, active file, tabs

pages/
└── tradingview_pages.dart           # Admin → bisa buat, edit, delete indikator "public/shared" + akses semua
Exclusive → bisa buat indikator pribadi + pakai indikator admin, tapi ga bisa edit/delete punya admin
File/folder isolation → kode user lain ga keliatan sama sekali, setiap user cuma lihat punyanya sendiri + yang admin publish

postingan/
└── postingan_tradingview.dart       # (optional) preview script cards

style/
└── apps_colors_tradingview.dart     # Dark theme colors khusus editor

trading_screen/                      # Folder ini udah ada, expand aja
├── tradeview_screen.dart            # (existing)
└── tradingview/                     # Sub-folder khusus editor components
    ├── file_explorer_panel.dart     # Sidebar: folder & file tree
    ├── folder_tree_tile.dart        # Widget: collapsible folder
    ├── file_tile.dart               # Widget: file item
    ├── context_menu_file.dart       # Right-click: rename, delete, new
    ├── code_editor_widget.dart      # Core: Python text editor
    ├── editor_tab_bar.dart          # Multi-tab open files
    ├── editor_toolbar.dart          # Save, Run, Format buttons
    ├── line_number_gutter.dart      # Nomor baris
    ├── output_console_panel.dart    # Output bawah
    └── resizable_divider.dart       # Drag resize panel

models/
├── chart_state.dart                 # (existing)
├── chart_theme.dart                 # (existing)
├── script_file.dart                 # NEW: model file Python
└── script_folder.dart              # NEW: model folder

utils/
├── auth_storage.dart                # (existing)
├── constants.dart                   # (existing)
├── helpers.dart                     # (existing)
├── role_guard.dart                  # (existing) — ini dipake buat guard admin
└── python_syntax_highlighter.dart  # NEW: tokenizer Python






















































══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 32 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/frontend/lib/tr
  ading_screen/tradingview/output_console_panel.dart:541:55

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:41361/dXLgIN8ojDc=/devtools//#/inspector?uri=http%3A%2F%2F127.0
.0.1%3A41361%2FdXLgIN8ojDc%3D%2F&inspectorRef=inspector-207

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering
with a yellow and
black striped pattern. This is usually caused by the contents being too big for
the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the
children of the
RenderFlex to fit within the available space instead of being sized to their
natural size.
This is considered an error condition because it indicates that there is content
that cannot be
seen. If the content is legitimately bigger than the available space, consider
clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container
rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#03bb7 relayoutBoundary=up1
OVERFLOWING:
  creator: Column ← Center ← _EmptyConsole ← _OutputTab ← Semantics ←
  KeyedSubtree-[<0>] ←
    RepaintBoundary ← IndexedSemantics ← _SelectionKeepAlive ←
    NotificationListener<KeepAliveNotification> ← KeepAlive ← AutomaticKeepAlive
    ← ⋯
  parentData: offset=Offset(750.1, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=1674.0, 0.0<=h<=21.0)
  size: Size(173.9, 21.0)
  direction: vertical
  mainAxisAlignment: center
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════
════════════════════

Performing hot reload...                                                
Reloaded 0 libraries in 160ms (compile: 8 ms, reload: 0 ms, reassemble: 97 ms).


══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 32 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/frontend/lib/tr
  ading_screen/tradingview/output_console_panel.dart:541:55

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:41361/dXLgIN8ojDc=/devtools//#/inspector?uri=http%3A%2F%2F127.0
.0.1%3A41361%2FdXLgIN8ojDc%3D%2F&inspectorRef=inspector-207

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering
with a yellow and
black striped pattern. This is usually caused by the contents being too big for
the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the
children of the
RenderFlex to fit within the available space instead of being sized to their
natural size.
This is considered an error condition because it indicates that there is content
that cannot be
seen. If the content is legitimately bigger than the available space, consider
clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container
rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#03bb7 relayoutBoundary=up1
OVERFLOWING:
  creator: Column ← Center ← _EmptyConsole ← _OutputTab ← Semantics ←
  KeyedSubtree-[<0>] ←
    RepaintBoundary ← IndexedSemantics ← _SelectionKeepAlive ←
    NotificationListener<KeepAliveNotification> ← KeepAlive ← AutomaticKeepAlive
    ← ⋯
  parentData: offset=Offset(750.1, 0.0) (can use size)
  constraints: BoxConstraints(0.0<=w<=1674.0, 0.0<=h<=21.0)
  size: Size(173.9, 21.0)
  direction: vertical
  mainAxisAlignment: center
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════
════════════════════
