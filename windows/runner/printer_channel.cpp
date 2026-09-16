// ============================================================
//  print_channel.cpp
//  Kologsoft — Silent Windows Printing
//
//  Exposes three methods to Dart via MethodChannel:
//
//    getPrinters        → List<String>   all installed printers
//    getDefaultPrinter  → String         Windows default printer name
//    printPdf           → bool           send raw bytes to printer
//
//  Arguments for printPdf:
//    {
//      "printer" : String      — exact printer name from getPrinters
//      "bytes"   : Uint8List   — raw PDF bytes from pdf.save()
//    }
// ============================================================

#include "printer_channel.h"

#include <flutter/method_channel.h>
#include <flutter/method_result.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <winspool.h>

#include <memory>
#include <string>
#include <vector>

// ------------------------------------------------------------
//  Helper: convert wide string (UTF-16) → UTF-8 std::string
// ------------------------------------------------------------
static std::string WideToUtf8(const std::wstring& wide) {
    if (wide.empty()) return {};
    int size = WideCharToMultiByte(
            CP_UTF8, 0,
            wide.c_str(), static_cast<int>(wide.size()),
            nullptr, 0,
            nullptr, nullptr);
    if (size <= 0) return {};
    std::string result(size, '\0');
    WideCharToMultiByte(
            CP_UTF8, 0,
            wide.c_str(), static_cast<int>(wide.size()),
            &result[0], size,
            nullptr, nullptr);
    return result;
}

// ------------------------------------------------------------
//  Helper: convert UTF-8 std::string → wide string (UTF-16)
// ------------------------------------------------------------
static std::wstring Utf8ToWide(const std::string& utf8) {
    if (utf8.empty()) return {};
    int size = MultiByteToWideChar(
            CP_UTF8, 0,
            utf8.c_str(), static_cast<int>(utf8.size()),
            nullptr, 0);
    if (size <= 0) return {};
    std::wstring result(size, L'\0');
    MultiByteToWideChar(
            CP_UTF8, 0,
            utf8.c_str(), static_cast<int>(utf8.size()),
            &result[0], size);
    return result;
}

// ------------------------------------------------------------
//  GetAllPrinters()
//  Returns UTF-8 names of every printer Windows knows about
//  (local + network connections).
// ------------------------------------------------------------
static flutter::EncodableList GetAllPrinters() {
    flutter::EncodableList list;

    DWORD needed  = 0;
    DWORD returned = 0;

    // First call — get required buffer size
    EnumPrintersW(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            nullptr, 2,
            nullptr, 0,
            &needed, &returned);

    if (needed == 0) return list;   // no printers found

    std::vector<BYTE> buffer(needed);
    BOOL ok = EnumPrintersW(
            PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS,
            nullptr, 2,
            buffer.data(), needed,
            &needed, &returned);

    if (!ok) return list;

    auto* infos = reinterpret_cast<PRINTER_INFO_2W*>(buffer.data());
    for (DWORD i = 0; i < returned; ++i) {
        if (infos[i].pPrinterName) {
            list.push_back(flutter::EncodableValue(
                    WideToUtf8(infos[i].pPrinterName)));
        }
    }
    return list;
}

// ------------------------------------------------------------
//  GetDefaultPrinterName()
//  Returns the Windows default printer name as UTF-8,
//  or empty string if none is set.
// ------------------------------------------------------------
static std::string GetDefaultPrinterName() {
    DWORD size = 0;
    // First call to get the size needed
    GetDefaultPrinterW(nullptr, &size);
    if (size == 0) return {};

    std::wstring wname(size, L'\0');
    if (!GetDefaultPrinterW(&wname[0], &size)) return {};

    // Remove null terminator that GetDefaultPrinterW includes in size
    if (!wname.empty() && wname.back() == L'\0') {
        wname.pop_back();
    }
    return WideToUtf8(wname);
}

// ------------------------------------------------------------
//  PrintRawBytes()
//  Sends raw bytes (PDF) directly to the named printer.
//  Returns true on success.
//
//  NOTE: "RAW" datatype works with:
//    - Thermal / receipt printers (ESC/POS or PCL)
//    - Any printer whose driver accepts raw PDF
//  For inkjet / laser printers that need GDI rendering,
//  see the note at the bottom of this file.
// ------------------------------------------------------------
static bool PrintRawBytes(
        const std::string& printerNameUtf8,
        const std::vector<uint8_t>& bytes,
        std::string& outError) {

    if (printerNameUtf8.empty()) {
        outError = "Printer name is empty";
        return false;
    }
    if (bytes.empty()) {
        outError = "PDF bytes are empty";
        return false;
    }

    std::wstring wPrinterName = Utf8ToWide(printerNameUtf8);

    // ---- Open printer handle ----
    HANDLE hPrinter = nullptr;
    if (!OpenPrinterW(const_cast<LPWSTR>(wPrinterName.c_str()),
                      &hPrinter, nullptr)) {
        outError = "OpenPrinter failed, Win32 error: " +
                   std::to_string(GetLastError());
        return false;
    }

    // ---- Start document ----
    std::wstring docName  = L"Kologsoft Receipt";
    std::wstring dataType = L"RAW";

    DOC_INFO_1W docInfo;
    docInfo.pDocName    = const_cast<LPWSTR>(docName.c_str());
    docInfo.pOutputFile = nullptr;
    docInfo.pDatatype   = const_cast<LPWSTR>(dataType.c_str());

    DWORD jobId = StartDocPrinterW(
            hPrinter, 1,
            reinterpret_cast<LPBYTE>(&docInfo));
    if (jobId == 0) {
        outError = "StartDocPrinter failed, Win32 error: " +
                   std::to_string(GetLastError());
        ClosePrinter(hPrinter);
        return false;
    }

    // ---- Start page ----
    if (!StartPagePrinter(hPrinter)) {
        outError = "StartPagePrinter failed, Win32 error: " +
                   std::to_string(GetLastError());
        EndDocPrinter(hPrinter);
        ClosePrinter(hPrinter);
        return false;
    }

    // ---- Write bytes ----
    DWORD written = 0;
    BOOL writeOk  = WritePrinter(
            hPrinter,
            const_cast<BYTE*>(bytes.data()),
            static_cast<DWORD>(bytes.size()),
            &written);

    DWORD writeError = GetLastError();

    // ---- End page and document ----
    EndPagePrinter(hPrinter);
    EndDocPrinter(hPrinter);
    ClosePrinter(hPrinter);

    if (!writeOk) {
        outError = "WritePrinter failed, Win32 error: " +
                   std::to_string(writeError) +
                   " (wrote " + std::to_string(written) +
                   " of " + std::to_string(bytes.size()) + " bytes)";
        return false;
    }

    return true;
}

// ------------------------------------------------------------
//  PrintRawText()
//  Sends UTF-8 text directly to the printer in RAW mode.
//  Use this for plain-text receipts instead of PDF.
// ------------------------------------------------------------
static bool PrintRawText(const std::string& printerNameUtf8,
                         const std::string& text,
                         std::string& outError) {
    std::vector<uint8_t> bytes(text.begin(), text.end());
    return PrintRawBytes(printerNameUtf8, bytes, outError);
}

// ------------------------------------------------------------
//  RegisterPrintChannel()
//  Call once from FlutterWindow::OnCreate()
// ------------------------------------------------------------
void RegisterPrintChannel(flutter::FlutterEngine* engine) {
    // Static so the channel is never destroyed
    static std::unique_ptr<
    flutter::MethodChannel<flutter::EncodableValue>> sChannel;

    sChannel = std::make_unique<
               flutter::MethodChannel<flutter::EncodableValue>>(
            engine->messenger(),
                    "com.kologsoft/printing",   // <-- must match Dart exactly
                    &flutter::StandardMethodCodec::GetInstance());

    sChannel->SetMethodCallHandler(
            [](const flutter::MethodCall<flutter::EncodableValue>& call,
               std::unique_ptr<flutter::MethodResult<
                       flutter::EncodableValue>> result) {

                // ================================================
                //  METHOD: getPrinters
                //  Returns: List<String>
                // ================================================
                if (call.method_name() == "getPrinters") {
                    auto printers = GetAllPrinters();
                    result->Success(flutter::EncodableValue(printers));
                    return;
                }

                // ================================================
                //  METHOD: getDefaultPrinter
                //  Returns: String
                // ================================================
                if (call.method_name() == "getDefaultPrinter") {
                    std::string def = GetDefaultPrinterName();
                    if (def.empty()) {
                        result->Error(
                                "NO_DEFAULT_PRINTER",
                                "No default printer is configured on this machine",
                                flutter::EncodableValue(false));
                    } else {
                        result->Success(flutter::EncodableValue(def));
                    }
                    return;
                }

                // ================================================
                //  METHOD: printPdf
                //  Args:   { "printer": String, "bytes": Uint8List }
                //  Returns: bool
                // ================================================
                if (call.method_name() == "printPdf") {
                    const auto* args =
                            std::get_if<flutter::EncodableMap>(call.arguments());

                    if (!args) {
                        result->Error(
                                "BAD_ARGS",
                                "Expected a map with 'printer' and 'bytes'",
                                flutter::EncodableValue(false));
                        return;
                    }

                    // Extract "printer" name
                    auto nameIt =
                            args->find(flutter::EncodableValue(std::string("printer")));
                    if (nameIt == args->end()) {
                        result->Error(
                                "MISSING_PRINTER",
                                "Argument 'printer' is required",
                                flutter::EncodableValue(false));
                        return;
                    }
                    const auto* printerName =
                            std::get_if<std::string>(&nameIt->second);
                    if (!printerName || printerName->empty()) {
                        result->Error(
                                "INVALID_PRINTER",
                                "Printer name must be a non-empty string",
                                flutter::EncodableValue(false));
                        return;
                    }

                    // Extract "bytes" (Uint8List arrives as vector<uint8_t>)
                    auto bytesIt =
                            args->find(flutter::EncodableValue(std::string("bytes")));
                    if (bytesIt == args->end()) {
                        result->Error(
                                "MISSING_BYTES",
                                "Argument 'bytes' (Uint8List) is required",
                                flutter::EncodableValue(false));
                        return;
                    }
                    const auto* byteVec =
                            std::get_if<std::vector<uint8_t>>(&bytesIt->second);
                    if (!byteVec || byteVec->empty()) {
                        result->Error(
                                "INVALID_BYTES",
                                "Bytes must be a non-empty Uint8List",
                                flutter::EncodableValue(false));
                        return;
                    }

                    // Send to printer
                    std::string error;
                    bool ok = PrintRawBytes(*printerName, *byteVec, error);
                    if (ok) {
                        result->Success(flutter::EncodableValue(true));
                    } else {
                        result->Error(
                                "PRINT_FAILED",
                                error,
                                flutter::EncodableValue(false));
                    }
                    return;
                }

                // ================================================
                //  METHOD: printText
                //  Args:   { "printer": String, "text": String }
                //  Returns: bool
                // ================================================
                if (call.method_name() == "printText") {
                    const auto* args =
                            std::get_if<flutter::EncodableMap>(call.arguments());

                    if (!args) {
                        result->Error(
                                "BAD_ARGS",
                                "Expected a map with 'printer' and 'text'",
                                flutter::EncodableValue(false));
                        return;
                    }

                    auto nameIt =
                            args->find(flutter::EncodableValue(std::string("printer")));
                    if (nameIt == args->end()) {
                        result->Error(
                                "MISSING_PRINTER",
                                "Argument 'printer' is required",
                                flutter::EncodableValue(false));
                        return;
                    }
                    const auto* printerName =
                            std::get_if<std::string>(&nameIt->second);
                    if (!printerName || printerName->empty()) {
                        result->Error(
                                "INVALID_PRINTER",
                                "Printer name must be a non-empty string",
                                flutter::EncodableValue(false));
                        return;
                    }

                    auto textIt =
                            args->find(flutter::EncodableValue(std::string("text")));
                    if (textIt == args->end()) {
                        result->Error(
                                "MISSING_TEXT",
                                "Argument 'text' is required",
                                flutter::EncodableValue(false));
                        return;
                    }
                    const auto* text =
                            std::get_if<std::string>(&textIt->second);
                    if (!text || text->empty()) {
                        result->Error(
                                "INVALID_TEXT",
                                "Text must be a non-empty string",
                                flutter::EncodableValue(false));
                        return;
                    }

                    std::string error;
                    bool ok = PrintRawText(*printerName, *text, error);
                    if (ok) {
                        result->Success(flutter::EncodableValue(true));
                    } else {
                        result->Error(
                                "PRINT_FAILED",
                                error,
                                flutter::EncodableValue(false));
                    }
                    return;
                }

                // ================================================
                //  Unknown method
                // ================================================
                result->NotImplemented();
            });
}

// ============================================================
//  NOTE — RAW vs GDI printing
//
//  RAW mode sends bytes directly to the printer driver.
//  This works for:
//    ✅ Thermal receipt printers  (Epson TM, Xprinter, etc.)
//    ✅ Printers with PDF-capable drivers (many modern lasers)
//    ✅ Printers set to accept raw PCL/PostScript
//
//  If you see a blank page or garbled output on a laser/inkjet:
//  the printer driver needs Windows GDI rendering instead.
//  In that case render the PDF to a bitmap first using a library
//  like PDFium, then send as a DIB to the printer DC.
// ============================================================