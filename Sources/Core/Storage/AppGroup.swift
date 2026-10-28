/// App Group（アプリ本体とウィジェットが共有できるフォルダ）の ID。
///
/// この値は `project.yml` の entitlements（アプリに許可する機能の宣言）と同じにする。
/// どちらかを変えたら、両方変える。
///
/// Junさんが確定した値。Apple側への登録の可否は、T-005のあとに確認する。
enum AppGroup {
    static let identifier = "group.com.junald69.easyjournal"
}
