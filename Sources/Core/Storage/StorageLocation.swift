import SwiftData

/// SwiftData（アプリの中に記録を保存する仕組み）の保存先を決める。
///
/// 保存場所は、最初から App Group（アプリ本体とウィジェットが共有できるフォルダ）の中にする。
/// あとから移すと、すでに保存したデータの引っ越しが必要になるため。
///
/// テストでは `inMemory: true` を使う。これはメモリ上だけに置き、ファイルを作らない。
/// アプリの起動（`EasyJournalApp`）は `makeContainer(inMemory:)` を呼ぶ。
///
/// 初期化の引数は、Apple Developer Documentation の次の宣言に合わせている（2026-10-28 に確認。iOS 17 以上）。
/// アプリの最低バージョンは iOS 18。
/// - `ModelConfiguration.init(_:schema:isStoredInMemoryOnly:allowsSave:groupContainer:cloudKitDatabase:)`
/// - `ModelConfiguration.init(isStoredInMemoryOnly:)`
/// - `GroupContainer.identifier(_:)`
/// - `ModelContainer.init(for:migrationPlan:configurations:)`（失敗することがある。throws）
/// - `Schema.init(versionedSchema:)`
///
/// `cloudKitDatabase` は `.none`（同期を使わない）。同期を使うと決めたら変更。
///
/// App Group の保存先が開けなかったときは、別の場所に切り替えない。
/// エラーをそのまま上に投げる。データが2か所に分かれて、消えたように見えるのを防ぐため。
/// App Group が署名つきで実際に使えるかは、T-005 のあとまで未確認。
enum StorageLocation {
    /// 保存先の設定を作る。
    /// - Parameter inMemory: `true` のとき、ファイルを作らずメモリ上だけにする（テスト用）。
    static func modelConfiguration(inMemory: Bool = false) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(isStoredInMemoryOnly: true)
        }
        // 同期を使うと決めたら、cloudKitDatabase を変更する。
        return ModelConfiguration(
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .none
        )
    }

    /// 保存の入れ物（`ModelContainer`）を作る。
    ///
    /// 失敗したときはエラーを投げる。握りつぶさない。`fatalError` にもしない。
    /// 呼ぶ側（アプリの起動）が、エラーの画面を出す。
    /// 開けなかったとき、別の場所には保存しない。
    /// - Parameter inMemory: `true` のとき、メモリ上だけにする（テスト用、画面テスト用）。
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: EasyJournalSchemaV1.self)
        let configuration = modelConfiguration(inMemory: inMemory)
        return try ModelContainer(
            for: schema,
            migrationPlan: EasyJournalMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
