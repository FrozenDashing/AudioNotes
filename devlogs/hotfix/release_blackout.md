这份新抓到的 log 已经把原因锁得很死了：**release 闪退是 Vosk / JNA 初始化阶段触发的原生异常**，不是 Flutter 页面本身。日志里两次都清楚地出现了：

* `Load ... libjnidispatch.so ... ok`，说明 JNA 的 native so 已经成功加载。
* 随后立刻在 `Thread-4` 抛出 `java.lang.UnsatisfiedLinkError: Can't obtain peer field ID for class com.sun.jna.Pointer`。
* 调用栈显示异常发生在 `com.sun.jna.Native.initIDs` → `com.sun.jna.Native.<clinit>` → `org.vosk.LibVosk.<clinit>` → `C0.h.run`。也就是说，是 **Vosk 在后台线程做静态初始化时炸了**。

## 结论

最可能的根因是：**release 构建里 JNA / Vosk 的 Java 类被 R8/ProGuard 压缩、混淆或裁剪后，JNA native 代码找不到 `com.sun.jna.Pointer` 里它需要的 `peer` 字段**。
因为 native so 已经加载成功了，所以这不是“缺少 `libjnidispatch.so`”这种问题，而是**JNI/JNA 反射/字段签名不匹配**。

## 为什么我这么判断

这类错误的典型特征就是：

1. so 能加载成功；
2. 一进入 JNA 的 `Native.initIDs()` 就崩；
3. 栈顶是 `UnsatisfiedLinkError`，而不是 Flutter 的 `PlatformException` 或 Dart `Exception`。

你的 log 完全符合这三点。并且相同错误在 `13:10`、`13:13`、`13:21` 多次重复出现，说明这是稳定复现的启动崩溃，不是偶发噪声。

## 你现在该怎么修

### 1) 先验证是不是 release 混淆导致

把 `android/app/build.gradle.kts` 里的 release 临时改成：

```gradle
buildTypes {
    release {
        minifyEnabled false
        shrinkResources false
    }
}
```

如果这样 release 不闪退了，基本就能确认是 **R8/ProGuard** 问题。

### 2) 加 keep 规则

在 `android/app/proguard-rules.pro` 里先加：

```pro
-keep class com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn com.sun.jna.**
-dontwarn org.vosk.**
```

如果你项目里还有 Vosk / JNA 相关的桥接类，也一起 keep。

### 3) 不要在启动时立刻初始化 Vosk

把原生侧 `onAttachedToEngine()` 里那种“启动就初始化模型”的逻辑延后，改成用户点击录音时再懒加载。
现在 log 显示崩溃发生在 `Thread-4` 的静态初始化阶段，说明它已经太早了。

### 4) 把启动崩溃变成可降级错误

原生插件初始化失败时，不要让整个 App 退出，改成：

* 记录错误
* 标记语音功能不可用
* 继续启动主界面

---

## 最短修复路径

按这个顺序做最省时间：

1. 关掉 release 的 `minifyEnabled` / `shrinkResources` 验证
2. 加 `com.sun.jna` 和 `org.vosk` 的 keep 规则
3. 把 Vosk 初始化从启动阶段挪到用户点击录音时
4. 再重新打 release 包测试

如果你要，我下一条可以直接给你一份**按文件和行级别写好的修复清单**，你可以直接交给本地 agent 改。
