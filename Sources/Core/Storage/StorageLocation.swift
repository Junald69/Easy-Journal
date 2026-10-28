import SwiftData

/// SwiftData（アプリの中に記録を保存する仕組み）の保存先を決める。
///
/// 保存場所は、最初から App Group（アプリ本体とウィジェットが共有できるフォルダ）の中にする。
/// あとから移すと、すでに保存したデータの引っ越しが必要になるため。
///
/// テストでは `inMemory: true` を使う。これはメモリ上だけに置き、ファイルを作らない。
/// この関数は、アプリの起動（`EasyJournalApp`）からは呼ばない。
/// 実際に保存する入れ物（`ModelContainer`）は、ここでは作らない（T-104）。
/// モデル（`@Model`）も、ここでは作らない。
///
/// 初期化の引数は、Apple Developer Documentation の
/// `ModelConfiguration.init(_:schema:isStoredInMemoryOnly:allowsSave:groupContainer:cloudKitDatabase:)`
/// と `init(isStoredInMemoryOnly:)`（どちらも iOS 17 以上。2026-10-28 に確認）に合わせている。
/// アプリの最低バージョンは iOS 18。
/// `groupContainer` に ID を渡すときは `GroupContainer.identifier(_:)`（iOS 17 以上。同じ日に確認）。
///
/// `cloudKitDatabase` はここでは書かない。同じ宣言では、標準は `.automatic`。
/// `.automatic` は、CloudKit の同期を有効にする、と書かれている。
/// 同期を使わないとき `.none` にすべきかは要確認。
/// この書き方がビルドで通るかは、まだ未確認。
enum StorageLocation {
    /// 保存先の設定を作る。
    /// - Parameter inMemory: `true` のとき、ファイルを作らずメモリ上だけにする（テスト用）。
    static func modelConfiguration(inMemory: Bool = false) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        }
        return ModelConfiguration(groupContainer: .identifier(AppGroup.identifier))
    }
}
