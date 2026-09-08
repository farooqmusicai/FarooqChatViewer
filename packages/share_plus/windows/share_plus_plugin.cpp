#include "share_plus_windows_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include "vector.h"
#include "async_file_share.h"

namespace share_plus_windows {

void SharePlusWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kSharePlusChannelName,
          &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<SharePlusWindowsPlugin>(registrar);
  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SharePlusWindowsPlugin::SharePlusWindowsPlugin(
    flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {}

SharePlusWindowsPlugin::~SharePlusWindowsPlugin() {
  if (data_transfer_manager_ != nullptr) {
    data_transfer_manager_->remove_DataRequested(data_transfer_manager_token_);
    data_transfer_manager_.Reset();
  }
  if (data_transfer_manager_interop_ != nullptr) {
    data_transfer_manager_interop_.Reset();
  }
}

HWND SharePlusWindowsPlugin::GetWindow() {
  return ::GetAncestor(registrar_->GetView()->GetNativeWindow(), GA_ROOT);
}

WRL::ComPtr<DataTransfer::IDataTransferManager>
SharePlusWindowsPlugin::GetDataTransferManager() {
  using Microsoft::WRL::Wrappers::HStringReference;
  HRESULT hr = ::RoGetActivationFactory(
      HStringReference(
          RuntimeClass_Windows_ApplicationModel_DataTransfer_DataTransferManager)
          .Get(),
      IID_PPV_ARGS(&data_transfer_manager_interop_));
  if (FAILED(hr)) return nullptr;
  hr = data_transfer_manager_interop_->GetForWindow(
      GetWindow(), IID_PPV_ARGS(&data_transfer_manager_));
  if (FAILED(hr)) return nullptr;
  return data_transfer_manager_;
}

void SharePlusWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Handle the share method.
  if (method_call.method_name().compare(kShare) == 0) {
    // A new share must never retain a previous message or attachment.
    share_text_.reset();
    share_subject_.reset();
    share_uri_.reset();
    share_title_.reset();
    paths_.clear();
    mime_types_.clear();
    if (data_transfer_manager_ != nullptr) {
      data_transfer_manager_->remove_DataRequested(data_transfer_manager_token_);
    }
    auto data_transfer_manager = GetDataTransferManager();
    if (!data_transfer_manager) { result->Error("share_unavailable", "Windows sharing is unavailable"); return; }
    auto args = std::get<flutter::EncodableMap>(*method_call.arguments());

    // Extract the text, subject, uri, title, paths and mimeTypes from the arguments
    if (auto text_value = std::get_if<std::string>(
            &args[flutter::EncodableValue("text")])) {
      share_text_ = *text_value;
    }
    if (auto subject_value = std::get_if<std::string>(
            &args[flutter::EncodableValue("subject")])) {
      share_subject_ = *subject_value;
    }
    if (auto uri_value = std::get_if<std::string>(
      &args[flutter::EncodableValue("uri")])) {
      share_uri_ = *uri_value;
    }
    if (auto title_value = std::get_if<std::string>(
      &args[flutter::EncodableValue("title")])) {
      share_title_ = *title_value;
    }
    if (auto paths = std::get_if<flutter::EncodableList>(
      &args[flutter::EncodableValue("paths")])) {
      paths_.clear();
      for (auto& path : *paths) {
        paths_.emplace_back(std::get<std::string>(path));
      }
    }
    if (auto mime_types = std::get_if<flutter::EncodableList>(
      &args[flutter::EncodableValue("mimeTypes")])) {
      mime_types_.clear();
      for (auto& mime_type : *mime_types) {
        mime_types_.emplace_back(std::get<std::string>(mime_type));
      }
    }

    // Snapshot this share; a later share cannot change an outstanding request.
    auto text_snapshot = share_text_;
    auto subject_snapshot = share_subject_;
    auto uri_snapshot = share_uri_;
    auto title_snapshot = share_title_;
    auto paths_snapshot = paths_;
    // Create the share callback
    auto callback = WRL::Callback<WindowsFoundation::ITypedEventHandler<
        DataTransfer::DataTransferManager *,
        DataTransfer::DataRequestedEventArgs *>>(
        [text_snapshot, subject_snapshot, uri_snapshot, title_snapshot, paths_snapshot](auto &&, DataTransfer::IDataRequestedEventArgs *e) {
          using Microsoft::WRL::Wrappers::HStringReference;
          WRL::ComPtr<DataTransfer::IDataRequest> request;
          e->get_Request(&request);
          WRL::ComPtr<DataTransfer::IDataPackage> data;
          request->get_Data(&data);
          WRL::ComPtr<DataTransfer::IDataPackagePropertySet> properties;
          data->get_Properties(&properties);

          // Set the title of the share dialog
          // Prefer the title, then the subject, then the text
          // Setting a title is mandatory for Windows
          if (title_snapshot && !title_snapshot.value_or("").empty()) {
            auto title = Utf16FromUtf8(title_snapshot.value_or(""));
            properties->put_Title(HStringReference(title.c_str()).Get());
          }
          else if (subject_snapshot && !subject_snapshot.value_or("").empty()) {
            auto title = Utf16FromUtf8(subject_snapshot.value_or(""));
            properties->put_Title(HStringReference(title.c_str()).Get());
          }
          else {
            auto title = Utf16FromUtf8(text_snapshot.value_or(""));
            properties->put_Title(HStringReference(title.c_str()).Get());
          }

          // Set the text of the share dialog
          if (text_snapshot && !text_snapshot.value_or("").empty()) {
            auto text = Utf16FromUtf8(text_snapshot.value_or(""));
            properties->put_Description(
                HStringReference(text.c_str()).Get());
            data->SetText(HStringReference(text.c_str()).Get());
          }

          // If URI provided, set the URI to share
          if (uri_snapshot && !uri_snapshot.value_or("").empty()) {
            auto uri = Utf16FromUtf8(uri_snapshot.value_or(""));
            properties->put_Description(
              HStringReference(uri.c_str()).Get());
            WRL::ComPtr<WindowsFoundation::IUriRuntimeClassFactory> factory;
            WRL::ComPtr<WindowsFoundation::IUriRuntimeClass> web_uri;
            HRESULT hr = WindowsFoundation::GetActivationFactory(
                HStringReference(RuntimeClass_Windows_Foundation_Uri).Get(), &factory);
            if (SUCCEEDED(hr)) hr = factory->CreateUri(HStringReference(uri.c_str()).Get(), &web_uri);
            WRL::ComPtr<DataTransfer::IDataPackage2> data2;
            if (SUCCEEDED(hr) && SUCCEEDED(data.As(&data2))) data2->SetWebLink(web_uri.Get());
            else data->SetText(HStringReference(uri.c_str()).Get());
          }

          // Keep both the request and heap-owned collection alive across async
          // completion. A stack Vector is invalid once this callback returns.
          if (!paths_snapshot.empty()) {
            auto pending = std::make_shared<AsyncFileShare>();
            pending->request = request;
            pending->data = data;
            HRESULT hr = request->GetDeferral(&pending->deferral);
            if (FAILED(hr)) return hr;
            for (const auto& path : paths_snapshot) {
              pending->paths.push_back(Utf16FromUtf8(path));
            }
            pending->Next();
          }

          return S_OK;
        });

    // Add the callback to the data transfer manager
    HRESULT hr = data_transfer_manager->add_DataRequested(callback.Get(), &data_transfer_manager_token_);
    if (SUCCEEDED(hr) && data_transfer_manager_interop_ != nullptr) {
      hr = data_transfer_manager_interop_->ShowShareUIForWindow(GetWindow());
    }
    if (FAILED(hr)) { result->Error("share_failed", "Windows could not open sharing"); return; }
    result->Success(flutter::EncodableValue(kShareResultUnavailable));
  } else {
    result->NotImplemented();
  }
}

// Converts string encoded in UTF-8 to wstring.
// Returns an empty |std::wstring| on failure.
// Present as static helper method.
std::wstring SharePlusWindowsPlugin::Utf16FromUtf8(std::string string) {
  int size_needed =
      MultiByteToWideChar(CP_UTF8, 0, string.c_str(), -1, NULL, 0);
  if (size_needed == 0) {
    return std::wstring();
  }
  std::wstring result(size_needed, 0);
  int converted_length = MultiByteToWideChar(CP_UTF8, 0, string.c_str(), -1,
                                             &result[0], size_needed);
  if (converted_length == 0) {
    return std::wstring();
  }
  return result;
}

} // namespace share_plus_windows

