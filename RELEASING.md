# 发布流程

与 Dayroll 完全一致（release-please + TestFlight 流水线）。

## 工作方式

1. 日常提交用 **Conventional Commits**（`feat: …` / `fix: …` / `chore: …`）推到 `main`
2. release-please 自动维护一个 Release PR（版本号 + CHANGELOG，`feat` 升 minor、`fix` 升 patch）
3. **合并 Release PR** → 自动打 tag、建 GitHub Release → 触发 TestFlight job：archive → 签名 → 上传
4. 版本号唯一来源是 `project.yml` 的 `MARKETING_VERSION`（release-please 通过 `x-release-please-version` 注释自动改写）；build 号 = GitHub run number

## Secrets

6 个 secrets（APPLE_TEAM_ID / ASC_KEY_ID / ASC_ISSUER_ID / ASC_API_KEY_P8 / DIST_CERT_P12 / DIST_CERT_PASSWORD）已配置在 **sunpebble org 级**（visibility ALL），本仓库自动继承，无需重复配置。

## 一次性准备（上传能成功的前提）

- [ ] App Store Connect 创建 App，bundle id `com.sunpebble.simmer`
- [ ] ASC 内购：创建非消耗型商品 `com.sunpebble.simmer.lifetime`（$1.99）
- [ ] 首次云签名如失败，本机 Xcode 用 `-allowProvisioningUpdates` 构建一次让 App ID 自动注册

注意：Simmer 无 App Group、无 HealthKit——Live Activity 不需要额外 capability，只需 Info.plist 的 `NSSupportsLiveActivities`（已配）。

## 注意

- 私有仓库的 macOS runner 按 10 倍分钟计费，流水线只在合并 Release PR 时跑一次 archive+upload，不跑测试（测试在本地/PR 阶段完成）
- 上传成功后在 App Store Connect → TestFlight 里勾出口合规（Info.plist 已声明 `ITSAppUsesNonExemptEncryption=false`，通常自动通过）
- Squash 合并 Release PR 时标题必须保持 conventional 格式
