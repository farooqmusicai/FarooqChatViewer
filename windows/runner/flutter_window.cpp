#include "flutter_window.h"

#include <optional>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <cstring>
#include "media_preview.h"

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  flutter::MethodChannel<flutter::EncodableValue> clipboard(
      flutter_controller_->engine()->messenger(), "farooq/clipboard",
      &flutter::StandardMethodCodec::GetInstance());
  clipboard.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "copyImage") { result->NotImplemented(); return; }
    const auto* bytes = call.arguments() ? std::get_if<std::vector<uint8_t>>(call.arguments()) : nullptr;
    if (!bytes || bytes->size() < 40 || bytes->size() > 268435456) {
      result->Error("invalid_image", "Invalid image data"); return;
    }
    HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, bytes->size());
    if (!data) { result->Error("memory", "Image too large"); return; }
    void* dest = GlobalLock(data);
    if (!dest) { GlobalFree(data); result->Error("memory", "Could not copy image"); return; }
    std::memcpy(dest, bytes->data(), bytes->size()); GlobalUnlock(data);
    if (!OpenClipboard(GetHandle())) { GlobalFree(data); result->Error("clipboard", "Clipboard busy; try again"); return; }
    EmptyClipboard();
    const auto copied = SetClipboardData(CF_DIB, data);
    CloseClipboard();
    if (!copied) { GlobalFree(data); result->Error("clipboard", "Copy failed"); return; }
    result->Success();
  });

  flutter::MethodChannel<flutter::EncodableValue> media(
      flutter_controller_->engine()->messenger(), "farooq/media",
      &flutter::StandardMethodCodec::GetInstance());
  media.SetMethodCallHandler([this](const auto& call, auto result) {
    const auto* path = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
    if (call.method_name() != "preview" || !path) { result->NotImplemented(); return; }
    int count = MultiByteToWideChar(CP_UTF8, 0, path->c_str(), -1, nullptr, 0);
    if (count <= 1) { result->Error("path", "Invalid media path"); return; }
    std::wstring wide(count, 0);
    MultiByteToWideChar(CP_UTF8, 0, path->c_str(), -1, wide.data(), count);
    LoadMediaPreview(GetHandle(), wide, std::move(result));
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

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
  if (message == kMediaPreviewReady) {
    std::unique_ptr<PreviewReply> reply(reinterpret_cast<PreviewReply*>(lparam));
    if (flutter_controller_) reply->result->Success(flutter::EncodableValue(reply->value));
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
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
