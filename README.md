# pindou-client

拼豆 Flutter 客户端，支持 iPadOS、Android 平板、iOS 手机和 Android 手机，适配优先级依次为 iPadOS、Android 平板、iOS 手机、Android 手机。

## 开发

```powershell
flutter create --platforms=android,ios .
flutter pub get
flutter test
flutter run --dart-define=PARSE_API_BASE_URL=http://你的服务地址:8787
```

静态图片解析成功后直接进入图片就绪页；实况和视频先选择关键帧，再生成静态图片。

## GitHub Actions 构建物

每次推送到 `main` 后，Actions 会完成分析、测试和双端 Release 构建，并直接生成：

- `pindou.apk`：针对现代 Android 手机和平板的 ARM64 Release APK；按 ABI 拆分，避免携带无关架构。
- `pindou-apk-compat`：供旧 32 位 ARM 设备和 x86_64 设备使用的兼容 APK。
- `pindou.ipa`：iOS/iPadOS 未签名 Release IPA，安装前需要使用个人 Apple ID 或开发证书签名。

Release 构建启用 Dart 混淆和调试符号拆分；符号文件由 Actions 单独保存，不计入安装包体积。
