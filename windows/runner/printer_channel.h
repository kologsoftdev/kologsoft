#ifndef PRINT_CHANNEL_H_
#define PRINT_CHANNEL_H_

// ============================================================
//  print_channel.h
//  Kologsoft — Silent Windows Printing
//
//  Include this header in flutter_window.cpp and call
//  RegisterPrintChannel() once after the FlutterViewController
//  is created.
// ============================================================

#include <flutter/flutter_engine.h>

// Registers the "com.kologsoft/printing" MethodChannel.
// Must be called once from FlutterWindow::OnCreate() after
// flutter_controller_ has been constructed.
void RegisterPrintChannel(flutter::FlutterEngine* engine);

#endif  // PRINT_CHANNEL_H_