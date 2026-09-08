#include <windows.h>
#include <shobjidl.h>
#include <propkey.h>
#include <wrl/client.h>
#include <thread>
#include <functional>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>

constexpr UINT kMediaPreviewReady = WM_APP + 174;
struct PreviewReply {
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result;
  flutter::EncodableMap value;
};

inline void LoadMediaPreview(HWND window, std::wstring path,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::thread([window, path, result = std::move(result)]() mutable {
    auto reply = std::make_unique<PreviewReply>();
    reply->result = std::move(result);
    const HRESULT com = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    Microsoft::WRL::ComPtr<IShellItem2> item;
    if (SUCCEEDED(com) && SUCCEEDED(SHCreateItemFromParsingName(path.c_str(), nullptr, IID_PPV_ARGS(&item)))) {
      ULONGLONG duration = 0;
      if (SUCCEEDED(item->GetUInt64(PKEY_Media_Duration, &duration))) {
        reply->value[flutter::EncodableValue("durationMs")] = flutter::EncodableValue(static_cast<int64_t>(duration / 10000));
      }
      Microsoft::WRL::ComPtr<IShellItemImageFactory> factory;
      HBITMAP bitmap = nullptr;
      if (SUCCEEDED(item.As(&factory)) && SUCCEEDED(factory->GetImage({420, 420}, SIIGBF_THUMBNAILONLY, &bitmap))) {
        BITMAP info{};
        GetObject(bitmap, sizeof(info), &info);
        const int w = info.bmWidth, h = info.bmHeight;
        if (w > 0 && h > 0 && w <= 1024 && h <= 1024) {
          BITMAPINFO dib{};
          dib.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
          dib.bmiHeader.biWidth = w;
          dib.bmiHeader.biHeight = -h;
          dib.bmiHeader.biPlanes = 1;
          dib.bmiHeader.biBitCount = 32;
          dib.bmiHeader.biCompression = BI_RGB;
          std::vector<uint8_t> pixels(static_cast<size_t>(w) * h * 4);
          HDC dc = GetDC(nullptr);
          if (GetDIBits(dc, bitmap, 0, h, pixels.data(), &dib, DIB_RGB_COLORS)) {
            for (size_t i = 0; i < pixels.size(); i += 4) {
              std::swap(pixels[i], pixels[i + 2]);
              pixels[i + 3] = 255;
            }
            reply->value[flutter::EncodableValue("width")] = flutter::EncodableValue(w);
            reply->value[flutter::EncodableValue("height")] = flutter::EncodableValue(h);
            reply->value[flutter::EncodableValue("rgba")] = flutter::EncodableValue(pixels);
          }
          ReleaseDC(nullptr, dc);
        }
        DeleteObject(bitmap);
      }
    }
    item.Reset();
    if (SUCCEEDED(com)) CoUninitialize();
    if (PostMessage(window, kMediaPreviewReady, 0, reinterpret_cast<LPARAM>(reply.get()))) reply.release();
  }).detach();
}
