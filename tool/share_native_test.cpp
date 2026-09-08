#include "async_file_share.h"
#include <iostream>
#include <atomic>
#include <chrono>
using namespace share_plus_windows;
class TestDeferral : public WRL::RuntimeClass<DataTransfer::IDataRequestDeferral> {
 public:
  std::atomic<int> completed{0};
  HRESULT STDMETHODCALLTYPE Complete() override { ++completed; return S_OK; }
};
class TestRequest : public WRL::RuntimeClass<DataTransfer::IDataRequest> {
 public:
  WRL::ComPtr<DataTransfer::IDataPackage> data;
  WRL::ComPtr<TestDeferral> deferral = WRL::Make<TestDeferral>();
  bool failed = false;
  HRESULT STDMETHODCALLTYPE get_Data(DataTransfer::IDataPackage** v) override { return data.CopyTo(v); }
  HRESULT STDMETHODCALLTYPE put_Data(DataTransfer::IDataPackage* v) override { data = v; return S_OK; }
  HRESULT STDMETHODCALLTYPE get_Deadline(WindowsFoundation::DateTime* v) override { v->UniversalTime = 0; return S_OK; }
  HRESULT STDMETHODCALLTYPE FailWithDisplayText(HSTRING) override { failed = true; return S_OK; }
  HRESULT STDMETHODCALLTYPE GetDeferral(DataTransfer::IDataRequestDeferral** v) override { return deferral.CopyTo(v); }
};
bool PumpUntil(const std::function<bool()>& done) {
  const auto start = GetTickCount64();
  while (!done()) {
    if (GetTickCount64() - start > 5000) return false;
    MsgWaitForMultipleObjects(0, nullptr, FALSE, 10, QS_ALLINPUT);
    MSG msg;
    while (PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) { TranslateMessage(&msg); DispatchMessage(&msg); }
  }
  return true;
}
int wmain(int argc, wchar_t** argv) {
  if (argc != 2 || FAILED(RoInitialize(RO_INIT_SINGLETHREADED))) return 2;
  for (int attempt = 0; attempt < 12; ++attempt) {
    bool missing = attempt == 11;
    auto request = WRL::Make<TestRequest>();
    WRL::ComPtr<IInspectable> instance;
    HRESULT hr = RoActivateInstance(WRL::Wrappers::HStringReference(RuntimeClass_Windows_ApplicationModel_DataTransfer_DataPackage).Get(), &instance);
    if (FAILED(hr) || FAILED(instance.As(&request->data))) return 3;
    auto pending = std::make_shared<AsyncFileShare>();
    pending->request = request;
    pending->data = request->data;
    pending->deferral = request->deferral;
    pending->paths.push_back(std::wstring(argv[1]) + (missing ? L".missing" : L""));
    const auto start = GetTickCount64();
    pending->Next();
    const auto dispatchMs = GetTickCount64() - start;
    pending.reset();
    if (dispatchMs > 1000 || !PumpUntil([&] { return request->deferral->completed.load() != 0; })) return 4;
    if (request->deferral->completed != 1 || request->failed != missing) return 5;
    if (!missing) {
      WRL::ComPtr<DataTransfer::IDataPackageView> view;
      request->data->GetView(&view);
      using Items = WindowsFoundation::Collections::IVectorView<WindowsStorage::IStorageItem*>;
      WRL::ComPtr<WindowsFoundation::IAsyncOperation<Items*>> op;
      if (FAILED(view->GetStorageItemsAsync(&op))) return 6;
      bool done = false;
      unsigned count = 0;
      op->put_Completed(WRL::Callback<WindowsFoundation::IAsyncOperationCompletedHandler<Items*>>(
        [&](auto* operation, auto status) -> HRESULT {
          WRL::ComPtr<Items> items;
          if (status == WindowsFoundation::AsyncStatus::Completed && SUCCEEDED(operation->GetResults(&items))) items->get_Size(&count);
          done = true; return S_OK;
        }).Get());
      if (!PumpUntil([&] { return done; }) || count != 1) return 7;
    }
    std::cout << "Attempt " << attempt + 1 << ": " << (missing ? "missing-file error completed" : "file retained after callback") << ", dispatch " << dispatchMs << " ms\n";
  }
  std::cout << "PASS: 11 asynchronous shares, collection lifetime, and missing-file completion. No Windows UI sending performed.\n";
  return 0;
}
