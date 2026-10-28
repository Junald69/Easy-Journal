import SwiftData

/// 保存データの形の、最初のバージョン（V1）。
///
/// 最初のバージョンから、バージョン管理を入れておく。
/// 保存データの形を変えるときは、変更前のモデルを SchemaV1 として凍結し、
/// V2 を作って stages に引っ越し手順を足す。
/// 公開後に形を変えるときは特に慎重に。
///
/// モデルのクラスは、いまは各ファイルのトップレベルに置いたまま、ここに名前を並べている。
/// この置き方だと、最初に形を変えるとき、変える前のクラスを V1 として凍結する必要がある。
enum EasyJournalSchemaV1: VersionedSchema {
    /// バージョン番号。1.0.0。
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    /// このバージョンに含まれるモデル。12個。
    static var models: [any PersistentModel.Type] {
        [
            Journal.self,
            Page.self,
            MonthlyPage.self,
            MonthlyLogLine.self,
            DailyPage.self,
            JournalTask.self,
            TaskHistory.self,
            Habit.self,
            HabitEntry.self,
            MoodEntry.self,
            SleepEntry.self,
            PageLink.self,
        ]
    }
}

/// 保存データの引っ越し手順。
///
/// いまは V1 だけなので、手順（stages）は空。
/// 形を変えるときは、ここに V2 と、V1 から V2 への手順を足す。
enum EasyJournalMigrationPlan: SchemaMigrationPlan {
    /// 知っているバージョンの一覧。いまは V1 だけ。
    static var schemas: [any VersionedSchema.Type] {
        [EasyJournalSchemaV1.self]
    }

    /// 引っ越しの手順。最初のバージョンなので、まだ無い。
    static var stages: [MigrationStage] {
        []
    }
}
