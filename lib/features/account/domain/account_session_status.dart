/// 账户会话状态。
///
/// 这里刻意不提供 `loggedIn: true/false` 这种布尔判断：
/// - 本地记账在 [guest] / [expired] / [error] 下都必须继续可用；
/// - 只有 [authenticated] 才允许执行服务器动作；
/// - 网络异常不等于退出登录，因此不能把临时网络失败映射成 [expired]。
enum AccountSessionStatus {
  /// 尚未读取本地会话（启动瞬间）。
  initializing,

  /// 没有服务器身份，本地记账完全可用。
  guest,

  /// 有服务器身份，可以执行需要账号的服务器动作。
  authenticated,

  /// 以前登录过，但 Token 已被服务器拒绝或本地已过期。
  /// 本地数据不受影响，用户再次触发服务器动作时提示重新登录。
  expired,

  /// 读取本地会话失败（例如安全存储不可用）。
  /// 这同样不等于退出登录：不得因此清空账号或本地数据。
  error,
}
