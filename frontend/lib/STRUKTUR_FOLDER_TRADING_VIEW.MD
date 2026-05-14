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
persistence_service.dart — abstraksi baca/tulis Hive
workspace_state.dart WorkspaceState yang auto-save ke Hive

















══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY
╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 68 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/frontend/lib/tr
  ading_screen/tradingviewcodeeditor_screen.dart:809:30

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:46303/mH9TmWiXv3Y=/devtools//#/inspector?uri=http%3A%2F%2F127.0
.0.1%3A46303%2FmH9TmWiXv3Y%3D%2F&inspectorRef=inspector-378






































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


══╡ EXCEPTION CAUGHT BY FOUNDATION LIBRARY ╞════════════════════════════════════════════════════════
The following assertion was thrown while dispatching notifications for ScrollController:
setState() called after dispose(): _OutputConsolePanelState#ffe05(lifecycle state: defunct, not
mounted, ticker inactive)
This error happens if you call setState() on a State object for a widget that no longer appears in
the widget tree (e.g., whose parent widget no longer includes the widget in its build). This error
can occur when code calls setState() from a timer or an animation callback.
The preferred solution is to cancel the timer or stop listening to the animation in the dispose()
callback. Another solution is to check the "mounted" property of this object before calling
setState() to ensure the object is still in the tree.
This error might indicate a memory leak if setState() is being called because another object is
retaining a reference to this State object after it has been removed from the tree. To avoid memory
leaks, consider breaking the reference to this object during dispose().

When the exception was thrown, this was the stack:
#0      State.setState.<anonymous closure> (package:flutter/src/widgets/framework.dart:1163:9)
#1      State.setState (package:flutter/src/widgets/framework.dart:1198:6)
#2      _OutputConsolePanelState._onScrollChanged (package:frontend/trading_screen/tradingview/output_console_panel.dart:107:34)
#3      ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:435:24)
#4      ChangeNotifier.notifyListeners (package:flutter/src/foundation/change_notifier.dart:435:24)
#5      ScrollPosition.notifyListeners (package:flutter/src/widgets/scroll_position.dart:1123:11)
#6      ScrollPosition.setPixels (package:flutter/src/widgets/scroll_position.dart:392:9)
#7      ScrollPositionWithSingleContext.setPixels (package:flutter/src/widgets/scroll_position_with_single_context.dart:87:18)
#8      DrivenScrollActivity.applyMoveTo (package:flutter/src/widgets/scroll_activity.dart:765:21)
#9      DrivenScrollActivity._tick (package:flutter/src/widgets/scroll_activity.dart:751:10)
#10     AnimationLocalListenersMixin.notifyListeners (package:flutter/src/animation/listener_helpers.dart:160:19)
#11     AnimationController._tick (package:flutter/src/animation/animation_controller.dart:957:5)
#12     Ticker._tick (package:flutter/src/scheduler/ticker.dart:269:12)
#13     SchedulerBinding._invokeFrameCallback (package:flutter/src/scheduler/binding.dart:1434:15)
#14     SchedulerBinding.handleBeginFrame.<anonymous closure> (package:flutter/src/scheduler/binding.dart:1265:11)
#15     _LinkedHashMapMixin.forEach (dart:_compact_hash:765:13)
#16     SchedulerBinding.handleBeginFrame (package:flutter/src/scheduler/binding.dart:1263:17)
#17     SchedulerBinding._handleBeginFrame (package:flutter/src/scheduler/binding.dart:1179:5)
#18     _invoke1 (dart:ui/hooks.dart:372:13)
#19     PlatformDispatcher._beginFrame (dart:ui/platform_dispatcher.dart:426:5)
#20     _beginFrame (dart:ui/hooks.dart:317:31)

The ScrollController sending notification was:
  ScrollController#6e482(one client, offset 28.3)
════════════════════════════════════════════════════════════════════════════════════════════════════

Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#a74f9(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#8a3c9(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#f8b88(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#9b9af(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#8ed69(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#e06b1(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#fac73(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#7afc8(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#998a1(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#cb6df(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#9112c(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#cc87b(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#c205d(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#ffe05(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#a74f9(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#8a3c9(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#f8b88(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#9b9af(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#8ed69(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#e06b1(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#fac73(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#7afc8(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#998a1(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#cb6df(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#9112c(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#cc87b(lifecycle state: defunct, not mounted, ticker inactive)
Another exception was thrown: setState() called after dispose(): _OutputConsolePanelState#c205d(lifecycle state: defunct, not mounted, ticker inactive)


