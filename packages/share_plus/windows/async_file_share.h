#pragma once
#include "share_plus_windows_plugin.h"
#include "vector.h"
namespace share_plus_windows {
// File resolution must yield to the STA message loop. Blocking here prevents
// Windows from completing the share request and freezes the Flutter window.
class AsyncFileShare : public std::enable_shared_from_this<AsyncFileShare> {
 public:
  WRL::ComPtr<DataTransfer::IDataRequest> request;
  WRL::ComPtr<DataTransfer::IDataRequestDeferral> deferral;
  WRL::ComPtr<DataTransfer::IDataPackage> data;
  WRL::ComPtr<Vector<WindowsStorage::IStorageItem*>> items =
      WRL::Make<Vector<WindowsStorage::IStorageItem*>>();
  std::vector<std::wstring> paths;
  size_t index = 0;

  void Finish(HRESULT hr) {
    if (FAILED(hr)) {
      request->FailWithDisplayText(WRL::Wrappers::HStringReference(
          L"This file could not be shared. Check that it is available locally, then try again.").Get());
    }
    deferral->Complete();
  }

  void Next() {
    if (index == paths.size()) {
      Finish(data->SetStorageItemsReadOnly(items.Get()));
      return;
    }
    WRL::ComPtr<WindowsStorage::IStorageFileStatics> factory;
    HRESULT hr = WindowsFoundation::GetActivationFactory(
        WRL::Wrappers::HStringReference(RuntimeClass_Windows_Storage_StorageFile).Get(),
        &factory);
    if (FAILED(hr)) { Finish(hr); return; }
    WRL::ComPtr<WindowsFoundation::IAsyncOperation<WindowsStorage::StorageFile*>> op;
    hr = factory->GetFileFromPathAsync(
        WRL::Wrappers::HStringReference(paths[index++].c_str()).Get(), &op);
    if (FAILED(hr)) { Finish(hr); return; }
    auto self = shared_from_this();
    hr = op->put_Completed(WRL::Callback<WindowsFoundation::IAsyncOperationCompletedHandler<WindowsStorage::StorageFile*>>(
        [self](WindowsFoundation::IAsyncOperation<WindowsStorage::StorageFile*>* operation,
               WindowsFoundation::AsyncStatus status) -> HRESULT {
          if (status != WindowsFoundation::AsyncStatus::Completed) {
            self->Finish(E_FAIL);
            return S_OK;
          }
          WRL::ComPtr<WindowsStorage::IStorageFile> file;
          HRESULT result = operation->GetResults(&file);
          WRL::ComPtr<WindowsStorage::IStorageItem> item;
          if (SUCCEEDED(result)) result = file.As(&item);
          if (SUCCEEDED(result)) result = self->items->Append(item.Get());
          if (FAILED(result)) self->Finish(result);
          else self->Next();
          return S_OK;
        }).Get());
    if (FAILED(hr)) Finish(hr);
  }
};

}
