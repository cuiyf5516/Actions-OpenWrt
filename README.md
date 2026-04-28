# Actions-OpenWrt

基于 GitHub Actions 自动编译 OpenWrt 固件。

## 🛠️ 使用方法

1. **配置文件**：在 `config/` 目录下准备你的 `.config`（如 `amd64.config` 或 `r2s.config`）。
2. **自定义脚本**：
   - 编辑 `diy-part1.sh` 修改插件源。
   - 编辑 `diy-part2.sh` 进行源码微调。
3. **手动触发**：
   - 在 GitHub **Actions** 页面选择对应的工作流。
   - 点击 **Run workflow** 开始编译。
4. **获取固件**：编译成功后在 **Artifacts** 处下载。

## 📝 脚本及文件说明

- `depends-ubuntu`: 编译所需的 Ubuntu 依赖包列表。
- `.github/workflows/`: 包含具体设备的流水线定义及可复用构建逻辑。

## 🤝 Credits & 致谢

本项目基于 [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt) 模板，并引用了以下项目与插件：

- [Microsoft Azure](https://azure.microsoft.com)
- [GitHub Actions](https://github.com/features/actions)
- [OpenWrt](https://github.com/openwrt/openwrt)
- [coolsnowwolf/lede](https://github.com/coolsnowwolf/lede)
- [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt)
- [Mikubill/transfer](https://github.com/Mikubill/transfer)
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)
- [Mattraks/delete-workflow-runs](https://github.com/Mattraks/delete-workflow-runs)
- [dev-drprasad/delete-older-releases](https://github.com/dev-drprasad/delete-older-releases)
- [peter-evans/repository-dispatch](https://github.com/peter-evans/repository-dispatch)

## 📄 License

本项目遵循 [MIT License](./LICENSE) 许可协议。
Copyright (c) 2019-2020 **P3TERX** & 2021-2026 **cuiyf5516**
