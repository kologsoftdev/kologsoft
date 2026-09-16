// ============================================================
//  flutter_window.cpp
//  Kologsoft — Modified to register the silent print channel
//
//  CHANGES FROM THE DEFAULT FLUTTER TEMPLATE:
//    Line 6  : #include "printer_channel.h"   ← ADDED
//    Line 47 : RegisterPrintChannel(...)    ← ADDED
//
//  Everything else is exactly as Flutter generates it.
// ============================================================

#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "printer_channel.h"    // ← ADDED: Kologsoft silent printing

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
        : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
    if (!Win32Window::OnCreate()) {
        return false;
    }

    RECT frame = GetClientArea();

    // The size here must match the window dimensions to avoid
    // gaps in the framework's hot reload.
    flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
            frame.right - frame.left, frame.bottom - frame.top, project_);

    // Ensure that basic setup of the controller was successful.
    if (!flutter_controller_->engine() ||
        !flutter_controller_->view()) {
        return false;
    }

    RegisterPlugins(flutter_controller_->engine());

    // --------------------------------------------------------
    //  ADDED: Register Kologsoft silent printing channel.
    //  This must come AFTER RegisterPlugins() so the engine
    //  messenger is fully initialised.
    // --------------------------------------------------------
    RegisterPrintChannel(flutter_controller_->engine());
    // --------------------------------------------------------

    SetChildContent(flutter_controller_->view()->GetNativeWindow());

    flutter_controller_->engine()->SetNextFrameCallback([&]() {
        this->Show();
    });

    // Flutter can complete the first frame before the "show window"
    // is handled by GetMessage. Force a flush so the window shows.
    ::ShowWindow(GetHandle(), SW_SHOW);
    ::UpdateWindow(GetHandle());

    return true;
}

void FlutterWindow::OnDestroy() {
    if (flutter_controller_) {
        flutter_controller_ = nullptr;
    }
    Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
// Give Flutter, including plugins, an opportunity to service the
// message.
if (flutter_controller_) {
std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message,
                                                      wparam, lparam);
if (result) {
return *result;
}
}

switch (message) {
case WM_FONTCHANGE:
flutter_controller_->engine()->ReloadSystemFonts();
break;
}

return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}