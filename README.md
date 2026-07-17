# easy_unraid_ssh

The core, audit-friendly SSH, keypair management, and direct connection library for the **Easy Unraid** client app.

[中文](#中文) | [English](#english)

---

## 中文

`easy_unraid_ssh` 是一个独立、开源的 Dart/Flutter 依赖包，负责处理 **Easy Unraid** 客户端中所有涉及安全防线的 SSH 命令执行、密钥对生成与服务器认证生命周期。

### 🛡️ 安全与隐私审计承诺
为了消除技术极客对服务器 Root 权限连接的安全顾虑，我们将这部分核心逻辑完全开源供社区监督审计：
* **纯本地执行**：所有的 RSA-2048 密钥对生成、SSH Socket 握手均在您的手机/电脑本地沙盒内完成。
* **零云端中转**：此代码库中没有任何向第三方或云端服务器发送隐私、密码、或流量分析（Telemetry）的网络请求，仅维持与您填写的 Unraid 局域网/内网穿透 IP 的直连。
* **物理抹除密码**：您的 root 密码仅在初次“密码配对”时被临时载入内存用于注入公钥，配对成功后立即从本地沙盒中物理抹除，后续所有监控指令均走公钥证书免密连接。

### ⚙️ 核心功能
1. **多线程安全密钥生成**：在后台 Isolate 中通过 PointyCastle 算法库异步生成 RSA-2048 密钥对。
2. **持久化公钥注入**：通过初始密码连接，自动将公钥追加至 Unraid 优盘的 `/boot/config/ssh/root/authorized_keys` 中，确保 Unraid 重启后连接依然有效。
3. **精准密钥注销**：退出登录时，根据客户端唯一标识符（Comment Tag）精准擦除 Unraid 中的授权公钥行，不影响服务器上其他已有密钥。
4. **底层 DartSSH2 转发**：透明导出 `dartssh2` 底层客户端，为上层 App 的终端模拟器和 SFTP 文件管理提供高速流通道。

---

## English

`easy_unraid_ssh` is a standalone, open-source Dart/Flutter package that handles the security-sensitive SSH commands, keypair generation, and server authentication lifecycle for the **Easy Unraid** server manager.

### 🛡️ Security & Privacy Audit Promise
This package is fully open-source to allow technical Unraid users and security researchers to inspect its behavior. 
* **Purely Local**: All operations, keypair generation (RSA-2048), and SSH socket handshakes are performed directly on your local device.
* **No Telemetry / No Backdoors**: There are absolutely no HTTP requests, cloud server telemetry, or password-forwarding code blocks in this repository. It only establishes direct connections to your Unraid host IP.
* **Password Erasure**: The root password is only used in memory for the initial session to inject the generated SSH public key. Once injection succeeds, the password is wiped from the device memory.

### ⚙️ Key Features
1. **Cryptographically Secure Key Gen**: Generates RSA-2048 key pairs inside a background isolate using PointyCastle Fortuna.
2. **Persistent SSH Key Injection**: Connects once via password to append the client public key to `/boot/config/ssh/root/authorized_keys` for Unraid, surviving flash drive reboots.
3. **Graceful Key Revocation**: Safely removes the device's public key from the Unraid boot storage during logout.
4. **Interactive Shell Support**: Exposes underlying `dartssh2` client bindings for secure terminal and file management streams.
